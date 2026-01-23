# =============================================================================
# Immich Hybrid Model - Makefile
# =============================================================================
# Local Docker + AWS S3 Storage
# =============================================================================

.PHONY: help setup start stop restart logs status backup clean

TERRAFORM_DIR := terraform
DOCKER_DIR := docker

help: ## Show this help message
	@echo "Immich Hybrid Model Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
setup: ## Initial setup - deploy S3 and configure Docker
	@echo "=== Step 1: Deploy AWS S3 Storage ==="
	@cp -n $(TERRAFORM_DIR)/terraform.tfvars.example $(TERRAFORM_DIR)/terraform.tfvars 2>/dev/null || true
	@echo "Edit $(TERRAFORM_DIR)/terraform.tfvars, then run: make deploy-s3"

deploy-s3: ## Deploy S3 buckets to AWS
	cd $(TERRAFORM_DIR) && terraform init && terraform apply
	@echo ""
	@echo "=== AWS Credentials (add to docker/.env) ==="
	@cd $(TERRAFORM_DIR) && terraform output aws_access_key_id
	@echo "Secret: Run 'cd terraform && terraform output -raw aws_secret_access_key'"
	@cd $(TERRAFORM_DIR) && terraform output s3_buckets

configure-docker: ## Configure Docker environment
	@cp -n $(DOCKER_DIR)/.env.example $(DOCKER_DIR)/.env 2>/dev/null || true
	@echo "Edit $(DOCKER_DIR)/.env with AWS credentials from 'make deploy-s3'"

generate-secrets: ## Generate secure database password
	@echo "Database Password (add to docker/.env as DB_PASSWORD):"
	@openssl rand -base64 32

# -----------------------------------------------------------------------------
# Docker Commands
# -----------------------------------------------------------------------------
start: ## Start Immich
	cd $(DOCKER_DIR) && docker compose up -d
	@echo ""
	@echo "Immich starting at http://localhost:2283"
	@echo "View logs: make logs"

stop: ## Stop Immich
	cd $(DOCKER_DIR) && docker compose down

restart: ## Restart Immich
	cd $(DOCKER_DIR) && docker compose restart

status: ## Show container status
	cd $(DOCKER_DIR) && docker compose ps

# -----------------------------------------------------------------------------
# Logs
# -----------------------------------------------------------------------------
logs: ## Follow all logs
	cd $(DOCKER_DIR) && docker compose logs -f

logs-server: ## Follow Immich server logs
	cd $(DOCKER_DIR) && docker compose logs -f immich-server

logs-sync: ## Follow S3 sync logs
	cd $(DOCKER_DIR) && docker compose logs -f s3-sync

logs-db: ## Follow PostgreSQL logs
	cd $(DOCKER_DIR) && docker compose logs -f database

# -----------------------------------------------------------------------------
# Backup & Maintenance
# -----------------------------------------------------------------------------
backup-db: ## Backup PostgreSQL database
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	docker exec immich_postgres pg_dump -U postgres immich > backup_$$TIMESTAMP.sql; \
	echo "Backup saved to backup_$$TIMESTAMP.sql"

sync-now: ## Force S3 sync now
	docker exec immich_s3_sync aws s3 sync /upload s3://$$S3_BUCKET/upload --storage-class STANDARD_IA
	@echo "Sync complete"

# -----------------------------------------------------------------------------
# Terraform Commands
# -----------------------------------------------------------------------------
tf-init: ## Initialize Terraform
	cd $(TERRAFORM_DIR) && terraform init

tf-plan: ## Preview Terraform changes
	cd $(TERRAFORM_DIR) && terraform plan

tf-apply: ## Apply Terraform changes
	cd $(TERRAFORM_DIR) && terraform apply

tf-output: ## Show Terraform outputs
	cd $(TERRAFORM_DIR) && terraform output

tf-destroy: ## Destroy AWS resources (CAUTION!)
	@echo "WARNING: This will destroy ALL S3 data!"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	cd $(TERRAFORM_DIR) && terraform destroy

# -----------------------------------------------------------------------------
# Cleanup
# -----------------------------------------------------------------------------
clean: ## Clean up local Terraform files
	rm -f backup_*.sql
	cd $(TERRAFORM_DIR) && rm -rf .terraform .terraform.lock.hcl

clean-all: ## Remove all local data (CAUTION!)
	@echo "WARNING: This will delete all local Immich data!"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	cd $(DOCKER_DIR) && rm -rf postgres redis upload model-cache

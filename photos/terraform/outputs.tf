# =============================================================================
# Immich AWS Infrastructure - Outputs (Hybrid Model)
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Credentials (IMPORTANT - Add these to your local .env file)
# -----------------------------------------------------------------------------
output "aws_access_key_id" {
  description = "AWS Access Key ID for local Immich"
  value       = aws_iam_access_key.immich.id
  sensitive   = false
}

output "aws_secret_access_key" {
  description = "AWS Secret Access Key for local Immich"
  value       = aws_iam_access_key.immich.secret
  sensitive   = true
}

# -----------------------------------------------------------------------------
# S3 Buckets
# -----------------------------------------------------------------------------
output "s3_primary_bucket" {
  description = "Primary S3 bucket (daily use)"
  value       = aws_s3_bucket.primary.id
}

output "s3_backup_bucket" {
  description = "Backup S3 bucket (disaster recovery)"
  value       = aws_s3_bucket.backup.id
}

output "primary_region" {
  description = "Primary AWS region"
  value       = var.primary_region
}

output "backup_region" {
  description = "Backup AWS region"
  value       = var.backup_region
}

# -----------------------------------------------------------------------------
# Quick Setup - Copy this to docker/.env
# -----------------------------------------------------------------------------
output "docker_env_config" {
  description = "Add these lines to docker/.env"
  value       = <<-EOT
    
    # === AWS Configuration (from Terraform) ===
    AWS_ACCESS_KEY_ID=${aws_iam_access_key.immich.id}
    AWS_SECRET_ACCESS_KEY=<run: terraform output -raw aws_secret_access_key>
    AWS_REGION=${var.primary_region}
    S3_BUCKET=${aws_s3_bucket.primary.id}
  EOT
}

# -----------------------------------------------------------------------------
# Cost Summary
# -----------------------------------------------------------------------------
output "cost_estimate" {
  description = "Estimated monthly cost"
  value = {
    note            = "Your computer runs Immich - AWS only stores photos"
    s3_storage      = "~$0.0125/GB/month (Standard-IA)"
    glacier_archive = "~$0.00099/GB/month (after ${var.archive_after_days} days)"
    example_100gb   = "~$1.25/month for 100GB"
    example_500gb   = "~$6.25/month for 500GB"
  }
}

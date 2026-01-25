# =============================================================================
# Immich AWS Infrastructure - Outputs (Cold Storage Model)
# =============================================================================

# -----------------------------------------------------------------------------
# AWS Credentials (IMPORTANT - Add these to your local .env file)
# -----------------------------------------------------------------------------
output "aws_access_key_id" {
  description = "AWS Access Key ID for s3-sync"
  value       = aws_iam_access_key.immich.id
  sensitive   = false
}

output "aws_secret_access_key" {
  description = "AWS Secret Access Key for s3-sync"
  value       = aws_iam_access_key.immich.secret
  sensitive   = true
}

# -----------------------------------------------------------------------------
# S3 Cold Storage Buckets (Glacier Deep Archive)
# -----------------------------------------------------------------------------
output "s3_cold_storage_1" {
  description = "Cold storage bucket 1 (us-west-1)"
  value       = aws_s3_bucket.cold_storage_1.id
}

output "s3_cold_storage_2" {
  description = "Cold storage bucket 2 (us-west-2)"
  value       = aws_s3_bucket.cold_storage_2.id
}

output "region_1" {
  description = "Cold storage region 1"
  value       = var.primary_region
}

output "region_2" {
  description = "Cold storage region 2"
  value       = var.backup_region
}

# -----------------------------------------------------------------------------
# Quick Setup - Copy this to docker/.env
# -----------------------------------------------------------------------------
output "docker_env_config" {
  description = "Add these lines to docker/.env"
  value       = <<-EOT
    
    # === AWS Cold Storage Configuration (from Terraform) ===
    AWS_ACCESS_KEY_ID=${aws_iam_access_key.immich.id}
    AWS_SECRET_ACCESS_KEY=<run: terraform output -raw aws_secret_access_key>
    
    # Cold storage bucket 1 (us-west-1)
    AWS_REGION_1=${var.primary_region}
    S3_BUCKET_1=${aws_s3_bucket.cold_storage_1.id}
    
    # Cold storage bucket 2 (us-west-2)
    AWS_REGION_2=${var.backup_region}
    S3_BUCKET_2=${aws_s3_bucket.cold_storage_2.id}
  EOT
}

# -----------------------------------------------------------------------------
# Cost Summary
# -----------------------------------------------------------------------------
output "cost_estimate" {
  description = "Estimated monthly cost"
  value = {
    note               = "Local SSD = primary storage, AWS = monthly cold backup"
    glacier_deep       = "~$0.00099/GB/month (Glacier Deep Archive)"
    example_100gb      = "~$0.20/month for 100GB (two regions)"
    example_500gb      = "~$1.00/month for 500GB (two regions)"
    restore_cost       = "~$0.02/GB + 12-48 hour wait time"
    includes           = "Photos + PostgreSQL database"
  }
}

# =============================================================================
# Immich AWS Infrastructure - Hybrid Model (Local + S3)
# =============================================================================
# Your computer runs Immich, AWS S3 stores photos
# Primary bucket for daily use, backup bucket in different region for disaster recovery
# =============================================================================

# -----------------------------------------------------------------------------
# General Configuration
# -----------------------------------------------------------------------------
variable "project_name" {
  description = "Name of the project, used for resource naming and S3 bucket"
  type        = string
  default     = "immich"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

# -----------------------------------------------------------------------------
# AWS Regions
# -----------------------------------------------------------------------------
variable "primary_region" {
  description = "Primary AWS region for main S3 bucket (closest to you)"
  type        = string
  default     = "us-west-1"  # N. California - closest to San Diego
}

variable "backup_region" {
  description = "Backup AWS region for disaster recovery bucket"
  type        = string
  default     = "us-west-2"  # Oregon - different region for redundancy
}

# -----------------------------------------------------------------------------
# S3 Storage Configuration
# -----------------------------------------------------------------------------
variable "enable_glacier_archive" {
  description = "Enable automatic archival to Glacier Deep Archive after configured days"
  type        = bool
  default     = true
}

variable "archive_after_days" {
  description = "Days before transitioning to Glacier Deep Archive"
  type        = number
  default     = 90
}

variable "s3_versioning_enabled" {
  description = "Enable versioning on S3 buckets (protects against accidental deletes)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------
variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

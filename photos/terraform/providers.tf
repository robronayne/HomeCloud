# =============================================================================
# Immich AWS Infrastructure - Provider Configuration
# =============================================================================
# Two providers: primary region (closest) and backup region (disaster recovery)
# =============================================================================

terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Primary region (closest to you - for daily use)
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

# Backup region (different region - for disaster recovery)
provider "aws" {
  alias  = "backup"
  region = var.backup_region
}

# Default provider (primary)
provider "aws" {
  region = var.primary_region
}

# =============================================================================
# S3 Cold Storage Buckets - Glacier Deep Archive (Quarterly Backups)
# =============================================================================
# Architecture: Local SSD (primary) + Cold Storage (disaster recovery)
# Two buckets in different regions for redundancy
# Quarterly sync from local to both buckets via s3-sync container
# =============================================================================

# -----------------------------------------------------------------------------
# Cold Storage Bucket 1 (us-west-1 - N. California)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "cold_storage_1" {
  provider = aws.primary
  bucket   = "${local.name_prefix}-cold-1-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cold-storage-1"
    Type = "glacier-deep-archive"
  })
}

resource "aws_s3_bucket_versioning" "cold_storage_1" {
  provider = aws.primary
  bucket   = aws_s3_bucket.cold_storage_1.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cold_storage_1" {
  provider = aws.primary
  bucket   = aws_s3_bucket.cold_storage_1.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cold_storage_1" {
  provider = aws.primary
  bucket   = aws_s3_bucket.cold_storage_1.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: Immediate transition to Glacier Deep Archive
resource "aws_s3_bucket_lifecycle_configuration" "cold_storage_1" {
  provider = aws.primary
  bucket   = aws_s3_bucket.cold_storage_1.id

  rule {
    id     = "immediate-deep-archive"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 0
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = 0
      storage_class   = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# -----------------------------------------------------------------------------
# Cold Storage Bucket 2 (us-west-2 - Oregon)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "cold_storage_2" {
  provider = aws.backup
  bucket   = "${local.name_prefix}-cold-2-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cold-storage-2"
    Type = "glacier-deep-archive"
  })
}

resource "aws_s3_bucket_versioning" "cold_storage_2" {
  provider = aws.backup
  bucket   = aws_s3_bucket.cold_storage_2.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cold_storage_2" {
  provider = aws.backup
  bucket   = aws_s3_bucket.cold_storage_2.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "cold_storage_2" {
  provider = aws.backup
  bucket   = aws_s3_bucket.cold_storage_2.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: Immediate transition to Glacier Deep Archive
resource "aws_s3_bucket_lifecycle_configuration" "cold_storage_2" {
  provider = aws.backup
  bucket   = aws_s3_bucket.cold_storage_2.id

  rule {
    id     = "immediate-deep-archive"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 0
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = 0
      storage_class   = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# =============================================================================
# S3 Buckets - Primary (monthly backups) + Backup (disaster recovery)
# =============================================================================
# Primary: us-west-1 (N. California) - closest to San Diego
# Backup:  us-west-2 (Oregon) - different region for redundancy
# Cross-region replication (CRR) automatically copies to backup bucket
# =============================================================================

# -----------------------------------------------------------------------------
# Primary Bucket (Monthly Backups - Infrequent Access)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${local.name_prefix}-primary-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-primary"
    Type = "primary-infrequent-access"
  })
}

resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id

  versioning_configuration {
    status = "Enabled"  # Required for replication
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: Transition to Infrequent Access after 30 days (AWS minimum)
resource "aws_s3_bucket_lifecycle_configuration" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# -----------------------------------------------------------------------------
# Backup Bucket (Disaster Recovery)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "backup" {
  provider = aws.backup
  bucket   = "${local.name_prefix}-backup-${random_id.bucket_suffix.hex}"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-backup"
    Type = "disaster-recovery"
  })
}

resource "aws_s3_bucket_versioning" "backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.backup.id

  versioning_configuration {
    status = "Enabled"  # Required for replication
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: Immediate transition to Glacier Deep Archive
resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  provider = aws.backup
  bucket   = aws_s3_bucket.backup.id

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
# Cross-Region Replication (Primary → Backup)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "replication" {
  name = "${local.name_prefix}-s3-replication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "replication" {
  name = "${local.name_prefix}-s3-replication"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.primary.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "${aws_s3_bucket.backup.arn}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "primary_to_backup" {
  provider   = aws.primary
  depends_on = [aws_s3_bucket_versioning.primary, aws_s3_bucket_versioning.backup]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.backup.arn
      storage_class = "DEEP_ARCHIVE"  # Replicate directly to Glacier Deep Archive
    }
  }
}

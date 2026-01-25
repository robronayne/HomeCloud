# =============================================================================
# IAM - User and Policies for Quarterly Cold Storage Backup
# =============================================================================

# IAM User for s3-sync container to backup to cold storage
resource "aws_iam_user" "immich" {
  name = "${local.name_prefix}-user"
  tags = local.common_tags
}

# Access keys for the IAM user
resource "aws_iam_access_key" "immich" {
  user = aws_iam_user.immich.name
}

# S3 access policy - write to both cold storage buckets, read for restore
resource "aws_iam_user_policy" "immich_s3" {
  name = "${local.name_prefix}-s3-access"
  user = aws_iam_user.immich.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.cold_storage_1.arn,
          aws_s3_bucket.cold_storage_2.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:RestoreObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ]
        Resource = [
          "${aws_s3_bucket.cold_storage_1.arn}/*",
          "${aws_s3_bucket.cold_storage_2.arn}/*"
        ]
      }
    ]
  })
}

# =============================================================================
# IAM - User and Policies for Local Immich Access to S3
# =============================================================================

# IAM User for local Immich server to access S3
resource "aws_iam_user" "immich" {
  name = "${local.name_prefix}-user"
  tags = local.common_tags
}

# Access keys for the IAM user
resource "aws_iam_access_key" "immich" {
  user = aws_iam_user.immich.name
}

# S3 access policy for Immich user (primary bucket only - backup is read via replication)
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
          aws_s3_bucket.primary.arn,
          aws_s3_bucket.backup.arn
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
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:RestoreObject"
        ]
        Resource = "${aws_s3_bucket.backup.arn}/*"
      }
    ]
  })
}

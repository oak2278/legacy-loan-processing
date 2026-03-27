# IAM Role for CodeBuild
# This role allows CodeBuild to compile the .NET application and upload artifacts
# Requirements: 12.2, 13.1

resource "aws_iam_role" "codebuild" {
  name = "codebuild-loan-processing-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "codebuild-loan-processing-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}

# Policy for S3 artifact bucket access (read/write)
resource "aws_iam_role_policy" "codebuild_s3" {
  name = "codebuild-s3-access"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      }
    ]
  })
}

# Policy for CloudWatch Logs
resource "aws_iam_role_policy" "codebuild_logs" {
  name = "codebuild-logs-access"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/loan-processing-${var.environment}",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/loan-processing-${var.environment}:*"
        ]
      }
    ]
  })
}

# Policy for KMS encryption key access
resource "aws_iam_role_policy" "codebuild_kms" {
  name = "codebuild-kms-access"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.pipeline_artifacts.arn
      }
    ]
  })
}

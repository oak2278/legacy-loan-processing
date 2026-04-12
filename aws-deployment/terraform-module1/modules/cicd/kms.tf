# KMS Key for Pipeline Artifact Encryption
# This key encrypts artifacts in S3 and is used by CodePipeline, CodeBuild, and CodeDeploy
# Requirements: 12.3, 13.2

resource "aws_kms_key" "pipeline_artifacts" {
  description             = "KMS key for encrypting CI/CD pipeline artifacts in ${var.environment} environment"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-pipeline-key-${var.environment}"
      Purpose     = "CI/CD Pipeline Artifact Encryption"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}

# KMS Key Policy
resource "aws_kms_key_policy" "pipeline_artifacts" {
  key_id = aws_kms_key.pipeline_artifacts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CodePipeline to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.codepipeline.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CodeBuild to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.codebuild.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CodeDeploy to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.codedeploy.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 instances to decrypt artifacts"
        Effect = "Allow"
        Principal = {
          AWS = var.ec2_instance_role_arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key for encryption"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# KMS Key Alias for easy reference
resource "aws_kms_alias" "pipeline_artifacts" {
  name          = "alias/loan-processing-pipeline-${var.environment}"
  target_key_id = aws_kms_key.pipeline_artifacts.key_id
}

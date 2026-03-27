# IAM Policy Extensions for EC2 Instance Role
# This file extends the existing EC2 instance IAM role (created in the security module)
# with additional permissions required for CodeDeploy deployments
# Requirements: 6.1, 11.4, 13.1, 13.3

# Additional IAM policy for CodeDeploy agent and deployment operations
resource "aws_iam_role_policy" "ec2_codedeploy" {
  name = "loan-processing-${var.environment}-ec2-codedeploy-policy"
  role = element(split("/", var.ec2_instance_role_arn), length(split("/", var.ec2_instance_role_arn)) - 1)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ArtifactBucketReadAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      },
      {
        Sid    = "SecretsManagerDatabaseCredentials"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          var.db_secret_arn
        ]
      },
      {
        Sid    = "SystemsManagerEnvironmentConfig"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/loan-processing/${var.environment}/*"
        ]
      },
      {
        Sid    = "CloudWatchLogsDeploymentLogging"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codedeploy/loan-processing-${var.environment}:*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/loan-processing-${var.environment}:*"
        ]
      },
      {
        Sid    = "KMSDecryptArtifacts"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.pipeline_artifacts.arn
      },
      {
        Sid    = "EC2DescribeTagsForEnvironmentDetection"
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach AWS managed policy for CodeDeploy agent
resource "aws_iam_role_policy_attachment" "ec2_codedeploy_agent" {
  role       = element(split("/", var.ec2_instance_role_arn), length(split("/", var.ec2_instance_role_arn)) - 1)
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}


# Module 2 CI/CD Resources — Linux/.NET 10 Pipeline
# This file defines all CI/CD resources for the Module 2 standalone root module.
# It provisions a complete Linux CI/CD pipeline: CodeBuild, CodeDeploy, CodePipeline,
# along with supporting resources (IAM roles, S3 bucket, KMS key, SNS topic, CloudWatch logs).
#
# The existing Module 1 Windows CI/CD pipeline is NOT modified — this is an entirely
# separate pipeline that builds and deploys the .NET 10 application to Linux instances.

# ---------------------------------------------------------------------------
# Random Suffix for Unique Resource Names
# ---------------------------------------------------------------------------

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ===========================================================================
# IAM Roles
# ===========================================================================

# ---------------------------------------------------------------------------
# IAM Role — CodeBuild
# ---------------------------------------------------------------------------

resource "aws_iam_role" "codebuild" {
  name = "${local.name_prefix}-linux-codebuild"

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

  tags = {
    Name = "${local.name_prefix}-linux-codebuild"
  }
}

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
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.name_prefix}-linux",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${local.name_prefix}-linux:*"
        ]
      }
    ]
  })
}

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

# ---------------------------------------------------------------------------
# IAM Role — CodeDeploy
# ---------------------------------------------------------------------------

resource "aws_iam_role" "codedeploy" {
  name = "${local.name_prefix}-linux-codedeploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-linux-codedeploy"
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_managed" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_iam_role_policy" "codedeploy_s3" {
  name = "codedeploy-s3-access"
  role = aws_iam_role.codedeploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
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
      }
    ]
  })
}

resource "aws_iam_role_policy" "codedeploy_autoscaling" {
  name = "codedeploy-autoscaling-access"
  role = aws_iam_role.codedeploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:CompleteLifecycleAction",
          "autoscaling:DeleteLifecycleHook",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeLifecycleHooks",
          "autoscaling:PutLifecycleHook",
          "autoscaling:RecordLifecycleActionHeartbeat",
          "autoscaling:CreateAutoScalingGroup",
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:EnableMetricsCollection",
          "autoscaling:DescribePolicies",
          "autoscaling:DescribeScheduledActions",
          "autoscaling:DescribeNotificationConfigurations",
          "autoscaling:SuspendProcesses",
          "autoscaling:ResumeProcesses",
          "autoscaling:AttachLoadBalancers",
          "autoscaling:AttachLoadBalancerTargetGroups",
          "autoscaling:PutScalingPolicy",
          "autoscaling:PutScheduledUpdateGroupAction",
          "autoscaling:PutNotificationConfiguration",
          "autoscaling:PutWarmPool",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DeleteAutoScalingGroup"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codedeploy_elb" {
  name = "codedeploy-elb-access"
  role = aws_iam_role.codedeploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codedeploy_sns" {
  name = "codedeploy-sns-access"
  role = aws_iam_role.codedeploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.pipeline_notifications.arn
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# IAM Role — CodePipeline
# ---------------------------------------------------------------------------

resource "aws_iam_role" "codepipeline" {
  name = "${local.name_prefix}-linux-codepipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-linux-codepipeline"
  }
}

resource "aws_iam_role_policy" "codepipeline_s3" {
  name = "codepipeline-s3-access"
  role = aws_iam_role.codepipeline.id

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

resource "aws_iam_role_policy" "codepipeline_kms" {
  name = "codepipeline-kms-access"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.pipeline_artifacts.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_codebuild" {
  name = "codepipeline-codebuild-access"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Resource = aws_codebuild_project.linux.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_codedeploy" {
  name = "codepipeline-codedeploy-access"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision"
        ]
        Resource = [
          "arn:aws:codedeploy:${var.aws_region}:${data.aws_caller_identity.current.account_id}:application:${aws_codedeploy_app.linux.name}",
          "arn:aws:codedeploy:${var.aws_region}:${data.aws_caller_identity.current.account_id}:deploymentgroup:${aws_codedeploy_app.linux.name}/*",
          "arn:aws:codedeploy:${var.aws_region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_codestar" {
  name = "codepipeline-codestar-access"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = var.github_connection_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_sns" {
  name = "codepipeline-sns-access"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.pipeline_notifications.arn
      }
    ]
  })
}

# ===========================================================================
# S3 Bucket for Pipeline Artifacts
# ===========================================================================

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "${local.name_prefix}-linux-artifacts-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name    = "${local.name_prefix}-linux-artifacts"
    Purpose = "CI/CD Pipeline Artifacts"
  }
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.pipeline_artifacts.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    id     = "delete-old-artifacts"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowCodePipelineAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.codepipeline.arn
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      },
      {
        Sid    = "AllowCodeBuildAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.codebuild.arn
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      },
      {
        Sid    = "AllowCodeDeployAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.codedeploy.arn
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      }
    ]
  })
}

# ===========================================================================
# KMS Key for Pipeline Artifact Encryption
# ===========================================================================

resource "aws_kms_key" "pipeline_artifacts" {
  description             = "KMS key for encrypting Module 2 Linux CI/CD pipeline artifacts"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name    = "${local.name_prefix}-linux-pipeline-key"
    Purpose = "CI/CD Pipeline Artifact Encryption"
  }
}

resource "aws_kms_key_policy" "pipeline_artifacts" {
  key_id = aws_kms_key.pipeline_artifacts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableIAMUserPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCodePipelineToUseKey"
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
        Sid    = "AllowCodeBuildToUseKey"
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
        Sid    = "AllowCodeDeployToUseKey"
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
        Sid    = "AllowS3ToUseKey"
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

resource "aws_kms_alias" "pipeline_artifacts" {
  name          = "alias/${local.name_prefix}-linux-pipeline"
  target_key_id = aws_kms_key.pipeline_artifacts.key_id
}

# ===========================================================================
# SNS Topic for Pipeline Notifications
# ===========================================================================

resource "aws_sns_topic" "pipeline_notifications" {
  name         = "${local.name_prefix}-linux-pipeline-notifications"
  display_name = "Loan Processing Linux Pipeline Notifications (${var.environment})"

  tags = {
    Name = "${local.name_prefix}-linux-pipeline-notifications"
  }
}

resource "aws_sns_topic_subscription" "pipeline_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.pipeline_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_sns_topic_policy" "pipeline_notifications" {
  arn = aws_sns_topic.pipeline_notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCodePipelinePublish"
        Effect = "Allow"
        Principal = {
          Service = "codestar-notifications.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.pipeline_notifications.arn
      },
      {
        Sid    = "AllowCodeDeployPublish"
        Effect = "Allow"
        Principal = {
          Service = "codedeploy.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.pipeline_notifications.arn
      },
      {
        Sid    = "AllowEventsPublish"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.pipeline_notifications.arn
      }
    ]
  })
}

# ===========================================================================
# CloudWatch Log Group for CodeBuild
# ===========================================================================

resource "aws_cloudwatch_log_group" "codebuild_linux" {
  name              = "/aws/codebuild/${local.name_prefix}-linux"
  retention_in_days = 30

  tags = {
    Name     = "codebuild-linux-logs-${var.environment}"
    Platform = "linux"
  }
}

# ===========================================================================
# CodeBuild Project — Linux/.NET 10
# ===========================================================================

resource "aws_codebuild_project" "linux" {
  name          = "${local.name_prefix}-linux"
  description   = "Build project for .NET 10 loan processing application on Linux"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.pipeline_artifacts.bucket}/build-cache-linux"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }

    environment_variable {
      name  = "AWS_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "ARTIFACT_BUCKET"
      value = aws_s3_bucket.pipeline_artifacts.bucket
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild_linux.name
      stream_name = "build-logs"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "aws-deployment/buildspec-linux.yml"
  }

  tags = {
    Name     = "${local.name_prefix}-linux-codebuild"
    Platform = "linux"
  }
}

# ===========================================================================
# CodeDeploy Application and Deployment Group — Linux
# ===========================================================================

resource "aws_codedeploy_app" "linux" {
  name             = "${local.name_prefix}-linux"
  compute_platform = "Server"

  tags = {
    Name     = "${local.name_prefix}-linux"
    Platform = "linux"
  }
}

resource "aws_codedeploy_deployment_group" "linux" {
  app_name              = aws_codedeploy_app.linux.name
  deployment_group_name = "${local.name_prefix}-linux"
  service_role_arn      = aws_iam_role.codedeploy.arn

  deployment_config_name = "CodeDeployDefault.OneAtATime"

  autoscaling_groups = [aws_autoscaling_group.linux.name]

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.linux.name
    }
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE", "DEPLOYMENT_STOP_ON_ALARM"]
  }

  trigger_configuration {
    trigger_events = [
      "DeploymentStart",
      "DeploymentSuccess",
      "DeploymentFailure",
      "DeploymentRollback"
    ]
    trigger_name       = "linux-deployment-notifications-${var.environment}"
    trigger_target_arn = aws_sns_topic.pipeline_notifications.arn
  }

  tags = {
    Name     = "${local.name_prefix}-linux"
    Platform = "linux"
  }
}

# ===========================================================================
# CodePipeline — Linux/.NET 10
# ===========================================================================

resource "aws_codepipeline" "linux" {
  name     = "${local.name_prefix}-linux-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.pipeline_artifacts.bucket

    encryption_key {
      id   = aws_kms_key.pipeline_artifacts.arn
      type = "KMS"
    }
  }

  # Source Stage: GitHub Integration via CodeStar Connection
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = var.github_connection_arn
        FullRepositoryId     = var.github_repository_id
        BranchName           = var.github_branch_name
        DetectChanges        = "true"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  # Build Stage: Linux CodeBuild Compilation
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.linux.name
      }
    }
  }

  # Deploy Stage: CodeDeploy to Linux EC2 Instances
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ApplicationName     = aws_codedeploy_app.linux.name
        DeploymentGroupName = aws_codedeploy_deployment_group.linux.deployment_group_name
      }
    }
  }

  tags = {
    Name     = "${local.name_prefix}-linux-pipeline"
    Platform = "linux"
  }
}

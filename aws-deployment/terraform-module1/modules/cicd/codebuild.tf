# CodeBuild Project for .NET Framework Application
# This project compiles the LoanProcessing application and creates deployment artifacts
# Requirements: 2.1, 2.7, 14.1, 14.2

resource "aws_codebuild_project" "loan_processing" {
  name          = "loan-processing-${var.environment}"
  description   = "Build project for .NET Framework loan processing application"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type     = "S3"
    location = "${aws_s3_bucket.pipeline_artifacts.bucket}/build-cache"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/windows-base:2019-3.0"
    type                        = "WINDOWS_SERVER_2019_CONTAINER"
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
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "build-logs"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-codebuild-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}

# CloudWatch Log Group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/loan-processing-${var.environment}"
  retention_in_days = 30

  tags = merge(
    var.common_tags,
    {
      Name        = "codebuild-logs-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}

# Linux CodeBuild Project for .NET 10 Application
# This project compiles the LoanProcessing application using dotnet CLI on Linux
# Requirements: 8.1, 8.2, 10.3

resource "aws_codebuild_project" "linux" {
  name          = "loan-processing-linux-${var.environment}"
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

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-linux-codebuild-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      Platform    = "linux"
      ManagedBy   = "terraform"
    }
  )
}

# CloudWatch Log Group for Linux CodeBuild
resource "aws_cloudwatch_log_group" "codebuild_linux" {
  name              = "/aws/codebuild/loan-processing-linux-${var.environment}"
  retention_in_days = 30

  tags = merge(
    var.common_tags,
    {
      Name        = "codebuild-linux-logs-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      Platform    = "linux"
      ManagedBy   = "terraform"
    }
  )
}

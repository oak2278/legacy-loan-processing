# CodePipeline for CI/CD Orchestration
# This pipeline orchestrates the entire CI/CD workflow from GitHub to AWS
# Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 12.1

resource "aws_codepipeline" "loan_processing" {
  name     = "loan-processing-pipeline-${var.environment}"
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

  # Build Stage: CodeBuild Compilation
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
        ProjectName = aws_codebuild_project.loan_processing.name
      }
    }
  }

  # Manual Approval Stage: Production Deployment Approval
  # Only enabled when var.require_manual_approval is true (typically for production)
  # Requirements: 11.3
  dynamic "stage" {
    for_each = var.require_manual_approval ? [1] : []

    content {
      name = "Approval"

      action {
        name     = "ManualApproval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"

        configuration = {
          CustomData         = "Please review the build artifacts and approve deployment to ${var.environment} environment."
          ExternalEntityLink = "https://console.aws.amazon.com/codesuite/codepipeline/pipelines/loan-processing-pipeline-${var.environment}/view"
          NotificationArn    = aws_sns_topic.pipeline_notifications.arn
        }
      }
    }
  }

  # Deploy Stage: CodeDeploy to EC2 Instances
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
        ApplicationName     = aws_codedeploy_app.loan_processing.name
        DeploymentGroupName = aws_codedeploy_deployment_group.loan_processing.deployment_group_name
      }
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-pipeline-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}

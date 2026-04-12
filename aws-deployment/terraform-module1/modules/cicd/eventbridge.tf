# EventBridge Rules for CodePipeline Notifications
# This file creates EventBridge rules to capture pipeline state changes and send notifications to SNS
# Requirements: 10.1, 10.2, 10.3

# EventBridge Rule for Pipeline State Changes
resource "aws_cloudwatch_event_rule" "pipeline_state_changes" {
  name        = "loan-processing-pipeline-state-changes-${var.environment}"
  description = "Capture CodePipeline state changes (STARTED, SUCCEEDED, FAILED) for loan processing pipeline"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Pipeline Execution State Change"]
    detail = {
      pipeline = [aws_codepipeline.loan_processing.name]
      state    = ["STARTED", "SUCCEEDED", "FAILED"]
    }
  })

  tags = merge(
    var.common_tags,
    {
      Name        = "loan-processing-pipeline-state-changes-${var.environment}"
      Environment = var.environment
      Project     = "loan-processing"
      ManagedBy   = "terraform"
    }
  )
}

# EventBridge Target: Publish to SNS Topic
resource "aws_cloudwatch_event_target" "pipeline_notifications" {
  rule      = aws_cloudwatch_event_rule.pipeline_state_changes.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.pipeline_notifications.arn

  input_transformer {
    input_paths = {
      pipeline  = "$.detail.pipeline"
      state     = "$.detail.state"
      execution = "$.detail.execution-id"
      time      = "$.time"
      account   = "$.account"
      region    = "$.region"
    }

    input_template = <<-EOT
    {
      "notification_type": "CodePipeline State Change",
      "pipeline_name": "<pipeline>",
      "execution_id": "<execution>",
      "state": "<state>",
      "timestamp": "<time>",
      "account_id": "<account>",
      "region": "<region>",
      "message": "Pipeline <pipeline> has <state>",
      "details": {
        "environment": "${var.environment}",
        "execution_id": "<execution>",
        "console_url": "https://console.aws.amazon.com/codesuite/codepipeline/pipelines/<pipeline>/executions/<execution>/timeline?region=<region>"
      }
    }
    EOT
  }
}

# IAM Role for EventBridge to publish to SNS (if not already exists)
# Note: The SNS topic policy already allows events.amazonaws.com to publish
# This is just for explicit role-based access if needed


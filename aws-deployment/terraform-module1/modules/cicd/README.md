# CI/CD Module

This Terraform module creates the AWS infrastructure required for the GitHub to AWS CI/CD pipeline for the loan processing application.

## Components

### S3 Bucket for Pipeline Artifacts

The module creates an S3 bucket to store CodeBuild artifacts and CodeDeploy deployment packages with the following features:

- **Environment-specific naming**: `loan-processing-artifacts-{environment}-{account-id}`
- **Versioning enabled**: Maintains artifact history for rollback capability
- **KMS encryption**: Server-side encryption using AWS KMS for security
- **Lifecycle policy**: Automatically deletes artifacts older than 30 days
- **Restricted access**: Bucket policy limits access to pipeline IAM roles only
- **Public access blocked**: All public access is explicitly blocked
- **TLS enforcement**: Denies all non-HTTPS requests

### Parameter Store Configuration

The module creates AWS Systems Manager Parameter Store entries for environment-specific configuration values used by deployment scripts:

- **Application Pool Name**: `/loan-processing/{environment}/app-pool-name` - IIS application pool name (default: "LoanProcessingAppPool")
- **Website Name**: `/loan-processing/{environment}/site-name` - IIS website name (default: "LoanProcessing")
- **Deployment Path**: `/loan-processing/{environment}/deployment-path` - Application deployment path (default: "C:\inetpub\wwwroot\LoanProcessing")
- **Notification Email**: `/loan-processing/{environment}/notification-email` - Email address for notifications (from variable)
- **Database Secret ARN**: `/loan-processing/{environment}/db-secret-arn` - ARN of the Secrets Manager secret containing database credentials (from variable)

These parameters enable environment-specific configuration without hardcoding values in deployment scripts. The EC2 instance IAM role has read access to these parameters via the `SystemsManagerEnvironmentConfig` policy.

### CloudWatch Monitoring and Alarms

The module creates comprehensive monitoring for the CI/CD pipeline:

#### Log Groups
- **CodeBuild Logs**: `/aws/codebuild/loan-processing-{environment}` - Build execution logs
- **CodeDeploy Logs**: `/aws/codedeploy/loan-processing-{environment}` - Deployment logs
- **CodePipeline Logs**: `/aws/codepipeline/loan-processing-{environment}` - Pipeline orchestration logs

#### Metric Filters
- **Build Failures**: Extracts build failure count from CodeBuild logs
- **Deployment Failures**: Extracts deployment failure count from CodeDeploy logs
- **Credential Exposure**: Monitors all logs for potential credential leaks (security)

#### CloudWatch Alarms
The module creates three critical alarms that monitor pipeline health:

1. **Repeated Build Failures Alarm**
   - Triggers when 3 or more builds fail within 1 hour
   - Indicates systemic build issues (broken dependencies, code problems)
   - Severity: High

2. **Repeated Deployment Failures Alarm**
   - Triggers when 2 or more deployments fail within 1 hour
   - Indicates deployment script or infrastructure issues
   - Severity: Critical
   - **Linked to CodeDeploy auto-rollback**

3. **Deployment Duration Exceeded Alarm**
   - Triggers when deployment takes longer than 15 minutes
   - Indicates performance issues or stuck processes
   - Severity: Medium
   - **Linked to CodeDeploy auto-rollback**

All alarms are integrated with CodeDeploy's auto-rollback configuration to automatically revert failed deployments.

## Requirements

- AWS Provider >= 4.0
- Terraform >= 1.0

## Usage

```hcl
module "cicd" {
  source = "./modules/cicd"

  environment              = "production"
  kms_key_arn             = aws_kms_key.pipeline_key.arn
  codepipeline_role_arn   = aws_iam_role.codepipeline.arn
  codebuild_role_arn      = aws_iam_role.codebuild.arn
  codedeploy_role_arn     = aws_iam_role.codedeploy.arn
  ec2_instance_role_arn   = aws_iam_role.ec2_instance.arn

  common_tags = {
    Project    = "LoanProcessing"
    ManagedBy  = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| environment | Environment name (dev, staging, production) | string | yes |
| kms_key_arn | ARN of the KMS key for encrypting pipeline artifacts | string | yes |
| codepipeline_role_arn | ARN of the IAM role for CodePipeline | string | yes |
| codebuild_role_arn | ARN of the IAM role for CodeBuild | string | yes |
| codedeploy_role_arn | ARN of the IAM role for CodeDeploy | string | yes |
| ec2_instance_role_arn | ARN of the IAM role for EC2 instances | string | yes |
| common_tags | Common tags to apply to all resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| artifact_bucket_id | ID of the S3 bucket for pipeline artifacts |
| artifact_bucket_arn | ARN of the S3 bucket for pipeline artifacts |
| artifact_bucket_name | Name of the S3 bucket for pipeline artifacts |
| artifact_bucket_domain_name | Domain name of the S3 bucket for pipeline artifacts |
| deployment_failure_alarm_arn | ARN of the CloudWatch alarm for deployment failures |
| repeated_build_failures_alarm_arn | ARN of the CloudWatch alarm for repeated build failures |
| repeated_deployment_failures_alarm_arn | ARN of the CloudWatch alarm for repeated deployment failures |
| deployment_duration_exceeded_alarm_arn | ARN of the CloudWatch alarm for deployment duration exceeding threshold |
| ssm_parameter_app_pool_name | Name of the SSM parameter for IIS application pool name |
| ssm_parameter_site_name | Name of the SSM parameter for IIS website name |
| ssm_parameter_deployment_path | Name of the SSM parameter for deployment path |
| ssm_parameter_notification_email | Name of the SSM parameter for notification email |

## Security Features

1. **Encryption at Rest**: All artifacts are encrypted using AWS KMS
2. **Encryption in Transit**: Bucket policy enforces HTTPS-only access
3. **Least Privilege Access**: Bucket policy grants minimal required permissions to each role
4. **Public Access Prevention**: All public access is blocked at the bucket level
5. **Audit Trail**: S3 versioning maintains history of all artifact changes

## Lifecycle Management

The bucket automatically manages artifact retention:

- **Artifact Expiration**: Current versions are deleted after 30 days
- **Version Expiration**: Non-current versions are deleted after 30 days
- **Multipart Upload Cleanup**: Incomplete uploads are aborted after 7 days

This ensures the bucket doesn't accumulate unnecessary storage costs while maintaining sufficient history for troubleshooting and rollback scenarios.

## Requirements Validation

This module satisfies the following requirements:

- **3.1**: Pipeline stores build artifacts in dedicated S3 bucket
- **3.7**: Pipeline retains artifacts for at least 30 days
- **11.4**: Pipeline uses environment-specific configuration from Parameter Store
- **12.3**: S3 buckets for artifacts have encryption enabled
- **13.2**: Pipeline encrypts artifacts in S3 using AWS KMS

## Future Enhancements

This module will be extended with additional CI/CD resources:

- KMS key for artifact encryption (Task 6.2)
- IAM roles for CodePipeline, CodeBuild, and CodeDeploy (Tasks 6.3-6.6)
- CodeBuild project configuration (Task 6.7)
- CodeDeploy application and deployment group (Task 6.8)
- CodePipeline orchestration (Task 6.9)
- EventBridge rules for monorepo path filtering (Task 6.10)

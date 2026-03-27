# CI/CD Pipeline Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the automated CI/CD pipeline that builds and deploys the Legacy .NET Framework Loan Processing Application from GitHub to AWS.

**What you'll deploy:**
- AWS CodePipeline for orchestration
- AWS CodeBuild for .NET compilation
- AWS CodeDeploy for automated deployments
- Supporting infrastructure (VPC, EC2, RDS, ALB)
- Monitoring and notifications

**Estimated deployment time:** 30-45 minutes

---

## Prerequisites

### Required Tools

- **Terraform** >= 1.5.0
- **AWS CLI** >= 2.0
- **Git**
- **Text editor** (VS Code recommended)

### AWS Account Requirements

- AWS account with administrative access
- AWS CLI configured with credentials
- Sufficient service limits for:
  - CodePipeline (1 pipeline)
  - CodeBuild (1 project)
  - CodeDeploy (1 application)
  - EC2 (2 t3.medium instances)
  - RDS SQL Server (1 db.t3.small instance)

### GitHub Requirements

- Access to repository: `aws-shawn/legacy-loan-processing`
- Permissions to create webhooks
- Ability to push commits

---

## Step 1: Create GitHub CodeConnection

AWS CodePipeline needs a connection to GitHub to monitor repository changes.

### 1.1 Create Connection via AWS Console

1. Sign in to the AWS Console and open the Developer Tools console:
   ```
   https://console.aws.amazon.com/codesuite/settings/connections
   ```

2. Choose **Settings > Connections**, then click **"Create connection"**

3. Under **Select a provider**, choose **"GitHub"**

4. Enter connection name: `github-loan-processing`

5. Click **"Connect to GitHub"**

6. On the access request page, click **"Authorize AWS Connector for GitHub"**

7. Under **GitHub Apps**, choose an existing app installation or click **"Install a new app"**:
   - Select the GitHub account where your repository lives
   - On the Install page, leave defaults and click **"Install"**
   - If prompted about updated permissions, click **"Accept new permissions"**

8. Back on the **Connect to GitHub** page, your app installation should appear. Click **"Connect"**

9. Verify the connection shows as **"Available"** in the connections list

### 1.2 Copy Connection ARN

After creation, copy the Connection ARN. It looks like:
```
arn:aws:codestar-connections:eu-west-2:123456789012:connection/abc123def456
```

**Save this ARN** - you'll need it in the next step.

---

## Step 2: Configure Terraform Variables

### 2.1 Navigate to Terraform Directory

```bash
cd aws-deployment/terraform
```

### 2.2 Create terraform.tfvars

Copy the example file:
```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2.3 Edit terraform.tfvars

Open `terraform.tfvars` and update these required values:

```hcl
# General Configuration
aws_region   = "eu-west-2"              # Your AWS region
aws_profile  = "your-profile-name"      # Your AWS CLI profile
environment  = "dev"                    # Environment name (dev/staging/prod)

# CI/CD Configuration (REQUIRED)
github_connection_arn = "arn:aws:codestar-connections:eu-west-2:ACCOUNT:connection/ID"
github_repository_id  = "aws-shawn/legacy-loan-processing"
github_branch_name    = "main"          # Branch to monitor

# Notifications (OPTIONAL)
notification_email = "your-email@example.com"  # Pipeline notifications
alarm_email        = "your-email@example.com"  # CloudWatch alarms
```

**Important variables to review:**
- `vpc_cidr` - Ensure no conflicts with existing VPCs
- `instance_type` - t3.medium recommended for .NET workloads
- `db_instance_class` - db.t3.small for dev/test
- `enable_nat_gateway` - Set to `true` if EC2 instances need internet access

### 2.4 Save the File

Save `terraform.tfvars` with your configuration.

---

## Step 3: Initialize Terraform

### 3.1 Initialize Terraform

```bash
terraform init
```

**Expected output:**
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

### 3.2 Validate Configuration

```bash
terraform validate
```

**Expected output:**
```
Success! The configuration is valid.
```

---

## Step 4: Review Deployment Plan

### 4.1 Generate Plan

```bash
terraform plan -out=tfplan
```

**Review the plan carefully.** You should see approximately 50-60 resources to be created:

**Key resources:**
- VPC and networking (subnets, route tables, internet gateway, NAT gateway)
- Security groups (ALB, EC2, RDS)
- EC2 instances and Auto Scaling Group
- Application Load Balancer
- RDS SQL Server instance
- CodePipeline, CodeBuild, CodeDeploy
- S3 bucket for artifacts
- KMS key for encryption
- IAM roles and policies
- CloudWatch log groups and alarms
- SNS topic for notifications
- Secrets Manager secret for database credentials

### 4.2 Verify No Errors

Ensure the plan completes without errors. Common issues:
- Missing required variables
- Invalid GitHub connection ARN
- AWS service limit conflicts
- VPC CIDR conflicts

---

## Step 5: Deploy Infrastructure

### 5.1 Apply Terraform Configuration

```bash
terraform apply tfplan
```

Or apply directly (will prompt for confirmation):
```bash
terraform apply
```

Type `yes` when prompted.

**Deployment time:** 15-20 minutes

**What's happening:**
1. Creating VPC and networking (2-3 min)
2. Creating RDS instance (10-12 min) - longest step
3. Creating EC2 instances and ALB (3-4 min)
4. Creating CI/CD resources (2-3 min)
5. Configuring monitoring and notifications (1-2 min)

### 5.2 Monitor Progress

Watch for any errors during deployment. Terraform will show progress for each resource.

### 5.3 Save Outputs

When complete, save the outputs:
```bash
terraform output > deployment-outputs.txt
```

**Important outputs:**
- `alb_dns_name` - Application URL
- `codepipeline_url` - Pipeline console URL
- `artifact_bucket_name` - S3 bucket for builds
- `db_endpoint` - RDS endpoint (for troubleshooting)

---

## Step 6: Verify Infrastructure Deployment

### 6.1 Check Resource Counts

```bash
# Count created resources
terraform state list | wc -l
```

Expected: 50-60 resources

### 6.2 Verify CodePipeline

```bash
aws codepipeline get-pipeline --name loan-processing-pipeline-dev
```

Should return pipeline configuration without errors.

### 6.3 Verify CodeBuild Project

```bash
aws codebuild list-projects
```

Should include: `loan-processing-build-dev`

### 6.4 Verify CodeDeploy Application

```bash
aws deploy list-applications
```

Should include: `loan-processing-dev`

### 6.5 Verify EC2 Instances

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]' \
  --output table
```

Should show running instances.

### 6.6 Verify RDS Instance

```bash
aws rds describe-db-instances \
  --db-instance-identifier loanprocessing-dev-db \
  --query 'DBInstances[0].[DBInstanceStatus,Endpoint.Address]' \
  --output table
```

Should show "available" status.

---

## Step 7: Trigger the Pipeline

### 7.1 Make a Test Commit

The pipeline automatically triggers on commits to the main branch:

```bash
# Make an empty commit to trigger pipeline
git commit --allow-empty -m "Test pipeline deployment"
git push origin main
```

### 7.2 Monitor Pipeline Execution

Open the CodePipeline console:
```bash
# Get pipeline URL from outputs
terraform output codepipeline_url
```

Or use CLI:
```bash
aws codepipeline get-pipeline-state \
  --name loan-processing-pipeline-dev
```

### 7.3 Watch Pipeline Stages

The pipeline has 3 stages:

1. **Source** (1-2 min): Fetches code from GitHub
2. **Build** (5-8 min): Compiles .NET application, packages artifacts
3. **Deploy** (8-12 min): Deploys to EC2 instances using CodeDeploy

**Total pipeline time:** 15-20 minutes for first run

---

## Step 8: Monitor Build Stage

### 8.1 View Build Logs

```bash
# Tail build logs in real-time
aws logs tail /aws/codebuild/loan-processing-build-dev --follow
```

### 8.2 Check Build Status

```bash
aws codebuild list-builds-for-project \
  --project-name loan-processing-build-dev \
  --max-items 5
```

### 8.3 Verify Build Artifacts

After build completes:
```bash
# List artifacts in S3
BUCKET=$(terraform output -raw artifact_bucket_name)
aws s3 ls s3://$BUCKET/ --recursive
```

Should show deployment package with commit SHA.

---

## Step 9: Monitor Deployment Stage

### 9.1 View Deployment Logs

```bash
# Tail deployment logs
aws logs tail /aws/codedeploy/loan-processing-dev --follow
```

### 9.2 Check Deployment Status

```bash
aws deploy list-deployments \
  --application-name loan-processing-dev \
  --max-items 5
```

### 9.3 Get Deployment Details

```bash
# Get latest deployment ID
DEPLOYMENT_ID=$(aws deploy list-deployments \
  --application-name loan-processing-dev \
  --query 'deployments[0]' \
  --output text)

# Get deployment details
aws deploy get-deployment --deployment-id $DEPLOYMENT_ID
```

### 9.4 Monitor Instance Deployments

```bash
# Check deployment status on each instance
aws deploy list-deployment-instances \
  --deployment-id $DEPLOYMENT_ID
```

---

## Step 10: Verify Application Deployment

### 10.1 Get Application URL

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Application URL: http://$ALB_DNS"
```

### 10.2 Check ALB Target Health

```bash
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn)
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN
```

**Expected:** All targets should show `healthy` state.

### 10.3 Test Application Access

```bash
# Test HTTP response
curl -I http://$ALB_DNS
```

**Expected:** HTTP 200 OK

### 10.4 Open in Browser

```bash
# Open application in default browser (Windows)
start http://$ALB_DNS

# Or manually navigate to the URL
```

**Expected:** Loan Processing application home page loads.

---

## Step 11: Verify Database Initialization

### 11.1 Check Database Connection

Navigate to the Customers page in the application and verify it loads without errors.

### 11.2 Test Database Operations

1. Click "Create New Customer"
2. Fill in customer details
3. Click "Save"
4. Verify customer appears in the list

This confirms:
- Database connection is working
- Web.config was updated correctly
- Database schema was initialized
- Sample data was loaded

---

## Step 12: Test Rollback Capability

### 12.1 Inject a Deployment Failure

Create a commit that will cause deployment to fail:

```bash
# Temporarily break the application
echo "INVALID CODE" >> LoanProcessing.Web/Global.asax
git add .
git commit -m "Test rollback"
git push origin main
```

### 12.2 Monitor Rollback

Watch the pipeline fail and trigger automatic rollback:

```bash
aws codepipeline get-pipeline-state \
  --name loan-processing-pipeline-dev
```

### 12.3 Verify Application Still Works

```bash
curl -I http://$ALB_DNS
```

**Expected:** Application still returns HTTP 200 (rolled back to previous version)

### 12.4 Fix and Redeploy

```bash
# Revert the breaking change
git revert HEAD
git push origin main
```

Pipeline should succeed on the next run.

---

## Step 13: Verify Monitoring and Notifications

### 13.1 Check CloudWatch Logs

```bash
# View pipeline logs
aws logs tail /aws/codepipeline/loan-processing-dev --since 1h

# View build logs
aws logs tail /aws/codebuild/loan-processing-build-dev --since 1h

# View deployment logs
aws logs tail /aws/codedeploy/loan-processing-dev --since 1h
```

### 13.2 Check CloudWatch Alarms

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix loan-processing-dev
```

### 13.3 Verify SNS Notifications

Check your email for notifications:
- Pipeline started
- Build succeeded/failed
- Deployment succeeded/failed
- Rollback triggered (if tested)

### 13.4 View CloudWatch Metrics

Open CloudWatch console and check:
- Pipeline execution duration
- Build success rate
- Deployment success rate
- Application performance metrics

---

## Step 14: Validate All Requirements

### Checklist

- [ ] Pipeline triggers automatically on GitHub commits
- [ ] Build compiles .NET application successfully
- [ ] Artifacts are stored in S3 with encryption
- [ ] Deployment deploys to all EC2 instances
- [ ] Application is accessible via ALB
- [ ] Database is initialized correctly
- [ ] Rollback works on deployment failure
- [ ] SNS notifications are received
- [ ] CloudWatch logs contain all events
- [ ] Health checks pass
- [ ] IIS is configured correctly
- [ ] Web.config has correct connection string

---

## Troubleshooting

### Pipeline Not Triggering

**Issue:** Pipeline doesn't start after git push

**Solutions:**
1. Verify GitHub connection status:
   ```bash
   aws codestar-connections get-connection \
     --connection-arn <your-connection-arn>
   ```
   Status should be "AVAILABLE"

2. Check EventBridge rule:
   ```bash
   aws events list-rules --name-prefix loan-processing
   ```

3. Manually trigger pipeline:
   ```bash
   aws codepipeline start-pipeline-execution \
     --name loan-processing-pipeline-dev
   ```

### Build Failures

**Issue:** CodeBuild fails during compilation

**Solutions:**
1. Check build logs:
   ```bash
   aws logs tail /aws/codebuild/loan-processing-build-dev --follow
   ```

2. Common issues:
   - NuGet package restore failures → Check internet connectivity
   - MSBuild compilation errors → Check code syntax
   - Missing dependencies → Verify buildspec.yml

3. Test build locally:
   ```bash
   nuget restore LoanProcessing.sln
   msbuild LoanProcessing.sln /p:Configuration=Release
   ```

### Deployment Failures

**Issue:** CodeDeploy fails to deploy application

**Solutions:**
1. Check CodeDeploy agent status:
   ```bash
   aws ssm send-command \
     --document-name "AWS-RunPowerShellScript" \
     --targets "Key=tag:Environment,Values=dev" \
     --parameters 'commands=["Get-Service codedeployagent"]'
   ```

2. Check deployment logs:
   ```bash
   aws logs tail /aws/codedeploy/loan-processing-dev --follow
   ```

3. Common issues:
   - Agent not running → Restart CodeDeploy agent
   - Lifecycle hook failures → Check PowerShell script errors
   - Health check failures → Verify IIS and application status

### Application Not Accessible

**Issue:** ALB returns 503 or connection timeout

**Solutions:**
1. Check target health:
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw target_group_arn)
   ```

2. Check security groups:
   ```bash
   # Verify ALB security group allows port 80
   # Verify EC2 security group allows traffic from ALB
   ```

3. Check IIS status on EC2:
   ```bash
   # Connect via Session Manager
   Get-Service W3SVC
   Get-Website
   ```

### Database Connection Errors

**Issue:** Application can't connect to database

**Solutions:**
1. Verify Secrets Manager secret:
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id loan-processing-dev-db-credentials
   ```

2. Check RDS security group:
   ```bash
   # Verify RDS security group allows traffic from EC2 security group
   ```

3. Test database connectivity from EC2:
   ```powershell
   sqlcmd -S <rds-endpoint> -U sqladmin -P <password> -Q "SELECT @@VERSION"
   ```

### Rollback Not Working

**Issue:** Automatic rollback doesn't trigger

**Solutions:**
1. Check CodeDeploy deployment group configuration:
   ```bash
   aws deploy get-deployment-group \
     --application-name loan-processing-dev \
     --deployment-group-name loan-processing-dev-dg
   ```

2. Verify auto-rollback is enabled:
   ```hcl
   # In Terraform: auto_rollback_configuration.enabled = true
   ```

3. Check CloudWatch alarms:
   ```bash
   aws cloudwatch describe-alarms \
     --alarm-name-prefix loan-processing-dev
   ```

---

## Cost Management

### Monitor Costs

```bash
# View cost by service (requires Cost Explorer API)
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

### Stop Resources to Save Costs

```bash
# Stop EC2 instances (when not in use)
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name loan-processing-dev-asg \
  --desired-capacity 0

# Stop RDS instance
aws rds stop-db-instance \
  --db-instance-identifier loanprocessing-dev-db
```

### Resume Resources

```bash
# Start EC2 instances
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name loan-processing-dev-asg \
  --desired-capacity 1

# Start RDS instance
aws rds start-db-instance \
  --db-instance-identifier loanprocessing-dev-db
```

---

## Cleanup

### Destroy All Resources

When you're done testing:

```bash
cd aws-deployment/terraform

# Empty S3 artifact bucket first
BUCKET=$(terraform output -raw artifact_bucket_name)
aws s3 rm s3://$BUCKET --recursive

# Destroy infrastructure
terraform destroy
```

Type `yes` when prompted.

**Destruction time:** 10-15 minutes

**What's deleted:**
- All CI/CD resources (CodePipeline, CodeBuild, CodeDeploy)
- EC2 instances and Auto Scaling Group
- RDS database (final snapshot created by default)
- VPC and all networking resources
- S3 buckets, KMS keys, IAM roles
- CloudWatch logs and alarms
- SNS topics

---

## Next Steps

### Production Deployment

For production environments:

1. **Enable manual approval:**
   ```hcl
   # In terraform.tfvars
   require_manual_approval = true
   ```

2. **Enable Multi-AZ RDS:**
   ```hcl
   db_multi_az = true
   ```

3. **Increase instance count:**
   ```hcl
   asg_min_size = 2
   asg_desired_capacity = 2
   ```

4. **Configure custom domain:**
   - Create Route 53 hosted zone
   - Add CNAME record pointing to ALB
   - Configure SSL certificate in ACM

5. **Enable WAF:**
   ```hcl
   enable_waf = true
   ```

### Multi-Environment Setup

Deploy separate environments:

```bash
# Development
terraform workspace new dev
terraform apply -var-file=dev.tfvars

# Staging
terraform workspace new staging
terraform apply -var-file=staging.tfvars

# Production
terraform workspace new prod
terraform apply -var-file=prod.tfvars
```

---

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review CloudWatch logs
3. Consult AWS documentation:
   - [CodePipeline](https://docs.aws.amazon.com/codepipeline/)
   - [CodeBuild](https://docs.aws.amazon.com/codebuild/)
   - [CodeDeploy](https://docs.aws.amazon.com/codedeploy/)
4. Open GitHub issue

---

**Deployment Guide Version:** 1.0  
**Last Updated:** 2024  
**Terraform Version:** >= 1.5.0  
**AWS Provider Version:** >= 5.0

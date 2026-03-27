# AWS Deployment - Legacy .NET Loan Processing Application

## Overview

This directory contains the automated CI/CD pipeline infrastructure for deploying the Legacy .NET Framework Loan Processing Application to AWS. The deployment uses AWS CodePipeline, CodeBuild, and CodeDeploy to provide fully automated builds and deployments from GitHub to EC2 instances running IIS.

## 🚀 Quick Navigation

**New to this deployment?** Start here:
- � [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Complete deployment and validation guide
- 🏗️ [ARCHITECTURE.md](ARCHITECTURE.md) - CI/CD pipeline architecture

**Ready to deploy?**
- � [terraform/terraform.tfvars.example](terraform/terraform.tfvars.example) - Configuration template
- 📘 [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Step-by-step deployment instructions

**Understanding the pipeline?**
- 📄 [buildspec.yml](../buildspec.yml) - CodeBuild configuration
- � [appspec.yml](appspec.yml) - CodeDeploy configuration
- � [codedeploy/](codedeploy/) - Deployment lifecycle hooksx

## Architecture

### CI/CD Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          GitHub Repository                           │
│                    aws-shawn/legacy-loan-processing                  │
└────────────────────────────┬────────────────────────────────────────┘
                             │ Push to main branch
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS CodePipeline                             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐   │
│  │   Source     │──▶│    Build     │──▶│      Deploy          │   │
│  │   (GitHub)   │   │  (CodeBuild) │   │   (CodeDeploy)       │   │
│  └──────────────┘   └──────────────┘   └──────────────────────┘   │
│         │                   │                      │                │
│         │                   ▼                      │                │
│         │          ┌─────────────────┐            │                │
│         │          │  S3 Artifacts   │◀───────────┘                │
│         │          │  (Encrypted)    │                             │
│         │          └─────────────────┘                             │
└─────────┴──────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      Target Environment (AWS)                        │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    VPC (10.1.0.0/16)                          │  │
│  │                                                                │  │
│  │  ┌──────────────────┐      ┌──────────────────┐             │  │
│  │  │  Public Subnet   │      │  Public Subnet   │             │  │
│  │  │   (AZ-1)         │      │   (AZ-2)         │             │  │
│  │  │                  │      │                  │             │  │
│  │  │  ┌────────────┐  │      │  ┌────────────┐  │             │  │
│  │  │  │    ALB     │◀─┼──────┼─►│    ALB     │  │             │  │
│  │  │  └────────────┘  │      │  └────────────┘  │             │  │
│  │  │        │         │      │        │         │             │  │
│  │  │  ┌────▼──────┐  │      │  ┌────▼──────┐  │             │  │
│  │  │  │ EC2 Win   │  │      │  │ EC2 Win   │  │             │  │
│  │  │  │ + IIS     │  │      │  │ + IIS     │  │             │  │
│  │  │  │ + CodeDep │  │      │  │ + CodeDep │  │             │  │
│  │  │  └───────────┘  │      │  └───────────┘  │             │  │
│  │  └──────────────────┘      └──────────────────┘             │  │
│  │           │                         │                       │  │
│  │  ┌────────▼─────────────────────────▼────────────┐         │  │
│  │  │         Private Subnet (Database)             │         │  │
│  │  │                                               │         │  │
│  │  │  ┌──────────────────────────────────────┐    │         │  │
│  │  │  │   RDS SQL Server                     │    │         │  │
│  │  │  │   - Credentials in Secrets Manager   │    │         │  │
│  │  │  │   - Automated Backups                │    │         │  │
│  │  │  └──────────────────────────────────────┘    │         │  │
│  │  └───────────────────────────────────────────────┘         │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  Supporting Services:                                               │
│  - CloudWatch Logs & Metrics (Pipeline & Application monitoring)   │
│  - SNS (Pipeline notifications)                                     │
│  - Secrets Manager (Database credentials)                           │
│  - Parameter Store (Environment configuration)                      │
│  - IAM (Roles & Policies)                                          │
└─────────────────────────────────────────────────────────────────────┘
```

### Components

1. **CI/CD Pipeline**
   - CodePipeline orchestrates the entire workflow
   - CodeBuild compiles .NET Framework application
   - CodeDeploy deploys to EC2 instances with zero downtime
   - S3 stores encrypted build artifacts
   - EventBridge filters monorepo changes

2. **Networking**
   - VPC with public and private subnets across 2 AZs
   - Internet Gateway for public access
   - NAT Gateway for outbound connectivity
   - Security Groups for network isolation

3. **Compute**
   - EC2 Windows Server 2022 instances (t3.medium)
   - IIS 10 with .NET Framework 4.7.2
   - CodeDeploy agent for automated deployments
   - Application Load Balancer for traffic distribution
   - Auto Scaling Group (rolling deployments)

4. **Database**
   - RDS SQL Server Express Edition
   - db.t3.small instance class
   - Automated backups (7-day retention)
   - Encryption at rest

5. **Security**
   - IAM roles with least privilege
   - Security Groups with minimal ports
   - Secrets Manager for database credentials
   - KMS encryption for artifacts
   - Systems Manager Session Manager (no SSH/RDP keys)

6. **Monitoring & Notifications**
   - CloudWatch Logs for pipeline and application
   - CloudWatch Metrics and Alarms
   - SNS notifications for pipeline events
   - Automatic rollback on deployment failures

## Cost Estimate (Monthly)

| Service | Configuration | Estimated Cost |
|---------|--------------|----------------|
| EC2 (t3.medium) | 1 instance, Windows | ~$60 |
| RDS SQL Server Express | db.t3.small | ~$40 |
| Application Load Balancer | 1 ALB | ~$20 |
| CodePipeline | 1 pipeline | $1 |
| CodeBuild | ~30 builds/month | ~$5 |
| S3 (Artifacts) | Minimal storage | ~$2 |
| Data Transfer | Minimal | ~$5 |
| CloudWatch | Logs & Metrics | ~$5 |
| **Total** | | **~$138/month** |

**Cost Optimization Notes:**
- Use EC2 Instance Scheduler to stop instances during non-work hours
- Consider Reserved Instances for long-term usage (40-60% savings)
- RDS Express Edition is free-tier eligible for first 12 months
- CodePipeline first pipeline is free

## Prerequisites

### Local Development Machine

1. **Terraform** (v1.5+)
   ```bash
   # Windows (using Chocolatey)
   choco install terraform
   
   # Or download from: https://www.terraform.io/downloads
   ```

2. **AWS CLI** (v2)
   ```bash
   # Windows
   msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi
   ```

3. **Git**
   ```bash
   # Windows
   winget install Git.Git
   ```

### AWS Account Setup

1. **AWS Account** with appropriate permissions
2. **IAM User** with programmatic access (or use AWS SSO)
3. **AWS CLI configured**:
   ```bash
   aws configure
   # Enter: Access Key ID, Secret Access Key, Region (eu-west-2), Output format (json)
   ```

4. **GitHub CodeConnections** (formerly CodeStar Connections)
   - Create connection to GitHub via AWS Console
   - Navigate to: Developer Tools → CodeConnections → Create connection
   - Authorize AWS to access your GitHub repository
   - Copy the Connection ARN for terraform.tfvars

## Directory Structure

```
aws-deployment/
├── README.md                          # This file
├── DEPLOYMENT_GUIDE.md              # Deployment and validation guide
├── ARCHITECTURE.md                   # Detailed architecture documentation
├── appspec.yml                       # CodeDeploy configuration
├── codedeploy/                       # CodeDeploy lifecycle hooks
│   ├── stop-application.ps1          # Stop IIS before deployment
│   ├── before-install.ps1            # Backup current application
│   ├── configure-application.ps1     # Configure Web.config and database
│   ├── start-application.ps1         # Start IIS after deployment
│   └── validate-deployment.ps1       # Health checks and validation
└── terraform/                        # Infrastructure as Code
    ├── main.tf                       # Main Terraform configuration
    ├── variables.tf                  # Input variables
    ├── outputs.tf                    # Output values
    ├── terraform.tfvars.example      # Example variable values
    ├── backend.tf                    # Terraform state configuration
    └── modules/
        ├── networking/               # VPC, subnets, security groups
        ├── compute/                  # EC2, ALB, Auto Scaling
        ├── database/                 # RDS SQL Server
        ├── security/                 # IAM roles, Secrets Manager
        ├── monitoring/               # CloudWatch configuration
        └── cicd/                     # CodePipeline, CodeBuild, CodeDeploy

buildspec.yml                         # CodeBuild configuration (root)
database/                             # SQL scripts for deployment
```

## Quick Start

### 1. Create GitHub CodeConnection

```bash
# Via AWS Console (recommended):
# 1. Go to: https://console.aws.amazon.com/codesuite/settings/connections
# 2. Create connection → Choose "GitHub"
# 3. Authorize AWS Connector for GitHub, install the GitHub App
# 4. Copy the Connection ARN

# Or via CLI:
aws codestar-connections create-connection \
  --provider-type GitHub \
  --connection-name loan-processing-github \
  --region eu-west-2
```

### 2. Configure Terraform Variables

```bash
# Navigate to deployment directory
cd aws-deployment/terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values (especially github_connection_arn)
notepad terraform.tfvars
```

Required variables:
- `github_connection_arn` - ARN from step 1
- `github_repository_id` - "aws-shawn/legacy-loan-processing"
- `github_branch_name` - "main" (or your branch)
- `notification_email` - Your email for pipeline notifications

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review and Deploy

```bash
# Review the plan
terraform plan

# Deploy infrastructure
terraform apply
```

### 5. Trigger the Pipeline

The pipeline automatically triggers on commits to the main branch. To test:

```bash
# Make a small change and push
git commit --allow-empty -m "Trigger pipeline"
git push origin main
```

Monitor the pipeline in AWS Console: CodePipeline → loan-processing-pipeline-{environment}

## Deployment Process

See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for comprehensive step-by-step deployment and validation instructions.

### Pipeline Workflow

1. **Source Stage**: CodePipeline detects commit to GitHub main branch
2. **Build Stage**: CodeBuild compiles .NET application and packages artifacts
3. **Deploy Stage**: CodeDeploy deploys to EC2 instances using rolling strategy
4. **Validation**: Health checks verify deployment success
5. **Notifications**: SNS sends email notifications on success/failure

### Deployment Lifecycle Hooks

CodeDeploy executes these scripts on each EC2 instance during deployment:

1. **ApplicationStop** (`stop-application.ps1`): Stops IIS and application pool
2. **BeforeInstall** (`before-install.ps1`): Backs up current application
3. **AfterInstall** (`configure-application.ps1`): Updates Web.config, initializes database
4. **ApplicationStart** (`start-application.ps1`): Starts IIS and application pool
5. **ValidateService** (`validate-deployment.ps1`): Performs health checks

## Post-Deployment

### Access the Application

1. Get the ALB DNS name:
   ```bash
   terraform output alb_dns_name
   ```

2. Open in browser:
   ```
   http://<alb-dns-name>
   ```

### Monitor the Pipeline

1. **CodePipeline Console**:
   ```
   https://console.aws.amazon.com/codesuite/codepipeline/pipelines
   ```

2. **View Build Logs**:
   ```bash
   aws logs tail /aws/codebuild/loan-processing-{environment} --follow
   ```

3. **View Deployment Logs**:
   ```bash
   aws logs tail /aws/codedeploy/loan-processing-{environment} --follow
   ```

### Verify Deployment

1. **Check Pipeline Status**:
   ```bash
   aws codepipeline get-pipeline-state \
     --name loan-processing-pipeline-{environment}
   ```

2. **Check Deployment Status**:
   ```bash
   aws deploy list-deployments \
     --application-name loan-processing-{environment} \
     --max-items 5
   ```

3. **Test Application**:
   - Navigate to Customers page
   - Create a test customer
   - Verify data is saved

## Monitoring

### CloudWatch Dashboards

Monitor pipeline and application health:
- Pipeline execution metrics
- Build success/failure rates
- Deployment duration
- Application performance
- Database metrics

### Alarms

Configured alarms:
- Repeated build failures (3 in 1 hour)
- Repeated deployment failures (2 in 1 hour)
- Deployment duration exceeds 15 minutes
- High CPU utilization (>80%)
- Database connection failures

### SNS Notifications

Email notifications sent for:
- Pipeline started
- Build succeeded/failed
- Deployment started
- Deployment succeeded/failed
- Rollback triggered

## Security Considerations

### Network Security

- Application Load Balancer in public subnets
- EC2 instances in public subnets (workshop simplicity)
- RDS in private subnets (no direct internet access)
- Security Groups with minimal required ports

### Access Control

- IAM roles for EC2 instances (no hardcoded credentials)
- Systems Manager Session Manager for instance access
- Secrets Manager for database credentials
- Parameter Store for configuration values

### Data Protection

- RDS encryption at rest (AWS KMS)
- S3 artifact encryption (AWS KMS)
- Automated backups (7-day retention)
- SSL/TLS for database connections
- CloudWatch Logs encryption
- Secrets Manager for credentials (never hardcoded)

### FSI Best Practices

- Audit logging enabled
- Encryption in transit and at rest
- Least privilege access
- Network segmentation
- Automated patching (optional)

## Maintenance

### Deploying Application Updates

Simply push code to GitHub - the pipeline handles everything:

```bash
# Make your code changes
git add .
git commit -m "Update feature X"
git push origin main

# Pipeline automatically:
# 1. Builds the application
# 2. Runs tests (if configured)
# 3. Deploys to EC2 instances
# 4. Validates deployment
# 5. Sends notification
```

### Manual Pipeline Trigger

```bash
aws codepipeline start-pipeline-execution \
  --name loan-processing-pipeline-{environment}
```

### Rollback

Automatic rollback occurs on deployment failure. For manual rollback:

```bash
# List recent deployments
aws deploy list-deployments \
  --application-name loan-processing-{environment}

# Get deployment details
aws deploy get-deployment --deployment-id <deployment-id>

# CodeDeploy automatically rolls back on failure
# Or redeploy a previous successful build from S3
```

## Troubleshooting

### Pipeline Issues

1. **Build fails**:
   ```bash
   # View build logs
   aws logs tail /aws/codebuild/loan-processing-{environment} --follow
   
   # Common issues:
   # - NuGet package restore failures
   # - MSBuild compilation errors
   # - Missing dependencies
   ```

2. **Deployment fails**:
   ```bash
   # View deployment logs
   aws logs tail /aws/codedeploy/loan-processing-{environment} --follow
   
   # Check deployment status
   aws deploy get-deployment --deployment-id <deployment-id>
   
   # Common issues:
   # - CodeDeploy agent not running
   # - Lifecycle hook script errors
   # - Health check failures
   ```

3. **Application not accessible**:
   ```bash
   # Check ALB target health
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output target_group_arn)
   
   # Check IIS status on EC2 (via Session Manager)
   Get-Service W3SVC
   Get-Website
   ```

### Quick Checks

```bash
# View pipeline execution history
aws codepipeline list-pipeline-executions \
  --pipeline-name loan-processing-pipeline-{environment}

# Check CodeDeploy agent status
aws ssm send-command \
  --document-name "AWS-RunPowerShellScript" \
  --targets "Key=tag:Environment,Values={environment}" \
  --parameters 'commands=["Get-Service codedeployagent"]'
```

## Cleanup

### Destroy Infrastructure

```bash
cd aws-deployment/terraform

# Destroy all resources
terraform destroy

# Confirm with 'yes'
```

**Warning**: This will delete all resources including:
- CodePipeline, CodeBuild, CodeDeploy
- EC2 instances and Auto Scaling Group
- RDS database (with final snapshot by default)
- S3 artifact bucket (must be empty first)
- All networking resources

### Empty S3 Bucket First

If terraform destroy fails due to non-empty S3 bucket:

```bash
# Get bucket name
BUCKET_NAME=$(terraform output -raw artifact_bucket_name)

# Empty the bucket
aws s3 rm s3://$BUCKET_NAME --recursive

# Try destroy again
terraform destroy
```

## CI/CD Pipeline Features

### Automated Workflow
- Automatic builds on GitHub commits
- Compiled .NET Framework application
- Encrypted artifact storage in S3
- Rolling deployments with zero downtime
- Automatic rollback on failures

### Monorepo Path Filtering
Pipeline only triggers on relevant file changes:
- Application code (`LoanProcessing.Web/`, `LoanProcessing.Core/`, etc.)
- Database scripts (`database/`)
- Deployment configs (`buildspec.yml`, `appspec.yml`, `terraform/`)
- Documentation changes do NOT trigger builds

### Multi-Environment Support
- Environment-specific configuration via terraform.tfvars
- Manual approval stage for production deployments
- Environment tagging for all resources
- Separate pipelines per environment (dev, staging, production)

### Security Best Practices
- IAM roles (no hardcoded credentials)
- KMS encryption for artifacts
- Secrets Manager for database credentials
- Least-privilege IAM policies
- Audit logging to CloudWatch

## Additional Resources

- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Complete step-by-step deployment guide
- [AWS CodePipeline Documentation](https://docs.aws.amazon.com/codepipeline/)
- [AWS CodeBuild Documentation](https://docs.aws.amazon.com/codebuild/)
- [AWS CodeDeploy Documentation](https://docs.aws.amazon.com/codedeploy/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## Support

For issues or questions:
1. Check [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) troubleshooting section
2. Review CloudWatch Logs for pipeline and deployment events
3. Consult AWS CodePipeline/CodeBuild/CodeDeploy documentation
4. Open GitHub issue

---

**Version**: 2.0.0 (CI/CD Pipeline)  
**Last Updated**: 2024  
**Terraform Version**: 1.5+  
**AWS Provider Version**: 5.0+

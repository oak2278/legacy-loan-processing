# AWS Architecture Documentation

## Overview

This document provides detailed architecture information for the Legacy .NET Loan Processing Application deployed on AWS.

## Architecture Principles

### Design Goals

1. **Cost-Effective**: Optimized for workshop/lab scenarios with minimal ongoing costs
2. **Lift-and-Shift**: Traditional Windows/IIS deployment pattern
3. **FSI-Aligned**: Security best practices suitable for financial services
4. **Modernization-Ready**: Foundation for future cloud-native transformation

### Architecture Patterns

- **Multi-AZ Deployment**: High availability for database tier
- **Load Balanced**: Application Load Balancer for traffic distribution
- **Auto Scaling**: Elastic compute capacity (configured for workshop scale)
- **Infrastructure as Code**: Terraform for repeatable deployments
- **Least Privilege**: IAM roles with minimal required permissions

## Network Architecture

### VPC Design

```
VPC: 10.0.0.0/16
├── Public Subnets (Internet-facing)
│   ├── 10.0.1.0/24 (us-east-1a)
│   └── 10.0.2.0/24 (us-east-1b)
└── Private Subnets (Database tier)
    ├── 10.0.10.0/24 (us-east-1a)
    └── 10.0.11.0/24 (us-east-1b)
```

### Network Components

**Internet Gateway**
- Provides internet connectivity for public subnets
- Enables inbound HTTP/HTTPS traffic to ALB
- Allows outbound internet access for EC2 instances

**Route Tables**
- Public route table: Routes 0.0.0.0/0 to Internet Gateway
- Private route table: No internet route (isolated database tier)

**NAT Gateway** (Optional)
- Disabled by default for cost savings
- Enable if EC2 instances need outbound internet access
- Required for Windows Updates, NuGet packages, etc.

### Security Groups

**ALB Security Group**
- Inbound: HTTP (80), HTTPS (443) from 0.0.0.0/0
- Outbound: All traffic
- Purpose: Public-facing load balancer

**Application Security Group**
- Inbound: HTTP (80), HTTPS (443) from ALB security group only
- Outbound: All traffic
- Purpose: EC2 instances running IIS

**Database Security Group**
- Inbound: SQL Server (1433) from Application security group only
- Outbound: All traffic
- Purpose: RDS SQL Server instances

### Network Flow

```
Internet → ALB (Public Subnet) → EC2 (Public Subnet) → RDS (Private Subnet)
```

## Compute Architecture

### EC2 Instances

**Instance Type**: t3.medium
- 2 vCPUs
- 4 GB RAM
- Burstable performance
- Cost: ~$0.0416/hour (~$30/month)

**Operating System**: Windows Server 2022
- Latest security patches
- .NET Framework 4.7.2
- IIS 10
- PowerShell 7

**Launch Template**
- Defines instance configuration
- User data script for automated setup
- IMDSv2 enforced for security
- Detailed monitoring enabled

### Auto Scaling Group

**Configuration**
- Min: 1 instance
- Max: 2 instances
- Desired: 1 instance
- Health check: ELB (ALB target health)
- Grace period: 300 seconds

**Scaling Policies**
- CPU-based: Target 70% CPU utilization
- Request-based: Target 1000 requests per target
- Cooldown: 300 seconds

**Instance Refresh**
- Strategy: Rolling
- Min healthy percentage: 50%
- Enables zero-downtime updates

### Application Load Balancer

**Configuration**
- Scheme: Internet-facing
- Type: Application (Layer 7)
- Cross-zone load balancing: Enabled
- HTTP/2: Enabled

**Target Group**
- Protocol: HTTP
- Port: 80
- Health check path: /
- Healthy threshold: 2
- Unhealthy threshold: 3
- Timeout: 5 seconds
- Interval: 30 seconds
- Stickiness: Enabled (86400 seconds)

**Listeners**
- HTTP (80): Forward to target group
- HTTPS (443): Not configured (can be added)

## Database Architecture

### RDS SQL Server

**Engine**: SQL Server Express Edition
- Version: 2019 (15.00.4335.1.v1)
- License: Included
- Free tier eligible (first 12 months)

**Instance Class**: db.t3.small
- 2 vCPUs
- 2 GB RAM
- Cost: ~$40/month (Multi-AZ: ~$80/month)

**Storage**
- Type: General Purpose SSD (gp3)
- Size: 20 GB
- Encryption: Enabled (AWS KMS)
- Auto-scaling: Not configured

**Multi-AZ Deployment**
- Primary: us-east-1a
- Standby: us-east-1b
- Automatic failover: Enabled
- Synchronous replication

**Backup Configuration**
- Automated backups: Enabled
- Retention period: 7 days
- Backup window: 03:00-04:00 UTC
- Maintenance window: Sunday 04:00-05:00 UTC

**Security**
- Encryption at rest: Enabled
- Encryption in transit: SSL/TLS enforced
- Network isolation: Private subnets only
- Access: Application security group only

### Database Credentials

**Storage**: AWS Secrets Manager
- Automatic rotation: Not configured
- Encryption: AWS KMS
- Access: IAM role-based

**Secret Structure**:
```json
{
  "username": "sqladmin",
  "password": "<generated>",
  "engine": "sqlserver",
  "host": "<rds-endpoint>",
  "port": 1433,
  "dbname": "LoanProcessing"
}
```

## Security Architecture

### Identity and Access Management

**EC2 Instance Role**
- Permissions:
  - Read Secrets Manager secrets
  - Read SSM parameters
  - Write CloudWatch Logs
  - Put CloudWatch metrics
  - Read S3 deployment artifacts
- Managed policies:
  - AmazonSSMManagedInstanceCore
  - CloudWatchAgentServerPolicy

**Principle of Least Privilege**
- Resources scoped to project/environment
- No wildcard permissions
- Time-limited credentials via IAM roles

### Encryption

**Data at Rest**
- RDS: AWS KMS encryption
- EBS volumes: AWS KMS encryption
- CloudWatch Logs: Encryption enabled
- Secrets Manager: AWS KMS encryption

**Data in Transit**
- ALB to EC2: HTTP (can upgrade to HTTPS)
- EC2 to RDS: SSL/TLS enforced
- API calls: HTTPS (AWS SDK)

### Access Control

**EC2 Access**
- Method: AWS Systems Manager Session Manager
- No SSH keys required
- Audit logging enabled
- MFA recommended for production

**Database Access**
- Method: SQL Server authentication
- Credentials: Secrets Manager
- Network: Security group restricted
- Audit: CloudWatch Logs

### Compliance Considerations

**FSI Best Practices**
- Network segmentation (public/private subnets)
- Encryption at rest and in transit
- Audit logging (CloudWatch, VPC Flow Logs)
- Least privilege access (IAM roles)
- Multi-AZ for high availability
- Automated backups

**Additional Recommendations for Production**
- Enable AWS Config for compliance monitoring
- Implement AWS GuardDuty for threat detection
- Use AWS WAF for application protection
- Enable AWS CloudTrail for API auditing
- Implement AWS Security Hub for centralized security

## Monitoring Architecture

### CloudWatch Logs

**Log Groups**
- `/aws/ec2/loanprocessing`: Application logs
  - IIS access logs
  - IIS error logs
  - Windows Event Logs (Application, System)
- `/aws/rds/instance/*/error`: RDS error logs
- `/aws/vpc/loanprocessing-workshop`: VPC Flow Logs

**Retention**: 7 days (configurable)

### CloudWatch Metrics

**EC2 Metrics**
- CPUUtilization
- NetworkIn/NetworkOut
- DiskReadOps/DiskWriteOps
- StatusCheckFailed

**ALB Metrics**
- TargetResponseTime
- RequestCount
- HTTPCode_Target_2XX_Count
- HTTPCode_Target_5XX_Count
- HealthyHostCount
- UnHealthyHostCount

**RDS Metrics**
- CPUUtilization
- DatabaseConnections
- FreeStorageSpace
- ReadLatency/WriteLatency
- ReadThroughput/WriteThroughput

**Custom Metrics** (via CloudWatch Agent)
- Memory utilization
- Disk space utilization
- IIS request metrics

### CloudWatch Alarms

**Critical Alarms**
- ALB unhealthy hosts > 0
- RDS CPU > 80%
- RDS free storage < 2 GB
- ALB 5XX errors > 10 in 5 minutes

**Warning Alarms**
- EC2 CPU > 80%
- ALB response time > 5 seconds
- RDS connections > 80

**Notification**: SNS topic (email subscription)

### CloudWatch Dashboard

**Widgets**
- ALB performance (response time, request count)
- Target health (healthy/unhealthy hosts)
- EC2 CPU utilization
- RDS metrics (CPU, connections, storage)
- Recent application logs

## Deployment Architecture

### Infrastructure as Code

**Terraform Structure**
```
terraform/
├── main.tf              # Root module
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── backend.tf           # State management
└── modules/
    ├── networking/      # VPC, subnets, routing
    ├── security/        # Security groups, IAM
    ├── compute/         # EC2, ASG, ALB
    ├── database/        # RDS, Secrets Manager
    └── monitoring/      # CloudWatch, SNS
```

**State Management**
- Backend: S3 (optional)
- State locking: DynamoDB (optional)
- Encryption: Enabled

### Application Deployment

**Build Process**
1. Restore NuGet packages
2. Build solution (Release configuration)
3. Publish web application
4. Package database scripts

**Deployment Process**
1. Upload artifacts to S3
2. Connect to EC2 via Session Manager
3. Download artifacts from S3
4. Configure IIS
5. Update Web.config with database connection
6. Initialize database schema
7. Load sample data

**Automation Opportunities**
- AWS CodePipeline for CI/CD
- AWS CodeBuild for compilation
- AWS CodeDeploy for deployment
- AWS Systems Manager Run Command for configuration

## Scalability Considerations

### Current Limitations

**Workshop Scale**
- Single EC2 instance (can scale to 2)
- Small RDS instance (db.t3.small)
- Limited concurrent users (~50-100)
- No caching layer

### Scaling Strategies

**Vertical Scaling**
- Increase EC2 instance type (t3.large, t3.xlarge)
- Increase RDS instance class (db.t3.medium, db.t3.large)
- Quick but limited scalability

**Horizontal Scaling**
- Increase ASG max size (4, 8, 16 instances)
- Add read replicas for RDS
- Implement session state management (Redis, DynamoDB)

**Performance Optimization**
- Add CloudFront CDN for static assets
- Implement ElastiCache for application caching
- Use RDS Proxy for connection pooling
- Enable ALB request compression

## Cost Optimization

### Current Monthly Costs

| Service | Configuration | Cost |
|---------|--------------|------|
| EC2 (t3.medium) | 1 instance, 730 hours | $60 |
| RDS (db.t3.small) | Multi-AZ, 730 hours | $80 |
| ALB | 1 ALB, minimal traffic | $20 |
| Data Transfer | <1 GB/month | $5 |
| CloudWatch | Basic monitoring | $5 |
| **Total** | | **$170** |

### Cost Reduction Strategies

**For Workshop/Lab**
1. **Instance Scheduler**: Stop instances during non-use hours
   - Savings: 50-70% (~$85-120/month)
   - Implementation: AWS Instance Scheduler solution

2. **Single-AZ RDS**: Disable Multi-AZ for non-production
   - Savings: ~$40/month
   - Trade-off: No automatic failover

3. **Smaller Instances**: Use t3.small for EC2
   - Savings: ~$30/month
   - Trade-off: Lower performance

4. **Spot Instances**: Use for non-critical workloads
   - Savings: 70-90%
   - Trade-off: Can be interrupted

**For Production**
1. **Reserved Instances**: 1-year or 3-year commitment
   - Savings: 40-60%
   - Best for predictable workloads

2. **Savings Plans**: Flexible commitment
   - Savings: 30-50%
   - Applies across services

3. **Right-Sizing**: Monitor and adjust instance sizes
   - Use AWS Compute Optimizer recommendations

## Disaster Recovery

### Backup Strategy

**RDS Automated Backups**
- Frequency: Daily
- Retention: 7 days
- Point-in-time recovery: Enabled
- Cross-region backup: Not configured

**Manual Snapshots**
- Before major changes
- Before modernization steps
- Long-term retention

**Application Backups**
- Source code: Git repository
- Configuration: Terraform state
- Deployment artifacts: S3

### Recovery Procedures

**RDS Failure**
1. Multi-AZ automatic failover (1-2 minutes)
2. Or restore from snapshot (15-30 minutes)

**EC2 Failure**
1. Auto Scaling replaces unhealthy instance (5-10 minutes)
2. ALB routes traffic to healthy instances

**Region Failure**
1. Deploy to new region using Terraform
2. Restore RDS from cross-region snapshot
3. Update DNS to new ALB

**Recovery Time Objective (RTO)**: 30 minutes
**Recovery Point Objective (RPO)**: 5 minutes (automated backups)

## Modernization Path

### Phase 1: Optimize Current Architecture
- Implement caching (ElastiCache)
- Add CloudFront CDN
- Enable RDS Performance Insights
- Implement application performance monitoring

### Phase 2: Containerization
- Create Docker container
- Deploy to ECS Fargate
- Use Aurora Serverless for database
- Implement service mesh (App Mesh)

### Phase 3: Serverless
- Migrate to Lambda + API Gateway
- Use DynamoDB for session state
- Implement Step Functions for workflows
- Use EventBridge for event-driven architecture

### Phase 4: Cloud-Native
- Microservices architecture
- Kubernetes (EKS)
- Service discovery (Cloud Map)
- Observability (X-Ray, CloudWatch Insights)

## References

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Windows Workloads](https://aws.amazon.com/windows/)
- [RDS SQL Server Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_SQLServer.html)
- [Application Load Balancer Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [EC2 Auto Scaling Guide](https://docs.aws.amazon.com/autoscaling/ec2/userguide/)

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Architecture Version**: Lift-and-Shift v1

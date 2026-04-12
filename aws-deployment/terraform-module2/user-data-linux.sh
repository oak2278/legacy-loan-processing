#!/bin/bash
# EC2 User Data Script — .NET 10 on Amazon Linux 2023
# This script runs on first boot to configure the instance for the
# LoanProcessing .NET 10 application with Kestrel on port 5000.
set -euo pipefail

LOG_FILE="/var/log/user-data-execution.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Starting User Data Execution — $(date) ==="

# -----------------------------------------------------------------------
# 1. Install .NET 10 Runtime
# -----------------------------------------------------------------------
echo "Cleaning dnf cache..."
dnf clean all
rm -rf /var/cache/dnf/*

# Wait for SSM agent auto-update to finish — it races with cloud-init for the dnf lock
# See: https://github.com/amazonlinux/amazon-linux-2023/issues/397
echo "Waiting for any background dnf operations to complete..."
sleep 30

echo "Installing .NET 10 runtime..."
# .NET 10 is available in the Amazon Linux 2023 native repository
dnf install -y aspnetcore-runtime-10.0

# Verify installation
dotnet --list-runtimes
echo ".NET 10 runtime installed successfully."

# -----------------------------------------------------------------------
# 2. Create systemd Unit File for Kestrel (port 5000)
# -----------------------------------------------------------------------
echo "Creating systemd unit file for loan-processing service..."
cat > /etc/systemd/system/loan-processing.service <<'UNIT'
[Unit]
Description=LoanProcessing .NET 10 Application
After=network.target

[Service]
WorkingDirectory=/opt/loan-processing
ExecStart=/usr/bin/dotnet /opt/loan-processing/LoanProcessing.Web.dll --urls http://0.0.0.0:5000
Restart=always
RestartSec=10
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_RUNNING_IN_CONTAINER=false

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable loan-processing
echo "systemd unit file created and enabled."

# -----------------------------------------------------------------------
# 3. Create Application Directory
# -----------------------------------------------------------------------
echo "Creating application directory..."
mkdir -p /opt/loan-processing

# -----------------------------------------------------------------------
# 4. Install CodeDeploy Agent
# -----------------------------------------------------------------------
echo "Installing CodeDeploy agent..."
dnf install -y ruby wget

wget "https://aws-codedeploy-${aws_region}.s3.${aws_region}.amazonaws.com/latest/install" -O /tmp/codedeploy-install
chmod +x /tmp/codedeploy-install
/tmp/codedeploy-install auto

# Wait for CodeDeploy agent to start
echo "Waiting for CodeDeploy agent..."
MAX_ATTEMPTS=30
AGENT_RUNNING=false
for i in $(seq 1 $MAX_ATTEMPTS); do
    if systemctl is-active --quiet codedeploy-agent; then
        echo "CodeDeploy agent running on attempt $i"
        AGENT_RUNNING=true
        break
    fi
    sleep 5
done

if [ "$AGENT_RUNNING" = false ]; then
    echo "WARNING: CodeDeploy agent not running after $MAX_ATTEMPTS attempts"
fi

# -----------------------------------------------------------------------
# 5. Configure Environment Metadata
# -----------------------------------------------------------------------
echo "Writing environment metadata..."
cat > /opt/loan-processing/environment.conf <<EOF
DB_ENDPOINT=${db_endpoint}
DB_NAME=${db_name}
DB_SECRET_ARN=${db_secret_arn}
PROJECT_NAME=${project_name}
ENVIRONMENT=${environment}
AWS_REGION=${aws_region}
EOF

# -----------------------------------------------------------------------
# 6. Firewall — Open Port 5000
# -----------------------------------------------------------------------
echo "Configuring firewall rules..."
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=5000/tcp || true
    firewall-cmd --reload || true
fi

echo "=== User Data Execution Completed — $(date) ==="

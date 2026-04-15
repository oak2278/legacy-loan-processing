#!/bin/bash
# CodeDeploy AfterInstall hook — configure appsettings.json with database connection string
set -euo pipefail

APP_DIR="/opt/loan-processing"
ENV_CONF="/etc/loan-processing/environment.conf"
APPSETTINGS="$APP_DIR/appsettings.json"

echo "=== Configuring application — $(date) ==="

# Read environment metadata written by user-data script
if [ -f "$ENV_CONF" ]; then
    # shellcheck source=/dev/null
    source "$ENV_CONF"
else
    echo "ERROR: $ENV_CONF not found. Ensure user-data script ran successfully."
    exit 1
fi

# Retrieve database credentials from AWS Secrets Manager
echo "Retrieving database credentials from Secrets Manager..."
SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "$DB_SECRET_ARN" \
    --region "$AWS_REGION" \
    --query SecretString \
    --output text)

DB_USERNAME=$(echo "$SECRET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['username'])")
DB_PASSWORD=$(echo "$SECRET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['password'])")

# Build connection string with TrustServerCertificate and Encrypt flags
CONNECTION_STRING="Server=${DB_ENDPOINT};Database=${DB_NAME};User Id=${DB_USERNAME};Password=${DB_PASSWORD};TrustServerCertificate=True;Encrypt=True;"

echo "Writing appsettings.json..."
cat > "$APPSETTINGS" <<EOF
{
  "ConnectionStrings": {
    "LoanProcessingConnection": "${CONNECTION_STRING}"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
EOF

# Set ownership and permissions
echo "Setting file ownership and permissions..."
chown -R root:root "$APP_DIR"
chmod -R 755 "$APP_DIR"
chmod 640 "$APPSETTINGS"

echo "=== Configuration complete — $(date) ==="

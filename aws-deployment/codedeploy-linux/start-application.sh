#!/bin/bash
# CodeDeploy ApplicationStart hook — start Kestrel service and verify health
set -euo pipefail

echo "=== Starting loan-processing service — $(date) ==="

# Reload systemd in case the unit file was updated
systemctl daemon-reload

# Start the service
systemctl start loan-processing

echo "Waiting for application to become healthy on port 5000..."

MAX_RETRIES=30
RETRY_INTERVAL=5
HEALTHY=false

for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf http://localhost:5000/ > /dev/null 2>&1; then
        echo "Application is healthy on attempt $i."
        HEALTHY=true
        break
    fi
    echo "Attempt $i/$MAX_RETRIES — waiting ${RETRY_INTERVAL}s..."
    sleep $RETRY_INTERVAL
done

if [ "$HEALTHY" = false ]; then
    echo "ERROR: Application did not become healthy after $MAX_RETRIES attempts."
    echo "Service status:"
    systemctl status loan-processing --no-pager || true
    echo "Recent logs:"
    journalctl -u loan-processing --no-pager -n 50 || true
    exit 1
fi

echo "=== ApplicationStart complete — $(date) ==="

#!/bin/bash
# CodeDeploy ValidateService hook — verify application health endpoint
set -euo pipefail

HEALTH_URL="http://localhost:5000/"
MAX_RETRIES="${VALIDATE_MAX_RETRIES:-10}"
RETRY_INTERVAL="${VALIDATE_RETRY_INTERVAL:-5}"
TIMEOUT="${VALIDATE_TIMEOUT:-5}"

echo "=== Validating deployment — $(date) ==="
echo "Health URL: $HEALTH_URL"
echo "Max retries: $MAX_RETRIES, Interval: ${RETRY_INTERVAL}s, Timeout: ${TIMEOUT}s"

HEALTHY=false

for i in $(seq 1 "$MAX_RETRIES"); do
    HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$HEALTH_URL" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        echo "Health check passed on attempt $i (HTTP $HTTP_CODE)."
        HEALTHY=true
        break
    fi

    echo "Attempt $i/$MAX_RETRIES — HTTP $HTTP_CODE, retrying in ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done

if [ "$HEALTHY" = false ]; then
    echo "ERROR: Health check failed after $MAX_RETRIES attempts."
    echo "Service status:"
    systemctl status loan-processing --no-pager || true
    echo "Recent logs:"
    journalctl -u loan-processing --no-pager -n 30 || true
    exit 1
fi

echo "=== Deployment validation passed — $(date) ==="

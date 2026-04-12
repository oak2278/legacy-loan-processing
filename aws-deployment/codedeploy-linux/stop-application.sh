#!/bin/bash
# CodeDeploy ApplicationStop hook — gracefully stop the Kestrel service
set -euo pipefail

echo "=== Stopping loan-processing service — $(date) ==="

if systemctl is-active --quiet loan-processing 2>/dev/null; then
    echo "Stopping loan-processing service..."
    systemctl stop loan-processing
    echo "Service stopped successfully."
elif systemctl list-unit-files | grep -q loan-processing; then
    echo "Service exists but is not running — nothing to stop."
else
    echo "Service does not exist yet — first deployment, skipping stop."
fi

echo "=== ApplicationStop complete — $(date) ==="

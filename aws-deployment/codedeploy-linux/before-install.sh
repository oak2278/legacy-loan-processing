#!/bin/bash
# CodeDeploy BeforeInstall hook — back up current application and clean old backups
set -euo pipefail

APP_DIR="/opt/loan-processing"
BACKUP_DIR="/opt/loan-processing.bak"

echo "=== BeforeInstall — $(date) ==="

# Back up current application if it exists
if [ -d "$APP_DIR" ]; then
    echo "Backing up $APP_DIR to $BACKUP_DIR..."
    rm -rf "$BACKUP_DIR"
    cp -a "$APP_DIR" "$BACKUP_DIR"
    echo "Backup complete."
else
    echo "No existing application directory — first deployment."
fi

# Clean the application directory for fresh deployment
if [ -d "$APP_DIR" ]; then
    echo "Cleaning application directory..."
    rm -rf "${APP_DIR:?}"/*
fi

# Ensure the application directory exists
mkdir -p "$APP_DIR"

echo "=== BeforeInstall complete — $(date) ==="

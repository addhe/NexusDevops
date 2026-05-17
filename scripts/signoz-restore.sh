#!/bin/bash
# SigNoz Restore Script
# Imports dashboards and alerts from JSON files to SigNoz database
# Usage: ./signoz-restore.sh [backup_dir]

set -e

# Configuration
SIGNOZ_CONTAINER="signoz"
DB_PATH="/var/lib/signoz/signoz.db"
BACKUP_DIR="${1:-./signoz-backup}"

echo "=== SigNoz Restore Script ==="
echo "Time: $(date)"
echo ""

# Check if backup exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "ERROR: Backup directory not found: $BACKUP_DIR"
    exit 1
fi

# Find latest backup
LATEST_DB=$(ls -t "$BACKUP_DIR"/signoz-backup-*.db 2>/dev/null | head -1)
if [ -z "$LATEST_DB" ]; then
    echo "ERROR: No backup database found in $BACKUP_DIR"
    exit 1
fi

echo "Using backup: $LATEST_DB"
echo ""

# Function to restore database
restore_database() {
    echo "[1/3] Stopping SigNoz..."
    sudo docker stop $SIGNOZ_CONTAINER

    echo "[2/3] Restoring database..."
    # Backup current database
    sudo docker cp $SIGNOZ_CONTAINER:$DB_PATH "$BACKUP_DIR/signoz.db.pre-restore" 2>/dev/null || true

    # Copy restored database
    sudo docker cp "$LATEST_DB" $SIGNOZ_CONTAINER:$DB_PATH

    echo "[3/3] Starting SigNoz..."
    sudo docker start $SIGNOZ_CONTAINER

    # Wait for SigNoz to be ready
    echo "Waiting for SigNoz to start..."
    sleep 10

    # Check health
    if curl -s http://localhost:3301/api/v1/version > /dev/null 2>&1; then
        echo "SigNoz is running!"
    else
        echo "WARNING: SigNoz might not be ready yet. Check with: sudo docker logs signoz"
    fi
}

# Function to import dashboards via API (if auth available)
import_dashboards_via_api() {
    echo "Attempting to import dashboards via API..."

    # Check for API token
    if [ -f "$BACKUP_DIR/api-token.txt" ]; then
        API_TOKEN=$(cat "$BACKUP_DIR/api-token.txt")

        # Import dashboards
        for dashboard in "$BACKUP_DIR"/dashboard-*.json; do
            if [ -f "$dashboard" ]; then
                echo "Importing: $dashboard"
                curl -s -X POST "http://localhost:3301/api/v1/dashboards" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d @"$dashboard" || echo "Failed to import $dashboard"
            fi
        done
    else
        echo "No API token found. Skipping API import."
    fi
}

# Main restore process
main() {
    echo "Starting restore..."

    restore_database
    # import_dashboards_via_api  # Uncomment if using API

    echo ""
    echo "=== Restore Complete ==="
    echo "Database restored from: $LATEST_DB"
    echo "SigNoz container: $SIGNOZ_CONTAINER"
    echo ""
    echo "IMPORTANT: Verify your dashboards and alerts in SigNoz UI."
}

main "$@"
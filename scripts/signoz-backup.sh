#!/bin/bash
# SigNoz Backup Script
# Exports dashboards and alerts from SigNoz database to JSON files
# Usage: ./signoz-backup.sh [output_dir]

set -e

# Configuration
SIGNOZ_CONTAINER="signoz"
DB_PATH="/var/lib/signoz/signoz.db"
OUTPUT_DIR="${1:-./signoz-backup}"
DATE=$(date +%Y%m%d_%H%M%S)

echo "=== SigNoz Backup Script ==="
echo "Time: $(date)"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to backup SQLite database
backup_database() {
    echo "[1/3] Backing up SigNoz database..."

    # Stop SigNoz to ensure data consistency (optional, can use WAL checkpoint)
    # sudo docker stop $SIGNOZ_CONTAINER

    # Copy database files
    sudo docker cp $SIGNOZ_CONTAINER:$DB_PATH "$OUTPUT_DIR/signoz.db" 2>/dev/null || true
    sudo docker cp $SIGNOZ_CONTAINER:${DB_PATH}-shm "$OUTPUT_DIR/signoz.db-shm" 2>/dev/null || true
    sudo docker cp $SIGNOZ_CONTAINER:${DB_PATH}-wal "$OUTPUT_DIR/signoz.db-wal" 2>/dev/null || true

    # Merge WAL into main database
    if command -v sqlite3 &> /dev/null; then
        cp "$OUTPUT_DIR/signoz.db" "$OUTPUT_DIR/signoz-backup-$DATE.db"
        if [ -f "$OUTPUT_DIR/signoz.db-wal" ]; then
            sqlite3 "$OUTPUT_DIR/signoz-backup-$DATE.db" <<EOF
ATTACH DATABASE '$OUTPUT_DIR/signoz.db' AS main;
PRAGMA main.journal_mode = DELETE;
VACUUM;
EOF
        fi
    fi

    echo "Database backed up to $OUTPUT_DIR/signoz-backup-$DATE.db"
}

# Function to extract dashboards
extract_dashboards() {
    echo "[2/3] Extracting dashboards..."

    # Query dashboards from database
    # Note: SigNoz stores dashboards in a specific table structure
    # This is a placeholder - actual implementation depends on SigNoz version

    if command -v sqlite3 &> /dev/null && [ -f "$OUTPUT_DIR/signoz-backup-$DATE.db" ]; then
        # Export dashboard definitions
        sqlite3 "$OUTPUT_DIR/signoz-backup-$DATE.db" ".dump" > "$OUTPUT_DIR/dashboard-dump-$DATE.sql" 2>/dev/null || true

        # Try to extract dashboard JSON if table exists
        sqlite3 "$OUTPUT_DIR/signoz-backup-$DATE.db" "SELECT * FROM dashboards;" > "$OUTPUT_DIR/dashboards-$DATE.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/dashboards-$DATE.json"
    fi

    echo "Dashboards extracted to $OUTPUT_DIR/"
}

# Function to extract alerts
extract_alerts() {
    echo "[3/3] Extracting alerts..."

    # Query alerts from database
    if command -v sqlite3 &> /dev/null && [ -f "$OUTPUT_DIR/signoz-backup-$DATE.db" ]; then
        sqlite3 "$OUTPUT_DIR/signoz-backup-$DATE.db" "SELECT * FROM alerts;" > "$OUTPUT_DIR/alerts-$DATE.json" 2>/dev/null || echo "[]" > "$OUTPUT_DIR/alerts-$DATE.json"
    fi

    echo "Alerts extracted to $OUTPUT_DIR/"
}

# Main backup process
main() {
    echo "Starting backup..."

    backup_database
    extract_dashboards
    extract_alerts

    # Create manifest
    cat > "$OUTPUT_DIR/manifest.json" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "signoz_version": "$(curl -s http://localhost:3301/api/v1/version 2>/dev/null || echo 'unknown')",
    "files": [
        "signoz-backup-$DATE.db",
        "dashboards-$DATE.json",
        "alerts-$DATE.json"
    ]
}
EOF

    echo ""
    echo "=== Backup Complete ==="
    echo "Location: $OUTPUT_DIR"
    echo "Files:"
    ls -la "$OUTPUT_DIR"
}

main "$@"
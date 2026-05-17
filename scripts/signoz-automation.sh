#!/bin/bash
# SigNoz Automation Script
# Populates dashboards and alerts from JSON definitions
# Usage: ./signoz-automation.sh [command] [options]
#
# Commands:
#   init        - Initialize SigNoz with default dashboards and alerts
#   backup      - Backup current SigNoz database
#   restore     - Restore from backup
#   status      - Check SigNoz status
#   help        - Show this help

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/signoz-backup"
DASHBOARDS_DIR="$BACKUP_DIR/dashboards"
ALERTS_DIR="$BACKUP_DIR/alerts"
SIGNOZ_CONTAINER="signoz"
DB_PATH="/var/lib/signoz/signoz.db"
SIGNOZ_URL="http://localhost:3301"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_header() {
    echo ""
    echo "========================================="
    echo "  SigNoz Automation Script"
    echo "========================================="
    echo ""
}

echo_success() { echo -e "${GREEN}✓ $1${NC}"; }
echo_error() { echo -e "${RED}✗ $1${NC}"; }
echo_info() { echo -e "${YELLOW}→ $1${NC}"; }

# Check if SigNoz is running
check_signoz_status() {
    echo_info "Checking SigNoz status..."

    if sudo docker ps | grep -q $SIGNOZ_CONTAINER; then
        echo_success "SigNoz container is running"

        # Check API
        if curl -s "$SIGNOZ_URL/api/v1/version" > /dev/null 2>&1; then
            VERSION=$(curl -s "$SIGNOZ_URL/api/v1/version" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
            echo_success "SigNoz API is responding (version: $VERSION)"
            return 0
        else
            echo_error "SigNoz API is not responding"
            return 1
        fi
    else
        echo_error "SigNoz container is not running"
        return 1
    fi
}

# Check metrics collection
check_metrics_collection() {
    echo_info "Checking metrics collection..."

    # Check otel-collector
    if sudo docker ps | grep -q otel-collector; then
        echo_success "OpenTelemetry Collector is running"
    else
        echo_error "OpenTelemetry Collector is not running"
        return 1
    fi

    # Check cAdvisor
    if sudo docker ps | grep -q cadvisor; then
        echo_success "cAdvisor is running"
    else
        echo_error "cAdvisor is not running"
        return 1
    fi

    # Check metrics in ClickHouse
    METRIC_COUNT=$(sudo docker exec signoz-clickhouse clickhouse-client -q "SELECT count(DISTINCT metric_name) FROM signoz_metrics.time_series_v4" 2>/dev/null || echo "0")
    echo_info "Metrics in ClickHouse: $METRIC_COUNT"

    if [ "$METRIC_COUNT" -gt 0 ]; then
        echo_success "Metrics are being collected"
    else
        echo_error "No metrics found in ClickHouse"
        return 1
    fi
}

# Initialize SigNoz with default configuration
init_signoz() {
    echo_header
    echo "Initializing SigNoz with default configuration..."
    echo ""

    # Check prerequisites
    check_signoz_status || exit 1
    check_metrics_collection || echo_warning "Metrics collection might not be complete"

    echo ""
    echo_info "Creating predefined dashboards..."

    # Note: Due to SigNoz architecture, dashboards must be created via UI
    # This script will prepare the configuration files

    mkdir -p "$DASHBOARDS_DIR"
    mkdir -p "$ALERTS_DIR"

    # Check if dashboards exist
    if [ -d "$DASHBOARDS_DIR" ] && [ "$(ls -A $DASHBOARDS_DIR/*.json 2>/dev/null)" ]; then
        echo_success "Dashboard definitions found in $DASHBOARDS_DIR"
        echo ""
        echo "To import dashboards:"
        echo "1. Open SigNoz UI: $SIGNOZ_URL"
        echo "2. Go to Dashboards → Import"
        echo "3. Upload JSON files from: $DASHBOARDS_DIR"
    else
        echo_info "No predefined dashboards found"
    fi

    echo ""
    echo_info "Predefined alerts configuration:"
    if [ -d "$ALERTS_DIR" ] && [ "$(ls -A $ALERTS_DIR/*.json 2>/dev/null)" ]; then
        echo_success "Alert definitions found in $ALERTS_DIR"
        echo ""
        echo "To configure alerts:"
        echo "1. Open SigNoz UI: $SIGNOZ_URL"
        echo "2. Go to Alerts → New Alert"
        echo "3. Create alerts from definitions in: $ALERTS_DIR"
    fi

    echo ""
    echo "=== Manual Steps Required ==="
    echo ""
    echo "SigNoz requires UI interaction for dashboard/alert creation."
    echo "The following files are ready for manual import:"
    echo ""
    echo "Dashboards:"
    ls -1 "$DASHBOARDS_DIR"/*.json 2>/dev/null || echo "  (none)"
    echo ""
    echo "Alerts:"
    ls -1 "$ALERTS_DIR"/*.json 2>/dev/null || echo "  (none)"
    echo ""
    echo "Alternative: Use SigNoz API with authentication token"
}

# Backup SigNoz database
backup_signoz() {
    echo_header
    echo "Backing up SigNoz..."
    echo ""

    DATE=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$BACKUP_DIR"

    echo_info "Stopping SigNoz for consistent backup..."
    sudo docker stop $SIGNOZ_CONTAINER 2>/dev/null || true

    echo_info "Copying database files..."
    sudo docker cp $SIGNOZ_CONTAINER:$DB_PATH "$BACKUP_DIR/signoz.db" 2>/dev/null || true
    sudo docker cp $SIGNOZ_CONTAINER:${DB_PATH}-shm "$BACKUP_DIR/signoz.db-shm" 2>/dev/null || true
    sudo docker cp $SIGNOZ_CONTAINER:${DB_PATH}-wal "$BACKUP_DIR/signoz.db-wal" 2>/dev/null || true

    echo_info "Starting SigNoz..."
    sudo docker start $SIGNOZ_CONTAINER

    # Create timestamped backup
    if [ -f "$BACKUP_DIR/signoz.db" ]; then
        cp "$BACKUP_DIR/signoz.db" "$BACKUP_DIR/signoz-backup-$DATE.db"
        echo_success "Database backed up to: $BACKUP_DIR/signoz-backup-$DATE.db"
    else
        echo_error "Backup failed - database file not found"
        return 1
    fi

    # Save manifest
    cat > "$BACKUP_DIR/manifest.json" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "signoz_version": "$(curl -s $SIGNOZ_URL/api/v1/version 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4 || echo 'unknown')",
    "backup_file": "signoz-backup-$DATE.db"
}
EOF

    echo_success "Backup complete!"
    echo ""
    echo "Files saved to: $BACKUP_DIR"
}

# Restore SigNoz from backup
restore_signoz() {
    echo_header
    echo "Restoring SigNoz from backup..."
    echo ""

    # Find latest backup
    LATEST_DB=$(ls -t "$BACKUP_DIR"/signoz-backup-*.db 2>/dev/null | head -1)

    if [ -z "$LATEST_DB" ]; then
        echo_error "No backup found in $BACKUP_DIR"
        exit 1
    fi

    echo_info "Using backup: $LATEST_DB"

    echo_info "Stopping SigNoz..."
    sudo docker stop $SIGNOZ_CONTAINER

    echo_info "Restoring database..."
    sudo docker cp "$LATEST_DB" $SIGNOZ_CONTAINER:$DB_PATH

    echo_info "Starting SigNoz..."
    sudo docker start $SIGNOZ_CONTAINER

    echo_info "Waiting for SigNoz to start..."
    sleep 10

    if check_signoz_status > /dev/null 2>&1; then
        echo_success "SigNoz restored successfully!"
    else
        echo_error "SigNoz failed to start after restore"
        return 1
    fi
}

# Show status
show_status() {
    echo_header
    echo "SigNoz Status"
    echo ""

    check_signoz_status
    echo ""

    # Container stats
    echo "Container Status:"
    sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "NAME|signoz|otel|cadvisor" || echo "  No containers running"
    echo ""

    # Metrics count
    echo "Metrics in ClickHouse:"
    sudo docker exec signoz-clickhouse clickhouse-client -q "SELECT count(DISTINCT metric_name) as metric_count FROM signoz_metrics.time_series_v4" 2>/dev/null || echo "  Unable to query"
    echo ""

    # Recent metrics
    echo "Recent metrics collected:"
    sudo docker exec signoz-clickhouse clickhouse-client -q "SELECT DISTINCT metric_name FROM signoz_metrics.time_series_v4 LIMIT 10" 2>/dev/null || echo "  Unable to query"
}

# Show help
show_help() {
    echo_header
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  init        Initialize SigNoz with default dashboards and alerts"
    echo "  backup      Backup current SigNoz database"
    echo "  restore     Restore from latest backup"
    echo "  status      Show SigNoz status and metrics"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 init               # Initialize with defaults"
    echo "  $0 backup             # Create backup"
    echo "  $0 restore            # Restore from backup"
    echo "  $0 status             # Show status"
    echo ""
    echo "Configuration:"
    echo "  Backup directory: $BACKUP_DIR"
    echo "  Dashboards: $DASHBOARDS_DIR"
    echo "  Alerts: $ALERTS_DIR"
}

# Main entry point
case "${1:-help}" in
    init)
        init_signoz
        ;;
    backup)
        backup_signoz
        ;;
    restore)
        restore_signoz
        ;;
    status)
        show_status
        ;;
    help|*)
        show_help
        ;;
esac
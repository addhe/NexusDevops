#!/bin/bash
# ============================================
# RandomOpsBot Quick Deploy Script
# ============================================
# Deploy bot dari snapshot dengan satu command
#
# Usage:
#   ./deploy-randomopsbot.sh <worker_id> [role] [--token "YOUR_TOKEN"]
#
# Examples:
#   ./deploy-randomopsbot.sh 001 devops
#   ./deploy-randomopsbot.sh 002 backend --token "YOUR_BOT_TOKEN"
#
# NOTE: Bot tokens should be in vault.yml, use --token only for new workers
#
# Owner: Om Awan (@BroAwn) - Telegram ID: 319535690
# ============================================

set -e

# Configuration
PROJECT_ID="awanmasterpiece"
ZONE="asia-southeast2-a"
NETWORK="openclaw-staging-network"
SUBNET="openclaw-staging-subnet"
SERVICE_ACCOUNT="awan-master-service-account@awanmasterpiece.iam.gserviceaccount.com"
BASE_SNAPSHOT_DEVOPS="openclaw-worker-devops-base-stg-v6"
BASE_SNAPSHOT_BACKEND="openclaw-worker-backend-base-stg-v6"

# Default values
WORKER_ID="${1:-001}"
ROLE="${2:-devops}"
NEW_TOKEN=""

# Parse arguments
shift 2 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case $1 in
        --token|-t)
            NEW_TOKEN="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate inputs
if [[ ! "$WORKER_ID" =~ ^[0-9]{3}$ ]]; then
    log_error "Invalid worker ID: $WORKER_ID. Must be 3 digits (e.g., 001, 002)"
    exit 1
fi

if [[ ! "$ROLE" =~ ^(devops|backend|frontend|test-engineer|infosec|pm|tpm|mobile-engineer)$ ]]; then
    log_error "Invalid role: $ROLE. Must be one of: devops, backend, frontend, test-engineer, infosec, pm, tpm, mobile-engineer"
    exit 1
fi

# Determine snapshot
SNAPSHOT=""
case $ROLE in
    devops|test-engineer|infosec|pm|tpm)
        SNAPSHOT="$BASE_SNAPSHOT_DEVOPS"
        ;;
    backend|frontend|mobile-engineer)
        SNAPSHOT="$BASE_SNAPSHOT_BACKEND"
        ;;
esac

INSTANCE_NAME="ocl-worker-${ROLE}-${WORKER_ID}-stg"

log_info "Configuration:"
echo "  Worker ID: $WORKER_ID"
echo "  Role: $ROLE"
echo "  Instance Name: $INSTANCE_NAME"
echo "  Snapshot: $SNAPSHOT"
echo "  Zone: $ZONE"

# Check if instance already exists
if gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" &>/dev/null; then
    log_error "Instance $INSTANCE_NAME already exists!"
    echo "Use a different worker ID or delete the existing instance first:"
    echo "  gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE"
    exit 1
fi

# Create instance
log_info "Creating instance from snapshot..."
gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type=e2-medium \
    --provisioning-model=SPOT \
    --source-snapshot="$SNAPSHOT" \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-ssd \
    --network-interface="network=$NETWORK,subnet=$SUBNET" \
    --tags="staging,openclaw,$ROLE" \
    --labels="environment=staging,role=$ROLE,id=$WORKER_ID,managed_by=script" \
    --service-account="$SERVICE_ACCOUNT" \
    --scopes="https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only"

# Wait for instance
log_info "Waiting for instance to be ready..."
sleep 30

# Get instance IP
VM_IP=$(gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')
log_info "Instance IP: $VM_IP"

# Update bot token if provided
if [[ -n "$NEW_TOKEN" ]]; then
    log_warn "Updating bot token..."
    log_warn "SECURITY: Token will be visible in shell history. Consider using vault.yml instead."
    gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --command="
        sudo sed -i 's/PLACEHOLDER_TOKEN/$NEW_TOKEN/g' /home/openclaw/.openclaw/openclaw.json
        sudo systemctl restart openclaw
    "
else
    log_info "Using default token from snapshot. Update manually if needed:"
    echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
    echo "  sudo nano /home/openclaw/.openclaw/openclaw.json"
    echo "  sudo systemctl restart openclaw"
fi

# Done
echo ""
log_info "=== Deployment Complete! ==="
echo ""
echo "Instance: $INSTANCE_NAME"
echo "IP: $VM_IP"
echo "Zone: $ZONE"
echo "Role: $ROLE"
echo ""
echo "To SSH:"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo ""
echo "To check status:"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command='sudo systemctl status openclaw'"
echo ""
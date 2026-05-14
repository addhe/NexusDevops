#!/bin/bash
# =============================================================================
# IrishEcho MasterControl - Quick Deploy Script
# =============================================================================
# This script deploys MasterControl bot from scratch
# Usage: ./create-mastercontrol-vm.sh

set -e

# Configuration
PROJECT="awanmasterpiece"
ZONE="asia-southeast2-b"
MACHINE_TYPE="n2d-standard-2"
DISK_SIZE="20"
INSTANCE_NAME="mastercontrol-001-stg"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== IrishEcho MasterControl Deployment ===${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check gcloud
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI not installed${NC}"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check ansible
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}Error: ansible not installed${NC}"
    echo "Install with: pip install ansible"
    exit 1
fi

# Check if vault file exists
VAULT_FILE="inventory/mastercontrol/group_vars/vault.yml"
if [ ! -f "$VAULT_FILE" ]; then
    echo -e "${YELLOW}Creating vault file template...${NC}"
    cat > "$VAULT_FILE" << 'EOF'
---
# MasterControl Secrets - ENCRYPT WITH ANSIBLE-VAULT
# Run: ansible-vault encrypt inventory/mastercontrol/group_vars/vault.yml

vault_mastercontrol_bot_token: "YOUR_BOT_TOKEN_HERE"
vault_mastercontrol_gateway_token: "GENERATE_WITH_openssl_rand_hex_24"
vault_sensitive_password: "CHANGE_ME_TO_SECURE_PASSWORD"
vault_ollama_api_key: "YOUR_OLLAMA_API_KEY"
EOF
    echo -e "${YELLOW}Please edit $VAULT_FILE with your secrets:${NC}"
    echo "  1. ansible-vault decrypt $VAULT_FILE"
    echo "  2. Edit the file"
    echo "  3. ansible-vault encrypt $VAULT_FILE"
    exit 1
fi

echo -e "${GREEN}Prerequisites OK${NC}"
echo ""

# Ask for confirmation
echo -e "${YELLOW}Configuration:${NC}"
echo "  Project: $PROJECT"
echo "  Zone: $ZONE"
echo "  Machine Type: $MACHINE_TYPE"
echo "  Disk Size: ${DISK_SIZE}GB"
echo "  Instance Name: $INSTANCE_NAME"
echo ""
echo -e "${RED}IMPORTANT: This bot is RESTRICTED to:${NC}"
echo "  • DM ONLY - No group access"
echo "  • OWNER ONLY - Om Awan (@BroAwn, ID: 319535690)"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Check if bot token is set
if grep -q "YOUR_BOT_TOKEN_HERE" "$VAULT_FILE" 2>/dev/null; then
    echo -e "${RED}Error: Bot token not configured in vault${NC}"
    echo "Please edit $VAULT_FILE with your bot token from @BotFather"
    exit 1
fi

# Create VM
echo -e "${GREEN}Creating VM...${NC}"
gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --provisioning-model=SPOT \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size="${DISK_SIZE}GB" \
    --boot-disk-type=pd-ssd \
    --network-interface=network=openclaw-staging-network,subnet=openclaw-staging-subnet \
    --tags=mastercontrol,staging,restricted,dm-only \
    --labels=environment=staging,role=mastercontrol,id=001,managed_by=manual \
    --service-account="awan-master-service-account@$PROJECT.iam.gserviceaccount.com" \
    --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only

# Wait for VM to be ready
echo -e "${GREEN}Waiting for VM to be ready...${NC}"
sleep 30

# Get VM IP
VM_IP=$(gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')
echo -e "${GREEN}VM IP: $VM_IP${NC}"

# Install dependencies
echo -e "${GREEN}Installing dependencies...${NC}"
gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --command="
    sudo apt-get update
    sudo apt-get install -y curl wget git
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
    sudo npm install -g openclaw
    sudo useradd -m -s /bin/bash mastercontrol || true
"

# Deploy configuration
echo -e "${GREEN}Deploying MasterControl configuration...${NC}"
ANSIBLE_HOST="$VM_IP" ansible-playbook \
    playbooks/mastercontrol/deploy.yml \
    -i inventory/mastercontrol/hosts.yml \
    --ask-vault-pass

# Done
echo ""
echo -e "${GREEN}=== MasterControl Deployed! ===${NC}"
echo ""
echo -e "${YELLOW}VM Info:${NC}"
echo "  Name: $INSTANCE_NAME"
echo "  IP: $VM_IP"
echo "  Zone: $ZONE"
echo ""
echo -e "${YELLOW}Bot Info:${NC}"
echo "  Bot: @IrishEcho_MasterControl_Bot"
echo "  Access: DM ONLY, OWNER ONLY"
echo "  Owner: Om Awan (@BroAwn, ID: 319535690)"
echo ""
echo -e "${GREEN}Test:${NC}"
echo "  1. Open Telegram"
echo "  2. DM @IrishEcho_MasterControl_Bot"
echo "  3. Send: hello"
echo "  4. Bot should respond (ONLY to @BroAwn)"
echo ""
echo -e "${YELLOW}To SSH:${NC}"
echo "  gcloud compute ssh $INSTANCE_NAME --zone=$ZONE"
echo ""
#!/bin/bash
# =============================================================================
# MasterControl E2E Deploy Test
# =============================================================================
# Destroys existing VM and deploys from scratch
# Usage: ./scripts/e2e-deploy-test.sh

set -e

# Configuration
PROJECT="awanmasterpiece"
ZONE="asia-southeast2-b"
MACHINE_TYPE="n2d-standard-2"
DISK_SIZE="20"
INSTANCE_NAME="mastercontrol-001-stg"
SSH_KEY="$HOME/.ssh/mastercontrol-gcp"
ANSIBLE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

timer_start() { date +%s; }
timer_elapsed() { echo $(( $(date +%s) - $1 )); }
format_time() {
  local s=$1
  printf "%dm%02ds" $((s/60)) $((s%60))
}

TOTAL_START=$(timer_start)
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  MasterControl E2E Deploy Test${NC}"
echo -e "${CYAN}  $(date '+%Y-%m-%d %H:%M:%S %Z')${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# ──────────────────────────────────────
# Step 1: Destroy existing VM
# ──────────────────────────────────────
echo -e "${YELLOW}[1/6] Destroying existing VM...${NC}"
STEP_START=$(timer_start)
if gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --project=$PROJECT &>/dev/null; then
  gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --quiet 2>&1
  echo -e "${GREEN}  ✓ VM destroyed ($(format_time $(timer_elapsed $STEP_START)))${NC}"
else
  echo -e "${GREEN}  ✓ No existing VM found ($(format_time $(timer_elapsed $STEP_START)))${NC}"
fi
DESTROY_TIME=$(timer_elapsed $STEP_START)

# ──────────────────────────────────────
# Step 2: Create new VM
# ──────────────────────────────────────
echo -e "${YELLOW}[2/6] Creating VM ($MACHINE_TYPE) with SSH key...${NC}"
STEP_START=$(timer_start)

# Prepare SSH metadata (inject key at boot)
PUBKEY=$(cat ${SSH_KEY}.pub)
SSH_METADATA="addheputra:${PUBKEY}"

gcloud compute instances create $INSTANCE_NAME \
  --project=$PROJECT \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --provisioning-model=SPOT \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=${DISK_SIZE}GB \
  --boot-disk-type=pd-ssd \
  --network-interface=network=openclaw-staging-network,subnet=openclaw-staging-subnet \
  --tags=mastercontrol,staging,restricted,dm-only \
  --labels=environment=staging,role=mastercontrol,id=001,managed_by=ansible \
  --service-account=awan-master-service-account@$PROJECT.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only \
  --metadata=ssh-keys="$SSH_METADATA" \
  --metadata-from-file=startup-script=<(cat <<'STARTUP'
#!/bin/bash
# Ensure addheputra has sudo NOPASSWD
if ! grep -q addheputra /etc/sudoers.d/addheputra 2>/dev/null; then
  useradd -m -s /bin/bash -G sudo addheputra 2>/dev/null || true
  echo 'addheputra ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/addheputra
  chmod 440 /etc/sudoers.d/addheputra
fi
STARTUP
) \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>&1 | tail -1
CREATE_TIME=$(timer_elapsed $STEP_START)
echo -e "${GREEN}  ✓ VM created with SSH key ($(format_time $CREATE_TIME))${NC}"

# ──────────────────────────────────────
# Step 3: Wait for SSH to be ready
# ──────────────────────────────────────
echo -e "${YELLOW}[3/6] Waiting for SSH to be ready...${NC}"
STEP_START=$(timer_start)

VM_IP=$(gcloud compute instances describe $INSTANCE_NAME \
  --zone=$ZONE --project=$PROJECT \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

for i in $(seq 1 15); do
  if ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=5 addheputra@${VM_IP} "echo 'SSH OK'" 2>/dev/null; then
    break
  fi
  echo "  Waiting for SSH... (attempt $i/15)"
  sleep 5
done
SSH_SETUP_TIME=$(timer_elapsed $STEP_START)
echo -e "${GREEN}  ✓ SSH ready ($(format_time $SSH_SETUP_TIME))${NC}"

# ──────────────────────────────────────
# Step 4: Run Ansible deploy
# ──────────────────────────────────────
echo -e "${YELLOW}[4/6] Running Ansible deploy...${NC}"
STEP_START=$(timer_start)
cd "$ANSIBLE_DIR"
ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_password \
  ansible-playbook playbooks/mastercontrol/deploy.yml \
  -i inventory/mastercontrol/ \
  2>&1 | tail -25
ANSIBLE_TIME=$(timer_elapsed $STEP_START)
echo -e "${GREEN}  ✓ Ansible deploy complete ($(format_time $ANSIBLE_TIME))${NC}"

# ──────────────────────────────────────
# Step 5: Verify gateway
# ──────────────────────────────────────
echo -e "${YELLOW}[5/6] Verifying gateway...${NC}"
STEP_START=$(timer_start)

# Wait for port
for i in $(seq 1 12); do
  if ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no addheputra@${VM_IP} "ss -tlnp | grep 8180" 2>/dev/null; then
    echo -e "${GREEN}  ✓ Gateway port 8180 listening!${NC}"
    break
  fi
  echo "  Waiting for gateway... (attempt $i/12)"
  sleep 10
done
VERIFY_TIME=$(timer_elapsed $STEP_START)

# ──────────────────────────────────────
# Step 6: Verify Telegram bot
# ──────────────────────────────────────
echo -e "${YELLOW}[6/6] Checking Telegram bot...${NC}"
STEP_START=$(timer_start)
ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no addheputra@${VM_IP} "
sudo journalctl -u openclaw --since '2 min ago' --no-pager 2>&1 | grep -i telegram | tail -3
sudo systemctl status openclaw --no-pager 2>&1 | head -8
" 2>&1
BOT_CHECK_TIME=$(timer_elapsed $STEP_START)

# ──────────────────────────────────────
# Summary
# ──────────────────────────────────────
TOTAL_TIME=$(timer_elapsed $TOTAL_START)

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  E2E Deploy Results${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "  Destroy old VM:    $(format_time $DESTROY_TIME)"
echo -e "  Create new VM:     $(format_time $CREATE_TIME)"
echo -e "  SSH user setup:    $(format_time $SSH_SETUP_TIME)"
echo -e "  Ansible deploy:    $(format_time $ANSIBLE_TIME)"
echo -e "  Gateway verify:    $(format_time $VERIFY_TIME)"
echo -e "  Bot check:         $(format_time $BOT_CHECK_TIME)"
echo -e "  ─────────────────────────────"
echo -e "${GREEN}  TOTAL:             $(format_time $TOTAL_TIME)${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

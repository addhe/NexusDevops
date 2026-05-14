#!/bin/bash
# =============================================================================
# RandomOps Bot - Deploy Script
# =============================================================================
# Deploys a RandomOps bot worker from scratch
# Usage: ./scripts/deploy-randomops.sh [role] [id] [env]
# Example: ./scripts/deploy-randomops.sh devops 001 stg

set -e

# Parameters
ROLE="${1:-devops}"
WORKER_ID="${2:-001}"
ENV="${3:-stg}"
INSTANCE_NAME="ocl-worker-${ROLE}-${WORKER_ID}-${ENV}"

# Configuration
PROJECT="awanmasterpiece"
ZONE="asia-southeast2-b"
MACHINE_TYPE="n2d-standard-2"
DISK_SIZE="20"
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
echo -e "${CYAN}  RandomOps Bot Deploy${NC}"
echo -e "${CYAN}  Instance: ${INSTANCE_NAME}${NC}"
echo -e "${CYAN}  $(date '+%Y-%m-%d %H:%M:%S %Z')${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo ""

# Pull latest changes
echo -e "${YELLOW}[0/5] Pulling latest repo...${NC}"
cd "$ANSIBLE_DIR" && git pull --quiet 2>&1 || echo "  (git pull skipped)"

# ──────────────────────────────────────
# Step 1: Destroy existing VM (if any)
# ──────────────────────────────────────
echo -e "${YELLOW}[1/5] Checking existing VM...${NC}"
STEP_START=$(timer_start)
if gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --project=$PROJECT &>/dev/null; then
  echo "  Destroying existing instance..."
  gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --project=$PROJECT --quiet 2>&1
  echo -e "${GREEN}  ✓ Old VM destroyed ($(format_time $(timer_elapsed $STEP_START)))${NC}"
else
  echo -e "${GREEN}  ✓ No existing VM ($(format_time $(timer_elapsed $STEP_START)))${NC}"
fi
DESTROY_TIME=$(timer_elapsed $STEP_START)

# ──────────────────────────────────────
# Step 2: Create new VM
# ──────────────────────────────────────
echo -e "${YELLOW}[2/5] Creating VM ($MACHINE_TYPE)...${NC}"
STEP_START=$(timer_start)

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
  --tags=randomops,staging,openclaw \
  --labels=environment=${ENV},role=${ROLE},id=${WORKER_ID},application=randomops,managed_by=ansible \
  --service-account=awan-master-service-account@$PROJECT.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only \
  --metadata=ssh-keys="$SSH_METADATA" \
  --metadata-from-file=startup-script=<(cat <<'STARTUP'
#!/bin/bash
if ! grep -q addheputra /etc/sudoers.d/addheputra 2>/dev/null; then
  useradd -m -s /bin/bash -G sudo addheputra 2>/dev/null || true
  echo 'addheputra ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/addheputra
  chmod 440 /etc/sudoers.d/addheputra
fi
STARTUP
) \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>&1 | tail -1
CREATE_TIME=$(timer_elapsed $STEP_START)
echo -e "${GREEN}  ✓ VM created ($(format_time $CREATE_TIME))${NC}"

# ──────────────────────────────────────
# Step 3: Wait for SSH
# ──────────────────────────────────────
echo -e "${YELLOW}[3/5] Waiting for SSH...${NC}"
STEP_START=$(timer_start)

VM_IP=$(gcloud compute instances describe $INSTANCE_NAME \
  --zone=$ZONE --project=$PROJECT \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

ssh-keygen -R ${VM_IP} 2>/dev/null || true

for i in $(seq 1 15); do
  if ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no -o ConnectTimeout=5 addheputra@${VM_IP} "echo 'SSH OK'" 2>/dev/null; then
    break
  fi
  echo "  Waiting... (attempt $i/15)"
  sleep 5
done
SSH_TIME=$(timer_elapsed $STEP_START)
echo -e "${GREEN}  ✓ SSH ready ($(format_time $SSH_TIME))${NC}"

# ──────────────────────────────────────
# Step 4: Run Ansible deploy
# ──────────────────────────────────────
echo -e "${YELLOW}[4/5] Running Ansible deploy...${NC}"
STEP_START=$(timer_start)
cd "$ANSIBLE_DIR"
ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_password \
  ansible-playbook playbooks/randomops/deploy.yml \
  -i inventory/randomops/ \
  -e "gcp_worker_role=${ROLE} gcp_worker_id=${WORKER_ID}" \
  2>&1 | tail -30
ANSIBLE_TIME=$(timer_elapsed $STEP_START)
echo -e "${GREEN}  ✓ Ansible deploy complete ($(format_time $ANSIBLE_TIME))${NC}"

# ──────────────────────────────────────
# Step 5: Verify
# ──────────────────────────────────────
echo -e "${YELLOW}[5/5] Verifying...${NC}"
STEP_START=$(timer_start)

for i in $(seq 1 12); do
  if ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no addheputra@${VM_IP} "ss -tlnp | grep 8080" 2>/dev/null; then
    echo -e "${GREEN}  ✓ Gateway port 8080 listening!${NC}"
    break
  fi
  echo "  Waiting for gateway... (attempt $i/12)"
  sleep 10
done

ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no addheputra@${VM_IP} "
sudo systemctl status openclaw --no-pager 2>&1 | head -8
" 2>&1
VERIFY_TIME=$(timer_elapsed $STEP_START)

# ──────────────────────────────────────
# Summary
# ──────────────────────────────────────
TOTAL_TIME=$(timer_elapsed $TOTAL_START)

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}  RandomOps Deploy Results${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "  Instance:       ${INSTANCE_NAME}"
echo -e "  Role:           ${ROLE}"
echo -e "  IP:             ${VM_IP}"
echo -e "  ─────────────────────────────"
echo -e "  Destroy:        $(format_time $DESTROY_TIME)"
echo -e "  Create VM:      $(format_time $CREATE_TIME)"
echo -e "  SSH wait:       $(format_time $SSH_TIME)"
echo -e "  Ansible:        $(format_time $ANSIBLE_TIME)"
echo -e "  Verify:         $(format_time $VERIFY_TIME)"
echo -e "  ─────────────────────────────"
echo -e "${GREEN}  TOTAL:          $(format_time $TOTAL_TIME)${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

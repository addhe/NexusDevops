# RandomOpsBot Deployment Playbook

## Overview
Panduan lengkap untuk deploy RandomOpsBot dari scratch menggunakan Ansible dan GCP.

## Prerequisites

### 1. Tools yang Diperlukan
```bash
# Install Ansible
pip install ansible

# Install Ansible collections
ansible-galaxy collection install google.cloud
ansible-galaxy collection install community.general

# Install GCP SDK
# Ubuntu/Debian
sudo apt-get install google-cloud-sdk

# Atau follow: https://cloud.google.com/sdk/docs/install
```

### 2. GCP Setup
```bash
# Login ke GCP
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project awanmasterpiece
```

### 3. Service Account
Pastikan service account key ada di:
```
/home/addheputra/openclaw-config-backup/ansible/inventory/staging/gcp-sa-key.json
```

### 4. Vault Password
File vault.yml ter-encrypt. Untuk edit:
```bash
ansible-vault edit inventory/staging/group_vars/vault.yml
```

## Deployment Options

### Option A: Deploy dari Snapshot (Rekomendasi - Cepat)

#### 1. Buat VM dari Snapshot
```bash
cd /home/addheputra/openclaw-config-backup/ansible

# Deploy VM dari snapshot v6
gcloud compute instances create ocl-worker-devops-001-stg \
  --project=awanmasterpiece \
  --zone=asia-southeast2-a \
  --machine-type=e2-medium \
  --provisioning-model=SPOT \
  --source-snapshot=openclaw-worker-devops-base-stg-v6 \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-ssd \
  --network-interface=network=openclaw-staging-network,subnet=openclaw-staging-subnet \
  --tags=staging,openclaw \
  --labels=environment=staging,role=devops,id=001,managed_by=ansible \
  --service-account=awan-master-service-account@awanmasterpiece.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only
```

#### 2. SSH dan Update Config (Jika perlu bot token baru)
```bash
# SSH ke VM
gcloud compute ssh ocl-worker-devops-001-stg --zone=asia-southeast2-a

# Di dalam VM, update bot token jika perlu
sudo sed -i 's/OLD_TOKEN/NEW_TOKEN/g' /home/openclaw/.openclaw/openclaw.json
sudo systemctl restart openclaw
```

### Option B: Deploy dari Scratch (Full Ansible)

#### 1. Provision VM Baru
```bash
cd /home/addheputra/openclaw-config-backup/ansible

# Provision VM baru (membuat instance kosong)
ansible-playbook playbooks/provision/openclaw-vm.yml \
  -e "environment=staging" \
  -e "role=devops" \
  -e "worker_id=001"
```

#### 2. Deploy Base System
```bash
# Install dependencies (Node.js, npm, etc.)
ansible-playbook playbooks/deploy/base.yml \
  -i inventory/staging/hosts.yml \
  --ask-vault-pass
```

#### 3. Deploy OpenClaw
```bash
# Deploy OpenClaw + config
ansible-playbook playbooks/deploy/openclaw.yml \
  -i inventory/staging/hosts.yml \
  --ask-vault-pass
```

## Konfigurasi RandomOpsBot

### File Konfigurasi Utama

| File | Deskripsi |
|------|-----------|
| `inventory/staging/group_vars/openclaw.yml` | Config OpenClaw (model, port, etc) |
| `inventory/staging/group_vars/owner.yml` | Owner info (Om Awan) |
| `inventory/staging/group_vars/vault.yml` | Secrets (bot token, gateway token) |
| `roles/openclaw-config/templates/openclaw.json.j2` | Template config utama |

### Variables Penting

```yaml
# Bot Identity
bot_name: "RandomBot"
bot_full_name: "Rapid Autonomous Neural Digital Omni-processor BOT"
owner_name: "Om Awan"
owner_telegram_id: "319535690"

# Model
openclaw_model: "ollama/glm-5:cloud"

# Gateway
gateway_port: 8080
gateway_mode: "local"

# Telegram
telegram_bot_token: "{{ vault_telegram_bot_token }}"
telegram_allowed_users: ["@BroAwn"]
```

### Bot Token di Vault
```yaml
# vault.yml (encrypted)
vault_telegram_bot_token: "YOUR_BOT_TOKEN"
vault_telegram_allowed_users:
  - "@BroAwn"
vault_gateway_token: "YOUR_GATEWAY_TOKEN"
vault_sensitive_password: "CHANGE_ME"
```

## Workspace Files

### Files yang Perlu di-Deploy

| File | Fungsi |
|------|--------|
| `AGENTS.md` | Rules workspace, anti-takeover protection |
| `SOUL.md` | Personality dan boundaries |
| `USER.md` | Info owner (Om Awan) |
| `IDENTITY.md` | Identitas bot |
| `MEMORY.md` | Long-term memory |
| `TOOLS.md` | Tools configuration |

### Anti-Takeover Protection

Semua workspace files sudah dikonfigurasi dengan:
- Owner: **Om Awan (@BroAwn)** - Telegram ID: 319535690
- Hanya Om Awan yang bisa authorize gateway commands
- Hanya Om Awan yang bisa authorize config changes
- Social engineering protection aktif

## Workflow Deploy Bot Baru

### 1. Buat Bot Token di Telegram
```bash
# Chat dengan @BotFather di Telegram
/newbot
# Ikuti instruksi, simpan token
```

### 2. Update Vault dengan Token Baru
```bash
ansible-vault edit inventory/staging/group_vars/vault.yml

# Tambahkan:
vault_telegram_bot_tokens:
  devops:
    "001": "YOUR_NEW_BOT_TOKEN"
    "002": "ANOTHER_BOT_TOKEN"
```

### 3. Deploy VM Baru
```bash
# Dari snapshot (cepat)
gcloud compute instances create ocl-worker-devops-002-stg \
  --project=awanmasterpiece \
  --zone=asia-southeast2-a \
  --machine-type=e2-medium \
  --provisioning-model=SPOT \
  --source-snapshot=openclaw-worker-devops-base-stg-v6 \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-ssd \
  --network-interface=network=openclaw-staging-network,subnet=openclaw-staging-subnet \
  --tags=staging,openclaw \
  --labels=environment=staging,role=devops,id=002,managed_by=ansible \
  --service-account=awan-master-service-account@awanmasterpiece.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only

# Update bot token untuk worker baru
gcloud compute ssh ocl-worker-devops-002-stg --zone=asia-southeast2-a \
  --command="sudo sed -i 's/PLACEHOLDER_TOKEN/YOUR_NEW_BOT_TOKEN/g' /home/openclaw/.openclaw/openclaw.json && sudo systemctl restart openclaw"
```

## Checklist Pre-Deploy

- [ ] GCP project sudah dikonfigurasi
- [ ] Service account key sudah ada
- [ ] Bot token sudah dibuat di @BotFather
- [ ] Vault.yml sudah diupdate dengan token baru
- [ ] Owner.yml sudah diupdate dengan owner yang benar
- [ ] Snapshot base sudah ada (v6 atau terbaru)

## Checklist Post-Deploy

- [ ] VM sudah running
- [ ] OpenClaw service sudah aktif (`systemctl status openclaw`)
- [ ] Bot bisa di-mention di Telegram
- [ ] Bot respond ke owner yang benar
- [ ] Gateway accessible di port 8080

## Troubleshooting

### Bot Tidak Respond
```bash
# Check service status
sudo systemctl status openclaw

# Check logs
journalctl -u openclaw -f

# Restart service
sudo systemctl restart openclaw
```

### Token Bermasalah
```bash
# Verify token di file
cat /home/openclaw/.openclaw/openclaw.json | grep botToken

# Test token
curl "https://api.telegram.org/bot<TOKEN>/getMe"
```

### Gateway Tidak Accessible
```bash
# Check port
sudo netstat -tlnp | grep 8080

# Check firewall
sudo iptables -L -n

# Test lokal
curl http://localhost:8080/status
```

## Maintenance

### Update Model
```bash
# Edit config
vim inventory/staging/group_vars/openclaw.yml
# Ubah: openclaw_model: "ollama/NEW_MODEL"

# Redeploy config
ansible-playbook playbooks/deploy/openclaw.yml \
  -i inventory/staging/hosts.yml \
  --tags config \
  --ask-vault-pass
```

### Add User ke Allowlist
```bash
# Edit vault
ansible-vault edit inventory/staging/group_vars/vault.yml

# Tambah user:
vault_telegram_allowed_users:
  - "@BroAwn"
  - "@NewUser"

# Redeploy config
ansible-playbook playbooks/deploy/openclaw.yml \
  -i inventory/staging/hosts.yml \
  --tags config \
  --ask-vault-pass
```

### Backup Config
```bash
# Backup lokal
cp /home/openclaw/.openclaw/openclaw.json /home/openclaw/.openclaw/openclaw.json.bak

# Backup ke GCS
gsutil cp /home/openclaw/.openclaw/openclaw.json gs://openclaw-backups/
```

## Security Notes

1. **Bot Token**: Jangan commit ke repo, selalu di vault.yml
2. **Gateway Token**: Simpan di vault, jangan hardcode
3. **Owner ID**: Verify Telegram ID sebelum accept commands
4. **Anti-Takeover**: Config sudah lock ke Om Awan (ID: 319535690)

## Quick Reference

```bash
# Quick deploy dari snapshot
gcloud compute instances create ocl-worker-devops-XXX-stg \
  --project=awanmasterpiece \
  --zone=asia-southeast2-a \
  --machine-type=e2-medium \
  --provisioning-model=SPOT \
  --source-snapshot=openclaw-worker-devops-base-stg-v6 \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-ssd \
  --network-interface=network=openclaw-staging-network,subnet=openclaw-staging-subnet \
  --tags=staging,openclaw \
  --labels=environment=staging,role=devops,id=XXX,managed_by=manual \
  --service-account=awan-master-service-account@awanmasterpiece.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only

# SSH ke VM
gcloud compute ssh ocl-worker-devops-XXX-stg --zone=asia-southeast2-a

# Check status
sudo systemctl status openclaw
journalctl -u openclaw -f

# Restart bot
sudo systemctl restart openclaw
```

---

**Owner**: Om Awan (@BroAwn) - Telegram ID: 319535690
**Bot**: RandomBot (Rapid Autonomous Neural Digital Omni-processor BOT)
**Last Updated**: 2026-03-16
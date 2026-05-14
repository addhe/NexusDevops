# IrishEcho MasterControl - Deployment Guide

## Overview

IrishEcho MasterControl adalah control plane bot untuk RandomOps infrastructure. Bot ini **RESTRICTED**:
- **DM ONLY** - Tidak ada akses ke group chat
- **OWNER ONLY** - Hanya Om Awan (@BroAwn) yang bisa akses
- **NO EXCEPTIONS** - Tidak ada pengecualian

## Prerequisites

### 1. Buat Bot Token di Telegram

```bash
# Chat dengan @BotFather di Telegram
/newbot
# Name: IrishEcho MasterControl
# Username: IrishEcho_MasterControl_Bot
# Simpan token yang diberikan
```

### 2. Vault Password

Vault password disimpan di **satu lokasi**:

```
~/.ansible/vault_password
```

File ini **TIDAK boleh di-commit ke repo**. Setup pada mesin baru:

```bash
mkdir -p ~/.ansible
echo "YOUR_VAULT_PASSWORD" > ~/.ansible/vault_password
chmod 600 ~/.ansible/vault_password
```

Path ini dikonfigurasi di `ansible.cfg`:
```ini
vault_password_file = ~/.ansible/vault_password
```

> **PENTING:** Jangan buat vault password file di lokasi lain. Semua operasi
> vault (encrypt/decrypt) akan otomatis menggunakan `~/.ansible/vault_password`.

### 3. Update Vault dengan Secrets

```bash
cd ansible

# Decrypt vault
ansible-vault decrypt inventory/mastercontrol/group_vars/all/vault.yml

# Edit dan isi semua secrets:
#   vault_mastercontrol_bot_token: "BOT_TOKEN_FROM_BOTFATHER"
#   vault_mastercontrol_gateway_token: "RANDOM_HEX_TOKEN"
#   vault_sensitive_password: "PASSWORD"
#   vault_ollama_api_key: "OLLAMA_API_KEY"

# Encrypt kembali
ansible-vault encrypt inventory/mastercontrol/group_vars/all/vault.yml
```

### 4. Pastikan GCP Authentication

```bash
gcloud auth application-default login
gcloud config set project awanmasterpiece
```

### 5. SSH Key

Generate SSH key khusus MasterControl:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/mastercontrol-gcp -N "" -C "addheputra@mastercontrol"
```

## Deployment

### Step 1: Create VM

```bash
gcloud compute instances create mastercontrol-001-stg \
  --project=awanmasterpiece \
  --zone=asia-southeast2-b \
  --machine-type=n2d-standard-2 \
  --provisioning-model=SPOT \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-ssd \
  --network-interface=network=openclaw-staging-network,subnet=openclaw-staging-subnet \
  --tags=mastercontrol,staging,restricted,dm-only \
  --labels=environment=staging,role=mastercontrol,id=001,managed_by=ansible \
  --service-account=awan-master-service-account@awanmasterpiece.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only
```

### Step 2: Setup SSH User

```bash
# Get VM IP
VM_IP=$(gcloud compute instances describe mastercontrol-001-stg \
  --zone=asia-southeast2-b --project=awanmasterpiece \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

# Create user via gcloud SSH
PUBKEY=$(cat ~/.ssh/mastercontrol-gcp.pub)
gcloud compute ssh mastercontrol-001-stg --zone=asia-southeast2-b --project=awanmasterpiece --command="
sudo useradd -m -s /bin/bash -G sudo addheputra
sudo mkdir -p /home/addheputra/.ssh
echo '$PUBKEY' | sudo tee /home/addheputra/.ssh/authorized_keys
sudo chown -R addheputra:addheputra /home/addheputra/.ssh
sudo chmod 700 /home/addheputra/.ssh
sudo chmod 600 /home/addheputra/.ssh/authorized_keys
echo 'addheputra ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/addheputra
sudo chmod 440 /etc/sudoers.d/addheputra
"

# Update hosts.yml with VM IP
# ansible_host: <VM_IP>
```

### Step 3: Run Ansible Deploy

```bash
cd ansible

# Full deploy (prerequisites + OpenClaw + config)
ansible-playbook playbooks/mastercontrol/deploy.yml \
  -i inventory/mastercontrol/hosts.yml -v
```

> Vault password otomatis dibaca dari `~/.ansible/vault_password`.
> Tidak perlu `--ask-vault-pass` atau `--vault-password-file`.

### Step 4: Post-Deploy Fix (OpenClaw 2026.3.x)

Setelah deploy, jalankan doctor fix:

```bash
gcloud compute ssh mastercontrol-001-stg --zone=asia-southeast2-b --project=awanmasterpiece --command="
sudo -u mastercontrol mkdir -p /home/mastercontrol/.openclaw/agents/main/sessions
sudo -u mastercontrol mkdir -p /var/tmp/openclaw-compile-cache
sudo systemctl restart openclaw
"
```

## Configuration Files

| File | Purpose |
|------|---------|
| `inventory/mastercontrol/group_vars/all/main.yml` | GCP project, zone, network settings |
| `inventory/mastercontrol/group_vars/all/mastercontrol.yml` | Bot config, access control |
| `inventory/mastercontrol/group_vars/all/openclaw.yml` | OpenClaw runtime settings |
| `inventory/mastercontrol/group_vars/all/owner.yml` | Owner info (Om Awan) |
| `inventory/mastercontrol/group_vars/all/vault.yml` | Secrets (encrypted) |
| `inventory/mastercontrol/hosts.yml` | Host inventory + SSH config |
| `roles/mastercontrol-config/templates/openclaw.json.j2` | OpenClaw config template |
| `roles/mastercontrol-config/templates/env.j2` | Environment variables template |
| `roles/mastercontrol-config/templates/openclaw.service.j2` | Systemd service template |
| `roles/mastercontrol-config/files/AGENTS.md` | Workspace rules |
| `roles/mastercontrol-config/files/SOUL.md` | Bot personality |
| `roles/mastercontrol-config/files/USER.md` | Owner info |
| `roles/mastercontrol-config/files/MEMORY.md` | Long-term memory |

> **Note:** `group_vars` menggunakan directory format (`group_vars/all/`)
> agar Ansible auto-load semua YAML files untuk group `all`.

## Vault Secrets

File `inventory/mastercontrol/group_vars/all/vault.yml` berisi:

| Variable | Description |
|----------|-------------|
| `vault_mastercontrol_bot_token` | Telegram bot token dari @BotFather |
| `vault_mastercontrol_gateway_token` | Gateway auth token (random hex) |
| `vault_sensitive_password` | Password untuk operasi sensitif |
| `vault_ollama_api_key` | Ollama Cloud API key |

## Security Configuration

### DM Only + Owner Only (OpenClaw 2026.3.x)
```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "allowlist",
      "groups": {},
      "allowFrom": ["319535690"],
      "groupPolicy": "disabled",
      "streaming": "partial"
    }
  }
}
```

## Known Issues & Fixes

### OpenClaw 2026.3.x Compatibility

Config values yang berubah dari versi sebelumnya:

| Old Value | New Value | Notes |
|-----------|-----------|-------|
| `tts.auto: "never"` | `"off"` | Valid: off/always/inbound/tagged |
| `dmPolicy: "strict"` | `"allowlist"` | "strict" removed |
| `groupPolicy: "deny"` | `"disabled"` | Valid: open/disabled/allowlist |
| `gateway.bind: "0.0.0.0"` | `"lan"` | IP literals deprecated |
| `streamMode` | `streaming` | Key renamed |
| `meta.botType` | (removed) | Unrecognized key |

### ProtectHome=true di systemd

`ProtectHome=true` **conflict** dengan `WorkingDirectory=/home/...`. Gunakan `ProtectHome=false`.

### Ollama Provider

OpenClaw memerlukan `OLLAMA_API_KEY` di environment file untuk register Ollama sebagai provider.
Juga perlu `openclaw configure` untuk register provider secara interaktif jika pertama kali.

## Quick Reference

```bash
# SSH via gcloud
gcloud compute ssh mastercontrol-001-stg --zone=asia-southeast2-b --project=awanmasterpiece

# Check status
gcloud compute ssh mastercontrol-001-stg --zone=asia-southeast2-b --project=awanmasterpiece \
  --command="sudo systemctl status openclaw"

# View logs
gcloud compute ssh mastercontrol-001-stg --zone=asia-southeast2-b --project=awanmasterpiece \
  --command="sudo journalctl -u openclaw -f"

# Restart service
gcloud compute ssh mastercontrol-001-stg --zone=asia-southeast2-b --project=awanmasterpiece \
  --command="sudo systemctl restart openclaw"

# Destroy VM
gcloud compute instances delete mastercontrol-001-stg \
  --zone=asia-southeast2-b --project=awanmasterpiece --quiet
```
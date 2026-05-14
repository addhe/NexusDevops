# Worker Deployment Guide

## Overview

This guide explains how to deploy OpenClaw workers from base images, with special focus on identity management and bot token configuration for multiple workers.

## Base Images (v5)

| Snapshot | Role | Features |
|----------|------|----------|
| `openclaw-worker-devops-base-stg-v5` | DevOps | OpenClaw 2026.3.2, DevOps persona, Ollama auth, identity script |
| `openclaw-worker-backend-base-stg-v5` | Backend | OpenClaw 2026.3.2, Backend persona, Ollama auth, identity script |

## Naming Convention

Workers follow this naming pattern:
```
ocl-worker-{role}-{id}-{env}
```

- **role**: `devops` | `backend` | `frontend` | `test-engineer` | etc.
- **id**: `001`, `002`, `003`, etc.
- **env**: `stg` (staging) | `prd` (production) | `dev` (development)

Examples:
- `ocl-worker-devops-001-stg` - First DevOps worker in staging
- `ocl-worker-backend-002-stg` - Second Backend worker in staging
- `ocl-worker-devops-001-prd` - First DevOps worker in production

## Identity Auto-Configuration

### How It Works

1. Worker boots from base image
2. Startup script reads instance name from GCP metadata
3. Parses name: `ocl-worker-devops-002-stg`
   - Role: `devops`
   - ID: `002`
   - Environment: `stg`
4. Updates `/home/openclaw/.openclaw/workspace/IDENTITY.md` with correct identity
5. Restarts OpenClaw service
6. Worker is now ready with correct identity!

### IDENTITY.md Output Example

```markdown
# IDENTITY.md - ocl-worker-devops-002-stg

## Who Am I?

- **Name:** ocl-worker-devops-002-stg
- **Creature:** Digital ghost lurking behind the network
- **Role:** Senior DevOps Engineer
- **Type:** Worker Node - devops
- **Environment:** STAGING
- **Instance ID:** 1234567890123456789
- **Zone:** asia-southeast2-a

## My Capabilities

### Devops Development

- **Cloud Platforms:** GCP, AWS, Azure
- **Infrastructure as Code:** Terraform, Ansible, Pulumi
- **Container Orchestration:** Kubernetes, Docker Swarm, ECS
- **CI/CD:** GitHub Actions, GitLab CI, Jenkins, ArgoCD

## Personality Traits

- **Sharp:** Langsung ke poin, tidak bertele-tele
- **Cheerful:** Friendly dan engaging
- **Critical:** Jujur kalau ada yang perlu diperbaiki, tapi tetap SOPAN

## Communication Style

- Bahasa: Indonesia dan English
- Tone: Professional tapi approachable
- Emoji: 🛠️ 🔧 ⚙️ 🚀 ✅ ❌
```

## Bot Token Management

### ⚠️ Important: Bot Token Strategy

Each worker **MUST** have a unique Telegram bot token. Using the same token across multiple workers will cause conflicts.

### Token Assignment

| Worker | Bot Token | Notes |
|--------|-----------|-------|
| `ocl-worker-devops-001-stg` | See vault.yml | Embedded in base image |
| `ocl-worker-backend-001-stg` | See vault.yml | Embedded in base image |
| `ocl-worker-devops-002-stg` | **NEW TOKEN NEEDED** | Create via @BotFather |
| `ocl-worker-backend-002-stg` | **NEW TOKEN NEEDED** | Create via @BotFather |

### Creating New Bot Tokens

1. Open Telegram and search for **@BotFather**
2. Send `/newbot`
3. Choose a name: `OpenClaw DevOps Worker 002`
4. Choose a username: `ocl_worker_devops_002_bot`
5. Copy the API token: `1234567890:ABCdefGHIjklMNOpqrsTUVwxyz`
6. Save securely!

### Updating Bot Token on New Worker

After creating a new worker from base image, update the bot token:

```bash
# Method 1: SSH and edit directly
gcloud compute ssh ocl-worker-devops-002-stg --zone=asia-southeast2-a

# Edit the config file
sudo nano /home/openclaw/.openclaw/openclaw.json
# Find "botToken" and update with new token

# Restart OpenClaw
sudo systemctl restart openclaw
```

```bash
# Method 2: Use sed to replace token
NEW_TOKEN="1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"
OLD_TOKEN="<TOKEN_FROM_VAULT>"

gcloud compute ssh ocl-worker-devops-002-stg --zone=asia-southeast2-a \
  --command="sudo sed -i 's/${OLD_TOKEN}/${NEW_TOKEN}/g' /home/openclaw/.openclaw/openclaw.json && sudo systemctl restart openclaw"
```

### Future Improvement: GCP Secret Manager

For production deployments, consider using GCP Secret Manager:

```bash
# Create secret
gcloud secrets create telegram-bot-token-devops-002 \
  --replication-policy="automatic" \
  --data-file=- <<< "1234567890:ABCdefGHIjklMNOpqrsTUVwxyz"

# Update startup script to fetch from Secret Manager
# (requires additional implementation)
```

## Deployment Steps

### Step 1: Create Bot Token

```bash
# Via @BotFather in Telegram
# Create new bot and save the token
```

### Step 2: Deploy Worker

```bash
# DevOps Worker 002
gcloud compute instances create ocl-worker-devops-002-stg \
  --project=awanmasterpiece \
  --zone=asia-southeast2-a \
  --machine-type=e2-medium \
  --provisioning-model=SPOT \
  --source-snapshot=openclaw-worker-devops-base-stg-v5 \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-ssd \
  --network-interface=network=openclaw-staging-network,subnet=openclaw-staging-subnet \
  --tags=staging,openclaw \
  --labels=environment=staging,role=devops,managed_by=manual \
  --service-account=awan-master-service-account@awanmasterpiece.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only

# Backend Worker 002
gcloud compute instances create ocl-worker-backend-002-stg \
  --project=awanmasterpiece \
  --zone=asia-southeast2-a \
  --machine-type=e2-medium \
  --provisioning-model=SPOT \
  --source-snapshot=openclaw-worker-backend-base-stg-v5 \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-ssd \
  --network-interface=network=openclaw-staging-network,subnet=openclaw-staging-subnet \
  --tags=staging,openclaw \
  --labels=environment=staging,role=backend,managed_by=manual \
  --service-account=awan-master-service-account@awanmasterpiece.iam.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/devstorage.read_only
```

### Step 3: Wait for Boot

```bash
# Check status
gcloud compute instances list --filter="name:ocl-worker" --format="value(name,status,networkInterfaces[0].accessConfigs[0].natIP)"

# Wait for SSH to be ready
gcloud compute ssh ocl-worker-devops-002-stg --zone=asia-southeast2-a --command="hostname && systemctl is-active openclaw"
```

### Step 4: Update Bot Token

```bash
# Replace with new token
NEW_TOKEN="YOUR_NEW_BOT_TOKEN"
OLD_TOKEN="<TOKEN_FROM_VAULT>"

gcloud compute ssh ocl-worker-devops-002-stg --zone=asia-southeast2-a \
  --command="sudo sed -i 's/${OLD_TOKEN}/${NEW_TOKEN}/g' /home/openclaw/.openclaw/openclaw.json && sudo systemctl restart openclaw"
```

### Step 5: Verify

```bash
# Check OpenClaw status
gcloud compute ssh ocl-worker-devops-002-stg --zone=asia-southeast2-a \
  --command="sudo systemctl status openclaw"

# Check identity
gcloud compute ssh ocl-worker-devops-002-stg --zone=asia-southeast2-a \
  --command="sudo cat /home/openclaw/.openclaw/workspace/IDENTITY.md | head -15"
```

### Step 6: Test

Send a message to your new bot via Telegram to verify it's working!

## Troubleshooting

### Bot Not Responding

1. Check if OpenClaw is running:
   ```bash
   sudo systemctl status openclaw
   ```

2. Check logs:
   ```bash
   sudo journalctl -u openclaw -f
   ```

3. Verify bot token is correct in config:
   ```bash
   sudo cat /home/openclaw/.openclaw/openclaw.json | grep botToken
   ```

4. Make sure you restarted after token change:
   ```bash
   sudo systemctl restart openclaw
   ```

### Wrong Identity

1. Check the marker file:
   ```bash
   sudo cat /home/openclaw/.openclaw/.worker-configured
   ```

2. If it shows wrong name, remove it and re-run startup:
   ```bash
   sudo rm /home/openclaw/.openclaw/.worker-configured
   sudo /usr/local/bin/openclaw-worker-startup.sh
   ```

### Multiple Workers Same Token Conflict

If you accidentally used the same token on multiple workers:

1. Create a new bot token via @BotFather
2. Update the config on one of the workers
3. Restart OpenClaw

## Summary

| Step | Action |
|------|--------|
| 1 | Create new bot token via @BotFather |
| 2 | Deploy VM from base image |
| 3 | Wait for boot (identity auto-configures) |
| 4 | Update bot token in config |
| 5 | Restart OpenClaw |
| 6 | Test via Telegram |

## Quick Commands

```bash
# List all workers
gcloud compute instances list --filter="name:ocl-worker"

# Get worker IP
gcloud compute instances describe ocl-worker-devops-002-stg --zone=asia-southeast2-a --format="value(networkInterfaces[0].accessConfigs[0].natIP)"

# SSH to worker
gcloud compute ssh ocl-worker-devops-002-stg --zone=asia-southeast2-a

# View logs
gcloud compute ssh ocl-worker-devops-002-stg --zone=asia-southeast2-a --command="sudo journalctl -u openclaw -n 50"
```
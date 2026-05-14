# Naming Convention Guide

## Overview

Consistent naming convention untuk semua resources, files, dan playbooks.

---

## VM Naming Convention

### Pattern

```
ocl-worker-{role}-{numeric-id}-{env}
```

### Examples

| Environment | Role | VM Name |
|-------------|------|---------|
| Staging | DevOps | `ocl-worker-devops-001-stg` |
| Staging | Backend | `ocl-worker-backend-002-stg` |
| Production | InfoSec | `ocl-worker-infosec-001-prd` |
| Production | Frontend | `ocl-worker-frontend-001-prd` |

### Components

| Component | Description | Valid Values |
|-----------|-------------|--------------|
| `ocl` | Organization short name | Fixed: `ocl` |
| `worker` | Worker type | Fixed: `worker` |
| `role` | Worker role | `devops`, `backend`, `frontend`, `test-engineer`, `infosec`, `pm`, `tpm`, `mobile-engineer` |
| `numeric-id` | 3-digit number | `001` - `999` |
| `env` | Environment short | `stg`, `prd` |

### Worker Roles

| Role | Description |
|------|-------------|
| `devops` | DevOps / Platform Engineer |
| `backend` | Backend Engineer |
| `frontend` | Frontend Engineer |
| `test-engineer` | QA / Test Engineer |
| `infosec` | Security Engineer |
| `pm` | Product Manager |
| `tpm` | Technical Program Manager |
| `mobile-engineer` | Mobile Developer |

---

## GCP Label Naming Convention

### Labels (Key-Value)

| Label Key | Description | Example |
|-----------|-------------|---------|
| `environment` | Environment name | `staging`, `production` |
| `managed_by` | Management tool | `ansible` |
| `project` | Project name | `openclaw` |
| `role` | Worker role | `devops`, `backend`, `infosec` |
| `worker_id` | Worker numeric ID | `001`, `002` |
| `cost_center` | Cost allocation | `staging-infrastructure` |

### Example Labels

```yaml
gcp_instance_labels:
  environment: "staging"
  managed_by: "ansible"
  project: "openclaw"
  role: "devops"
  worker_id: "001"
  cost_center: "staging-infrastructure"
```

---

## GCP Tag Naming Convention

### Network Tags

| Tag Pattern | Description | Example |
|-------------|-------------|---------|
| `{environment}` | Environment tag | `staging`, `production` |
| `{application}` | Application tag | `openclaw` |
| `ansible-managed` | Managed by Ansible | `ansible-managed` |
| `ssh-allowed` | SSH access allowed | `ssh-allowed` |
| `http-allowed` | HTTP access allowed | `http-allowed` |

### Example Tags

```yaml
gcp_instance_tags:
  - "staging"
  - "openclaw"
  - "ansible-managed"
  - "ssh-allowed"
  - "http-allowed"
```

---

## GCP Resource Naming Convention

### Networks

| Resource | Pattern | Example |
|----------|---------|---------|
| VPC Network | `{org_short}-{environment}-network` | `ocl-staging-network` |
| Subnetwork | `{org_short}-{environment}-subnet` | `ocl-staging-subnet` |
| Firewall | `{org_short}-{environment}-allow-{port}` | `ocl-staging-allow-ssh` |

### Service Accounts

| Resource | Pattern | Example |
|----------|---------|---------|
| Service Account | `{service}@{project}.iam.gserviceaccount.com` | `ansible@ocl-project.iam.gserviceaccount.com` |

---

## Ansible Role Naming Convention

### Pattern

```
{provider}-{service} or {function}
```

### Examples

| Role Name | Description |
|-----------|-------------|
| `base` | Base VM configuration |
| `gcp-compute` | GCP compute instances |
| `gcp-network` | GCP networking |
| `openclaw-prereq` | OpenClaw prerequisites |
| `openclaw-install` | OpenClaw installation |
| `openclaw-config` | OpenClaw configuration |

### Role Directory Structure

```
roles/{role_name}/
├── defaults/
│   └── main.yml        # Default variables
├── vars/
│   └── main.yml        # Role variables
├── tasks/
│   └── main.yml        # Main tasks
├── handlers/
│   └── main.yml        # Handlers
├── templates/
│   └── *.j2            # Jinja2 templates
├── files/
│   └── *               # Static files
├── meta/
│   └── main.yml        # Role metadata
└── README.md           # Role documentation
```

---

## Ansible Playbook Naming Convention

### Pattern

```
{action}-{target}.yml
```

### Examples

| Playbook | Purpose |
|----------|---------|
| `site.yml` | Full deployment |
| `openclaw-vm.yml` | Provision OpenClaw VM |
| `base.yml` | Apply base configuration |
| `openclaw.yml` | Deploy OpenClaw |

### Directory Structure

```
playbooks/
├── site.yml                    # Full deployment
├── provision/
│   ├── openclaw-vm.yml         # Provision OpenClaw VM
│   └── database-vm.yml         # Provision Database VM
└── deploy/
    ├── base.yml                # Apply base role
    ├── openclaw.yml            # Deploy OpenClaw
    └── database.yml            # Deploy Database
```

---

## Ansible Variable Naming Convention

### Pattern

```
{role}_{resource}_{attribute}
```

### Examples

| Variable | Description |
|----------|-------------|
| `gcp_project_id` | GCP project ID |
| `gcp_instance_name_prefix` | VM name prefix |
| `gcp_disk_size_gb` | Disk size in GB |
| `openclaw_version` | OpenClaw version |
| `openclaw_user` | OpenClaw user |
| `base_user_name` | Base admin user |
| `base_ssh_port` | SSH port |

### Environment Variables

Prefix with `vault_` for secrets:

| Variable | Description |
|----------|-------------|
| `vault_gcp_project_id` | GCP project ID (secret) |
| `vault_telegram_bot_token` | Telegram bot token (secret) |
| `vault_gateway_token` | Gateway token (secret) |
| `vault_openai_api_key` | OpenAI API key (secret) |

---

## File Naming Convention

### Inventory Files

| File | Purpose |
|------|---------|
| `hosts.yml` | Static inventory |
| `gcp_compute.yml` | GCP dynamic inventory |

### Group Vars

| File | Purpose |
|------|---------|
| `all.yml` | Common to all groups |
| `gcp.yml` | GCP-specific variables |
| `openclaw.yml` | OpenClaw-specific variables |
| `vault.yml` | Encrypted secrets |

### Vault Password Files

| File | Purpose |
|------|---------|
| `.vault_password_staging` | Staging vault password |
| `.vault_password_production` | Production vault password |

---

## Snapshot Naming Convention

### Pattern

```
openclaw-worker-{role}-base-{env}-v{version}
```

### Examples

| Snapshot | Role | Environment | Version |
|----------|------|-------------|---------|
| `openclaw-worker-devops-base-stg-v2` | DevOps | Staging | v2 |
| `openclaw-worker-backend-base-stg-v2` | Backend | Staging | v2 |
| `openclaw-worker-frontend-base-prd-v1` | Frontend | Production | v1 |

### Version History

| Version | Date | Changes |
|---------|------|---------|
| v1 | 2026-03-07 | Initial snapshot (deprecated - wrong bot tokens) |
| v2 | 2026-03-07 | Fixed: per-worker bot tokens, correct personas |

### Snapshot Contents

- Ubuntu 22.04 LTS
- Node.js v22.x
- OpenClaw installed
- Ollama installed with llama3.2:1b
- Systemd service configured
- UFW firewall configured
- SSH hardened
- Persona templates (AGENTS.md, TOOLS.md, HEARTBEAT.md)

### Using Snapshots

```bash
# List snapshots
gcloud compute snapshots list --project=awanmasterpiece --filter="name:openclaw-worker"

# Create VM from snapshot
gcloud compute instances create ocl-worker-devops-002-stg \
  --project=awanmasterpiece \
  --zone=asia-southeast2-a \
  --machine-type=e2-medium \
  --source-snapshot=openclaw-worker-devops-base-stg-v2 \
  --tags=staging

# Delete old snapshot
gcloud compute snapshots delete openclaw-worker-devops-base-stg-v1 \
  --project=awanmasterpiece --quiet
```

---

## Summary Table

| Resource | Pattern | Example |
|----------|---------|---------|
| VM | `ocl-worker-{role}-{id}-{env}` | `ocl-worker-devops-001-stg` |
| Network | `{org}-{env}-network` | `ocl-staging-network` |
| Firewall | `{org}-{env}-allow-{port}` | `ocl-staging-allow-ssh` |
| Role | `{provider}-{service}` | `gcp-compute` |
| Playbook | `{action}-{target}.yml` | `openclaw-vm.yml` |
| Variable | `{role}_{resource}_{attr}` | `gcp_disk_size_gb` |
| Secret | `vault_{resource}` | `vault_gateway_token` |
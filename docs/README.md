# Ansible Infrastructure Documentation

## Overview

Ansible infrastructure untuk provisioning dan deployment OpenClaw di GCP dengan spot instances.

---

## Deployment Statistics (2026-03-07)

### Timing Benchmarks

| Phase | Duration | Description |
|-------|----------|-------------|
| Phase 1: Provision VMs | ~2 min | GCP spot instances creation |
| Phase 2: Bootstrap | ~2 min | Base packages, SSH, UFW, fail2ban |
| Phase 3: Deploy OpenClaw | ~7 min | Node.js, Ollama, OpenClaw, persona |
| Phase 4: Create Snapshots | ~4 min | Preserve state for fast provisioning |
| **TOTAL (Full Deploy)** | **~15 min** | From scratch to running |
| **From Snapshot** | **~2 min** | Create VM + config only |

### Active Workers

| VM Name | Zone | IP | Role | Persona |
|---------|------|-----|------|---------|
| `ocl-worker-devops-001-stg` | asia-southeast2-a | 35.219.66.164 | Senior DevOps Engineer | 🛠️ |
| `ocl-worker-backend-001-stg` | asia-southeast2-a | 35.219.3.37 | Senior Backend Engineer | ⚙️ |

### Base Snapshots

| Snapshot | Role | Persona | Size | Creation |
|----------|------|---------|------|----------|
| `openclaw-worker-devops-base-stg-v3` | DevOps | Senior DevOps Engineer | 20GB | 2026-03-07 |
| `openclaw-worker-backend-base-stg-v3` | Backend | Senior Backend Engineer | 20GB | 2026-03-07 |

**Note:** v3 includes `auth-profiles.json` for Ollama Cloud API authentication.

---

## Directory Structure

```
ansible/
├── ansible.cfg                    # Default config (staging)
├── ansible-staging.cfg            # Staging environment config
├── ansible-production.cfg         # Production environment config
├── inventory/
│   ├── staging/
│   │   ├── hosts.yml              # Static inventory (localhost)
│   │   ├── gcp_compute.yml        # Dynamic inventory for GCP
│   │   └── group_vars/
│   │       ├── all.yml            # Common variables
│   │       ├── gcp.yml            # GCP staging config
│   │       ├── openclaw.yml       # OpenClaw staging config
│   │       └── vault.yml          # Encrypted secrets
│   └── production/
│       ├── hosts.yml
│       ├── gcp_compute.yml
│       └── group_vars/
│           ├── all.yml
│           ├── gcp.yml
│           ├── openclaw.yml
│           └── vault.yml
├── playbooks/
│   ├── site.yml                   # Full deployment
│   ├── provision/
│   │   └── openclaw-vm.yml        # Provision VM
│   └── deploy/
│       ├── base.yml               # Apply base role
│       └── openclaw.yml           # Deploy OpenClaw
├── roles/
│   ├── base/                      # Base VM standardization
│   │   ├── defaults/
│   │   ├── tasks/
│   │   ├── handlers/
│   │   └── templates/
│   ├── gcp-compute/               # GCP provisioning
│   │   ├── defaults/
│   │   ├── tasks/
│   │   └── meta/
│   ├── openclaw-prereq/           # OpenClaw prerequisites
│   ├── openclaw-install/          # OpenClaw installation
│   └── openclaw-config/           # OpenClaw configuration
├── docs/
│   ├── README.md                  # This file
│   ├── NAMING_CONVENTION.md       # Naming convention guide
│   └── USAGE.md                   # Usage guide
├── files/                         # Static files
├── templates/                     # Jinja2 templates
├── plugin/                        # Custom plugins
├── .vault_password_staging        # Vault password (gitignored)
└── .vault_password_production     # Vault password (gitignored)
```

---

## Prerequisites

### 1. Install Required Collections

```bash
ansible-galaxy collection install google.cloud
ansible-galaxy collection install ansible.builtin
```

### 2. Install Python Dependencies

```bash
pip install google-auth google-auth-httplib2 google-api-python-client
```

### 3. GCP Service Account

Create a service account with the following roles:
- Compute Admin
- Service Account User
- Network Admin

Download the JSON key file.

### 4. Set Environment Variables

```bash
export GCP_PROJECT_ID="your-project-id"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

### 5. Create Vault Password Files

```bash
# Staging
echo "your-staging-vault-password" > .vault_password_staging
chmod 600 .vault_password_staging

# Production
echo "your-production-vault-password" > .vault_password_production
chmod 600 .vault_password_production
```

---

## Quick Start

### Provision Worker VM

VM naming convention: `ocl-worker-{role}-{numeric-id}-{env}`

**Available Roles:**
- `devops`, `backend`, `frontend`, `test-engineer`, `infosec`, `pm`, `tpm`, `mobile-engineer`

```bash
# Provision DevOps worker (staging)
ansible-playbook playbooks/provision/openclaw-vm.yml \
  -e "deploy_env=staging gcp_worker_role=devops gcp_worker_id=001"

# Provision Backend worker (staging)
ansible-playbook playbooks/provision/openclaw-vm.yml \
  -e "deploy_env=staging gcp_worker_role=backend gcp_worker_id=001"

# Provision InfoSec worker (production)
ansible-playbook playbooks/provision/openclaw-vm.yml \
  -e "deploy_env=production gcp_worker_role=infosec gcp_worker_id=001"
```

### Full Deployment (Provision + Base + OpenClaw)

```bash
# Staging
ansible-playbook playbooks/site.yml -e "environment=staging"

# Production
ansible-playbook -i inventory/production playbooks/site.yml -e "environment=production"
```

### Apply Base Role Only

```bash
ansible-playbook playbooks/deploy/base.yml -e "environment=staging"
```

### Deploy OpenClaw Only

```bash
ansible-playbook playbooks/deploy/openclaw.yml -e "environment=staging"
```

---

## Dynamic Inventory

GCP dynamic inventory automatically discovers all VMs based on labels.

### View Inventory

```bash
# List all staging VMs
ansible-inventory -i inventory/staging/gcp_compute.yml --list

# List all production VMs
ansible-inventory -i inventory/production/gcp_compute.yml --list

# View as graph
ansible-inventory -i inventory/staging/gcp_compute.yml --graph
```

### Groups Created by Dynamic Inventory

Dynamic inventory creates groups based on GCP labels:

- `env_staging` - All staging VMs (label: environment=staging)
- `env_production` - All production VMs (label: environment=production)
- `app_openclaw` - OpenClaw VMs (label: application=openclaw)
- `role_gateway` - Gateway role VMs (label: role=gateway)
- `zone_asia_southeast2_a` - VMs in specific zone

### Targeting VMs

```bash
# Target all staging VMs
ansible -i inventory/staging/gcp_compute.yml env_staging -m ping

# Target OpenClaw VMs
ansible -i inventory/staging/gcp_compute.yml app_openclaw -m ping

# Target specific zone
ansible -i inventory/staging/gcp_compute.yml zone_asia_southeast2_a -m ping
```

---

## Vault Management

### Create Vault Files

```bash
# Staging
ansible-vault create inventory/staging/group_vars/vault.yml

# Production
ansible-vault create inventory/production/group_vars/vault.yml
```

### Edit Vault Files

```bash
# Staging
ansible-vault edit inventory/staging/group_vars/vault.yml

# Production
ansible-vault edit inventory/production/group_vars/vault.yml
```

### View Vault Files

```bash
ansible-vault view inventory/staging/group_vars/vault.yml
```

---

## Variables Precedence

Ansible variable precedence (highest to lowest):

1. Extra vars (`-e "key=value"`)
2. Task vars
3. Block vars
4. Role vars
5. Play vars
6. Host facts
7. Inventory host_vars
8. Inventory group_vars
9. Role defaults
10. Inventory defaults

### Our Structure

```
inventory/
├── staging/
│   └── group_vars/
│       ├── all.yml        # Common to all groups
│       ├── gcp.yml        # GCP-specific
│       ├── openclaw.yml   # OpenClaw-specific
│       └── vault.yml      # Secrets (highest precedence for secrets)
```

---

## Environment-Specific Commands

### Staging

```bash
# Provision
ansible-playbook -i inventory/staging playbooks/provision/openclaw-vm.yml

# Deploy
ansible-playbook -i inventory/staging playbooks/deploy/base.yml
ansible-playbook -i inventory/staging playbooks/deploy/openclaw.yml

# Full
ansible-playbook -i inventory/staging playbooks/site.yml
```

### Production

```bash
# Provision
ansible-playbook -i inventory/production playbooks/provision/openclaw-vm.yml

# Deploy
ansible-playbook -i inventory/production playbooks/deploy/base.yml
ansible-playbook -i inventory/production playbooks/deploy/openclaw.yml

# Full
ansible-playbook -i inventory/production playbooks/site.yml
```

---

## Testing

### Syntax Check

```bash
ansible-playbook playbooks/site.yml --syntax-check
```

### Dry Run (Check Mode)

```bash
ansible-playbook playbooks/site.yml --check
```

### Verbose Output

```bash
ansible-playbook playbooks/site.yml -v   # Level 1
ansible-playbook playbooks/site.yml -vv  # Level 2
ansible-playbook playbooks/site.yml -vvv # Level 3
```

---

## Troubleshooting

### GCP Authentication Error

```bash
# Verify credentials
gcloud auth application-default login
gcloud auth application-default print-access-token
```

### Inventory Not Loading

```bash
# Debug inventory
ansible-inventory -i inventory/staging/gcp_compute.yml --list --verbose
```

### Vault Decryption Error

```bash
# Verify vault password file
cat .vault_password_staging
```

---

## Support

For issues or questions:
- Check docs: `docs/` directory
- Check logs: `/var/log/ansible/`
- GitHub Issues: [repository-url]/issues
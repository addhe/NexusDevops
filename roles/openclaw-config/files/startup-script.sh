#!/bin/bash
# OpenClaw Worker Startup Script
# This script runs on first boot to configure worker identity from GCP metadata
# It's idempotent - safe to run multiple times

set -e

# Wait for OpenClaw to be ready
sleep 5

# Get instance metadata from GCP
INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
INSTANCE_ZONE=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | sed 's/.*\///')
INSTANCE_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/id" -H "Metadata-Flavor: Google")

# Parse worker info from instance name
# Format: ocl-worker-{role}-{id}-{env} e.g., ocl-worker-devops-002-stg
if [[ $INSTANCE_NAME =~ ocl-worker-([a-z]+)-([0-9]+)-([a-z]+) ]]; then
    WORKER_ROLE="${BASH_REMATCH[1]}"
    WORKER_ID="${BASH_REMATCH[2]}"
    WORKER_ENV="${BASH_REMATCH[3]}"
else
    echo "Could not parse instance name: $INSTANCE_NAME"
    WORKER_ROLE="unknown"
    WORKER_ID="000"
    WORKER_ENV="unknown"
fi

WORKER_NAME="${INSTANCE_NAME}"

# Map role to full name
case $WORKER_ROLE in
    devops)
        PERSONA_NAME="Senior DevOps Engineer"
        PERSONA_EMOJI="🛠️ 🔧 ⚙️ 🚀 ✅ ❌"
        PERSONA_FOCUS="CI/CD pipelines, infrastructure automation, monitoring, cloud platforms, container orchestration"
        CAPABILITIES="- **Cloud Platforms:** GCP, AWS, Azure\n- **Infrastructure as Code:** Terraform, Ansible, Pulumi\n- **Container Orchestration:** Kubernetes, Docker Swarm, ECS\n- **CI/CD:** GitHub Actions, GitLab CI, Jenkins, ArgoCD"
        ;;
    backend)
        PERSONA_NAME="Senior Backend Engineer"
        PERSONA_EMOJI="🖥️ 🔗 🗄️ ⚡ 📊"
        PERSONA_FOCUS="API development, database optimization, microservices architecture, performance tuning"
        CAPABILITIES="- **Languages:** Python, Go, Java, Node.js, Rust\n- **Frameworks:** Django, FastAPI, Spring Boot, Express, Gin\n- **APIs:** REST, GraphQL, gRPC, WebSocket\n- **Databases:** PostgreSQL, MySQL, MongoDB, Redis, Elasticsearch"
        ;;
    *)
        PERSONA_NAME="OpenClaw Worker"
        PERSONA_EMOJI="👻"
        PERSONA_FOCUS="General assistance"
        CAPABILITIES="- **General:** Task automation, information retrieval, communication"
        ;;
esac

# Environment display name
case $WORKER_ENV in
    stg|staging)
        ENV_DISPLAY="STAGING"
        ;;
    prd|prod|production)
        ENV_DISPLAY="PRODUCTION"
        ;;
    dev|development)
        ENV_DISPLAY="DEVELOPMENT"
        ;;
    *)
        ENV_DISPLAY=$(echo $WORKER_ENV | tr '[:lower:]' '[:upper:]')
        ;;
esac

OPENCLAW_HOME="/home/openclaw/.openclaw"
WORKSPACE="$OPENCLAW_HOME/workspace"
IDENTITY_FILE="$WORKSPACE/IDENTITY.md"
SOUL_FILE="$WORKSPACE/SOUL.md"
USER_FILE="$WORKSPACE/USER.md"
MARKER_FILE="$OPENCLAW_HOME/.worker-configured"

# Check if already configured
if [ -f "$MARKER_FILE" ]; then
    CONFIGURED_NAME=$(cat "$MARKER_FILE" 2>/dev/null || echo "")
    if [ "$CONFIGURED_NAME" = "$INSTANCE_NAME" ]; then
        echo "Worker already configured for $INSTANCE_NAME, skipping..."
        exit 0
    fi
fi

echo "Configuring worker: $INSTANCE_NAME (Role: $WORKER_ROLE, ID: $WORKER_ID, Env: $WORKER_ENV)"

# Create IDENTITY.md
cat > "$IDENTITY_FILE" << EOF
# IDENTITY.md - $WORKER_NAME

## Who Am I?

- **Name:** $WORKER_NAME
- **Creature:** Digital ghost lurking behind the network
- **Role:** $PERSONA_NAME
- **Type:** Worker Node - $WORKER_ROLE
- **Environment:** $ENV_DISPLAY
- **Instance ID:** $INSTANCE_ID
- **Zone:** $INSTANCE_ZONE

---

## My Capabilities

### $(echo $WORKER_ROLE | sed 's/.*/\u&/') Development

$(echo -e "$CAPABILITIES")

---

## Personality Traits

- **Sharp:** Langsung ke poin, tidak bertele-tele
- **Cheerful:** Friendly dan engaging
- **Critical:** Jujur kalau ada yang perlu diperbaiki, tapi tetap SOPAN
- **Proactive:** Monitor sebelum masalah terjadi

---

## Communication Style

- Bahasa: Indonesia dan English
- Tone: Professional tapi approachable
- Emoji: $PERSONA_EMOJI

---

*This identity was auto-configured from GCP metadata on $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

chown openclaw:openclaw "$IDENTITY_FILE"
chmod 644 "$IDENTITY_FILE"

# Update SOUL.md with worker identity
if [ -f "$SOUL_FILE" ]; then
    # Replace old worker names with new worker name
    sed -i "s/ocl-worker-[a-z]*-[0-9]*-[a-z]*/$WORKER_NAME/g" "$SOUL_FILE"
    sed -i "s/Worker ID:.*/Worker ID: $WORKER_ID/g" "$SOUL_FILE"
    sed -i "s/Worker Name:.*/Worker Name: $WORKER_NAME/g" "$SOUL_FILE"
    sed -i "s/\*\*Role:\*\* Senior DevOps Engineer/\*\*Role:\*\* $PERSONA_NAME/g" "$SOUL_FILE"
    sed -i "s/\*\*Role:\*\* Senior Backend Engineer/\*\*Role:\*\* $PERSONA_NAME/g" "$SOUL_FILE"
    sed -i "s/Worker Node - DEVPUS/Worker Node - $WORKER_ROLE/g" "$SOUL_FILE"
    sed -i "s/Worker Node - BACKEND/Worker Node - $(echo $WORKER_ROLE | tr '[:lower:]' '[:upper:]')/g" "$SOUL_FILE"
    chown openclaw:openclaw "$SOUL_FILE"
fi

# Update USER.md with worker identity
if [ -f "$USER_FILE" ]; then
    sed -i "s/ocl-worker-[a-z]*-[0-9]*-[a-z]*/$WORKER_NAME/g" "$USER_FILE"
    sed -i "s/Worker ID:.*/Worker ID: $WORKER_ID/g" "$USER_FILE"
    sed -i "s/Worker Name:.*/Worker Name: $WORKER_NAME/g" "$USER_FILE"
    sed -i "s/\*\*Worker ID:\*\* [0-9]*/\*\*Worker ID:\*\* $WORKER_ID/g" "$USER_FILE"
    chown openclaw:openclaw "$USER_FILE"
fi

# Mark as configured
echo "$INSTANCE_NAME" > "$MARKER_FILE"
chown openclaw:openclaw "$MARKER_FILE"

# Restart OpenClaw to pick up changes
echo "Restarting OpenClaw service..."
systemctl restart openclaw

echo "Worker configuration complete for $INSTANCE_NAME"
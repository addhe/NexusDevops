#!/bin/bash
# IrishEcho MasterControl Startup Script
# Sets up identity files based on GCP metadata

set -e

OPENCLAW_USER="{{ openclaw_user | default('mastercontrol') }}"
WORKSPACE="/home/${OPENCLAW_USER}/.openclaw/workspace"

# Get instance metadata
INSTANCE_NAME=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
ZONE=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google" | sed 's|.*/||')

# Parse instance name
# Format: mastercontrol-{id}-{env}
IFS='-' read -r PREFIX ID ENV <<< "$INSTANCE_NAME"

echo "=== IrishEcho MasterControl Startup ==="
echo "Instance: $INSTANCE_NAME"
echo "Zone: $ZONE"
echo "ID: $ID"
echo "Environment: $ENV"

# Update IDENTITY.md
cat > "${WORKSPACE}/IDENTITY.md" << EOF
# IDENTITY.md - Who Am I?

- **Name:** IrishEcho
- **Full Name:** IrishEcho MasterControl
- **Type:** Control Plane Bot
- **Creature:** Digital infrastructure controller
- **Vibe:** Precise, efficient, authoritative — control tower operator
- **Emoji:** 🎛️
- **Avatar:** Control panel / infrastructure icon
- **Instance:** ${INSTANCE_NAME}
- **Zone:** ${ZONE}
- **Environment:** ${ENV}

## Access Model

**DM ONLY** - No group access
**OWNER ONLY** - Om Awan (@BroAwn, ID: 319535690)

---

*This identity is locked. Modifications require explicit file edit by owner.*
*Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

# Update MEMORY.md with instance info
if [ -f "${WORKSPACE}/MEMORY.md" ]; then
    sed -i "s/Instance:.*/Instance: ${INSTANCE_NAME}/" "${WORKSPACE}/MEMORY.md"
    sed -i "s/Zone:.*/Zone: ${ZONE}/" "${WORKSPACE}/MEMORY.md"
    sed -i "s/Environment:.*/Environment: ${ENV}/" "${WORKSPACE}/MEMORY.md"
fi

echo "=== Identity updated successfully ==="
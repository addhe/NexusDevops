# Multi-Bot Setup Guide

This guide explains how to run multiple OpenClaw bots on a single VM.

## Overview

Each bot requires:
- Separate config file (`openclaw.json`)
- Separate workspace directory
- Separate state directory
- Separate systemd service

## Directory Structure

```
~/.openclaw/                    # Default OpenClaw (Bot 1)
├── openclaw.json
├── workspace/
│   ├── SOUL.md
│   ├── USER.md
│   └── ...
└── state/

~/.openclaw-bot2/               # Bot 2
├── openclaw.json
├── workspace/
│   ├── SOUL.md
│   ├── USER.md
│   └── ...
└── state/
```

## Configuration

### Bot 1 (Default) - Port 8080

```bash
# Systemd service: openclaw-gateway.service
# Config: ~/.openclaw/openclaw.json
# Workspace: ~/.openclaw/workspace/
# State: ~/.openclaw/ (default)
```

### Bot 2 - Port 8081

```bash
# Systemd service: nexusbyte-gateway.service
# Config: ~/.openclaw-nexusbyte/openclaw.json
# Workspace: ~/.openclaw-nexusbyte/workspace/
# State: ~/.openclaw-nexusbyte/state/
```

## Systemd Service Template

Create `~/.config/systemd/user/bot2-gateway.service`:

```ini
[Unit]
Description=Bot2 Gateway (v2026.5.12)
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/node /usr/lib/node_modules/openclaw/dist/index.js gateway --port 8081
WorkingDirectory=/home/openclaw/.openclaw-bot2/workspace
Environment="OPENCLAW_CONFIG_PATH=/home/openclaw/.openclaw-bot2/openclaw.json"
Environment="OPENCLAW_STATE_DIR=/home/openclaw/.openclaw-bot2/state"
Environment="OLLAMA_API_KEY=your_api_key"
Environment="OLLAMA_HOST=https://ollama.com"
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
```

## Commands

```bash
# Enable and start
systemctl --user daemon-reload
systemctl --user enable bot2-gateway.service
systemctl --user start bot2-gateway.service

# View logs
journalctl --user -u bot2-gateway.service -f

# Check status
systemctl --user status bot2-gateway.service
```

## Bot Identity

Each bot needs its own persona files in its workspace:

- `SOUL.md` - Core identity and personality
- `USER.md` - Owner information
- `IDENTITY.md` - Technical identity
- `MEMORY.md` - Context and preferences

## Telegram Configuration

Each bot needs its own Telegram bot token from @BotFather:

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "YOUR_BOT_TOKEN",
      "allowFrom": [123456789],
      "dmPolicy": "open",
      "groupPolicy": "open",
      "groups": {
        "-100123456789": {
          "enabled": true,
          "requireMention": false
        }
      }
    }
  }
}
```

## Port Allocation

| Service | Default Port |
|---------|-------------|
| Gateway | 8080 (bot 1), 8081 (bot 2), etc. |
| Browser Control | 8082 (bot 1), 8083 (bot 2), etc. |

## Resource Considerations

Each OpenClaw instance uses:
- ~200-400MB RAM
- ~1GB disk for state/logs
- Minimal CPU when idle

Plan VM resources accordingly.

## Troubleshooting

### Bot has wrong identity

1. Check `OPENCLAW_STATE_DIR` is set correctly
2. Verify `SOUL.md` exists in workspace
3. Clear sessions: `rm -rf ~/.openclaw-bot2/state/agents/main/sessions`
4. Restart service

### Bot not responding to DM

1. Check `dmPolicy` is set to `open` or `pairing`
2. Verify user ID in `allowFrom`
3. Check logs for Telegram API errors

### Port conflicts

Each bot must use a unique port. Check with:
```bash
ss -tlnp | grep node
```

---

**Last Updated:** 2026-05-16
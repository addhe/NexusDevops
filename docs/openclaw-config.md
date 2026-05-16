# OpenClaw Configuration Guide

## Worker-Specific Configuration

Each OpenClaw worker has its own `openclaw.json` config file at `~/.openclaw/openclaw.json`.

### Configuration Structure

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "YOUR_BOT_TOKEN",
      "allowFrom": [],
      "groupAllowFrom": [],
      "groups": {
        "-YOUR_GROUP_ID": {
          "enabled": true,
          "requireMention": false
        }
      }
    }
  },
  "gateway": {
    "bind": "lan",
    "port": 8080,
    "auth": {
      "mode": "token",
      "token": "YOUR_GATEWAY_TOKEN"
    },
    "mode": "local"
  },
  "commands": {
    "ownerAllowFrom": [
      "telegram:YOUR_TELEGRAM_ID"
    ]
  },
  "agents": {
    "defaults": {
      "agentRuntime": { "id": "openclaw" },
      "model": { "primary": "ollama/glm-5" }
    }
  },
  "env": {
    "vars": {
      "OLLAMA_API_KEY": "YOUR_OLLAMA_API_KEY",
      "OLLAMA_HOST": "https://ollama.com"
    }
  },
  "models": {
    "providers": {
      "ollama": {
        "baseUrl": "https://ollama.com",
        "api": "ollama",
        "models": [
          {
            "id": "glm-5",
            "name": "GLM-5",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 131072,
            "maxTokens": 1310720
          }
        ]
      }
    }
  }
}
```

## Environment Variables (Systemd)

For Ollama API key, use systemd environment override:

```bash
mkdir -p ~/.config/systemd/user/openclaw-gateway.service.d
cat > ~/.config/systemd/user/openclaw-gateway.service.d/environment.conf << 'EOF'
[Service]
Environment="OLLAMA_API_KEY=your-api-key-here"
Environment="OLLAMA_HOST=https://ollama.com"
EOF
systemctl --user daemon-reload
systemctl --user restart openclaw-gateway
```

## Key Configuration Paths

| Path | Description |
|------|-------------|
| `channels.telegram.botToken` | Telegram bot token from @BotFather |
| `channels.telegram.groups` | Group access config (object keyed by group ID) |
| `commands.ownerAllowFrom` | Owner Telegram IDs for admin commands |
| `agents.defaults.model.primary` | Model ID (e.g., `ollama/glm-5`) |
| `env.vars.OLLAMA_API_KEY` | Ollama API key (use systemd env instead) |
| `env.vars.OLLAMA_HOST` | Ollama API host URL |
| `models.providers.ollama` | Ollama provider registration |

## Group Access Configuration

To enable bot access in a Telegram group:

1. Get the group ID (negative number for supergroups)
2. Add to `channels.telegram.groups`:

```bash
openclaw config set channels.telegram.groups.'-GROUP_ID'.enabled true
openclaw config set channels.telegram.groups.'-GROUP_ID'.requireMention false
openclaw gateway restart
```

## Security Notes

- **Never commit secrets to repo** - Use Ansible vault or environment variables
- **Bot tokens** - Should be injected during deployment
- **API keys** - Use systemd environment files, not config
- **Gateway tokens** - Generate with `openclaw gateway token`
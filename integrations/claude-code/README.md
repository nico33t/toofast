# nt-deploy — Claude Code plugin (+ MCP)

Run nt-deploy straight from Claude Code: deploy, roll back, audit and scaffold sites
through natural language, backed by an MCP server.

## What you get

- **MCP server** (`mcp/nt_mcp.py`, stdlib only) exposing tools: `nt_deploy`, `nt_rollback`,
  `nt_snapshots`, `nt_audit`, `nt_check`, `nt_clients`, `nt_projects`, `nt_list`, `nt_create`.
- **Slash commands**: `/deploy`, `/rollback`, `/audit`.

Requires the nt-deploy CLI installed (`nt-deploy.sh` on PATH or `~/.nt-tools/nt-deploy.sh`).

## Install

Add to your Claude Code settings (or use it as a plugin directory):

```json
{
  "mcpServers": {
    "nt-deploy": { "command": "python3", "args": ["/absolute/path/to/integrations/claude-code/mcp/nt_mcp.py"] }
  }
}
```

The server runs `nt-deploy.sh` with a strict, no-shell argument allowlist (same security
posture as the GUI). Destructive tools (`nt_rollback`) run non-interactively, so review
before confirming in chat.

## Try it

> "Deploy the `dist` folder to client **acme** and give me the URL."
> "Audit acme on mobile and tell me what to fix."
> "Roll acme back to the previous version."

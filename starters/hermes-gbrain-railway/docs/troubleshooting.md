# Troubleshooting

## Slack Stops Responding After MCP Reload

Inspect runtime processes and look for more than one `gbrain serve`. Multiple GBrain servers usually mean one process owns the PGLite lock while another is blocked.

## PGLite Lock Timeout

Symptom:

```text
GBrain: Timed out waiting for PGLite lock.
```

If the lock references a dead process, remove only the lock directory. If the lock holder is a live `gbrain serve`, stop the owning gateway or process first.

## GBrain MCP Cannot Find A Page That CLI Can Read

Likely causes:

- MCP `gbrain serve` is reading a different source.
- A stale `gbrain serve` process is holding the lock.
- A previous reload left multiple MCP servers alive.
- The gateway needs a fresh session.

If no custom source exists, do not add a source override.

## Invalid Tool Schema For `extract_facts`

Keep `extract_facts` excluded from the GBrain MCP tool list.

## Model Regression

Expected setup: `gpt-5.5`, provider `openai-codex`, base URL `https://chatgpt.com/backend-api/codex`.

If Slack shows `Provider: auto`, `/new` reports a larger non-Codex context window, or `/reload-mcp` says `No MCP servers connected`, inspect `/data/.hermes/config.yaml`. The admin server must preserve the full Hermes config and must not replace it with a minimal `provider: auto` file.

Required config anchors:

```yaml
model:
  default: gpt-5.5
  provider: openai-codex
  base_url: https://chatgpt.com/backend-api/codex

mcp_servers:
  gbrain:
    command: /data/.hermes/bin/gbrain-mcp-server
```

Restore from the newest timestamped backup when available, then restart the gateway cleanly. The correct Slack state is `gpt-5.5` on `openai-codex` with GBrain MCP connected.

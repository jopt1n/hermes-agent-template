# Hermes + GBrain Railway Runbook

Use this package to prepare a new Railway volume at `/data` for Hermes, Slack, and GBrain.

Run `scripts/bootstrap-volume.sh`, complete `hermes login openai-codex`, start the gateway, run `/new` in Slack, and ask Hermes to read GBrain slug `policies/memory-policy`.

Golden paths:

- `/data/.hermes`
- `/data/.hermes/config.yaml`
- `/data/.hermes/SOUL.md`
- `/data/gbrain`
- `/data/brain`
- `/data/.gbrain/brain.pglite`
- `/data/.hermes/bin/gbrain-mcp-server`

PGLite allows one active GBrain process. Stop the Hermes gateway before CLI GBrain work, confirm `gbrain serve` is gone, run maintenance, then restart the gateway.

Before risky changes, back up Hermes config, SOUL, the brain repo, and the PGLite DB.

The admin server must preserve `/data/.hermes/config.yaml`. If `/new` shows `Provider: auto` or `/reload-mcp` reports no MCP servers, check whether the file was overwritten and restore the OpenAI Codex model block plus `mcp_servers.gbrain` before restarting the gateway.

# Hermes + GBrain Railway Starter

Reusable starter package for a Railway-hosted Hermes Agent with Slack, OpenAI Codex OAuth, and GBrain MCP backed by a persistent `/data` volume.

## Architecture

```text
Railway service
├── /data
│   ├── .hermes
│   │   ├── config.yaml
│   │   ├── SOUL.md
│   │   ├── bin/gbrain-mcp-server
│   │   ├── logs
│   │   └── sessions
│   ├── gbrain
│   ├── brain
│   │   └── policies/memory-policy.md
│   └── .gbrain/brain.pglite
└── Hermes gateway
```

## Captured Baseline

- Railway volume mount: `/data`
- Hermes home: `/data/.hermes`
- GBrain software repo: `/data/gbrain`
- Brain markdown repo: `/data/brain`
- GBrain local DB: `/data/.gbrain/brain.pglite`
- GBrain upstream: `https://github.com/garrytan/gbrain.git`
- Known-good GBrain commit when captured: `71ed8d0`
- Hermes model: `gpt-5.5`
- Hermes provider: `openai-codex`
- Hermes Codex base URL: `https://chatgpt.com/backend-api/codex`
- Slack gateway as primary control surface

## Included Files

- `templates/hermes/runtime.example`
- `templates/hermes/config.yaml.template`
- `templates/hermes/SOUL.md.template`
- `templates/brain/policies/memory-policy.md`
- `bin/gbrain-mcp-server`
- `scripts/bootstrap-volume.sh`
- `scripts/create-hermes-agent.sh`
- `scripts/generate-agent-env.sh`
- `scripts/gbrain-maintenance.sh`
- `scripts/health-check.sh`
- `docs/create-new-agent.md`
- `docs/runbook.md`
- `docs/troubleshooting.md`
- `docs/privacy.md`
- `examples/new-agent.env.example`
- `skills/create-hermes-agent/SKILL.md`

## Quick Start

For a guided duplicate-agent workflow, start with:

```bash
bash starters/hermes-gbrain-railway/scripts/create-hermes-agent.sh --interactive --dry-run
```

Then apply only after reviewing the dry run:

```bash
bash starters/hermes-gbrain-railway/scripts/create-hermes-agent.sh --interactive --yes
```

See `docs/create-new-agent.md` for the full guided flow.

1. Deploy this repo to a new Railway service.
2. Attach a persistent volume mounted at `/data`.
3. Fill Railway service variables from `templates/hermes/runtime.example`.
4. SSH into the Railway service.
5. Run:

```bash
export HOME=/data
export HERMES_HOME=/data/.hermes
export BUN_INSTALL=/data/.bun
export PATH="/data/.bun/bin:$PATH"

bash starters/hermes-gbrain-railway/scripts/bootstrap-volume.sh
```

6. Authenticate Hermes with OpenAI Codex OAuth:

```bash
hermes login openai-codex
```

7. Configure Slack credentials for the new app.
8. Start or restart the gateway.
9. In Slack, run `/new`, then test GBrain MCP with:

```text
call the GBrain MCP get_page tool with slug "policies/memory-policy". Return only the slug, title, and first heading. Do not search. Do not create a new page.
```

Expected result:

```text
slug: policies/memory-policy
title: Memory Policy
first heading: Memory Policy
```

Note: the committed MCP wrapper assumes runtime values are supplied by Railway service variables. If you store runtime values only in a file on the Railway volume, adapt the wrapper on the live service to load that file before `gbrain serve`.

## PGLite Operational Rule

This starter uses local PGLite by default. PGLite allows only one active GBrain process at a time.

Do not run CLI `gbrain` maintenance while MCP `gbrain serve` is active. For maintenance:

1. Stop the Hermes gateway.
2. Confirm no `gbrain serve` process is running.
3. Run CLI GBrain work.
4. Restart the Hermes gateway.
5. Reload MCP and start a fresh Slack session if needed.

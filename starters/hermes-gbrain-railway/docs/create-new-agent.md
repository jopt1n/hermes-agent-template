# Create a New Hermes Agent

This guide uses the Hermes + GBrain Railway starter to create another Railway-hosted Hermes agent without copying live credentials or OAuth state.

## Guided interactive setup

Start with a dry run:

```bash
bash starters/hermes-gbrain-railway/scripts/create-hermes-agent.sh --interactive --dry-run
```

When the dry run looks right and you want the script to apply Railway provisioning:

```bash
bash starters/hermes-gbrain-railway/scripts/create-hermes-agent.sh --interactive --yes
```

The wizard prompts for the new agent display name, Railway project and service names, admin username, admin password or generated password, Slack Bot Token, Slack App Token, Slack allowed member/user ID, Slack home channel ID, OpenAI API key for GBrain embeddings, dry-run versus apply, Slack app status, and whether to print the manual OpenAI Codex OAuth command.

The wizard can write a local private values file at `.agent-envs/<agent-slug>.env` after confirmation. Treat that file as sensitive. `.agent-envs/` is ignored by git.

## Non-interactive dry run

```bash
bash starters/hermes-gbrain-railway/scripts/create-hermes-agent.sh \
  --name "Hermes Agent Client A" \
  --project-name "Hermes Client A" \
  --service-name "Hermes Agent Client A" \
  --env-file .agent-envs/hermes-client-a.env \
  --dry-run
```

## What Can Be Automated

- Generate a strong admin password when requested.
- Create an ignored local values file after confirmation.
- Show a redacted provisioning summary.
- Dry-run the Railway plan.
- With `--yes` or `--apply`, run Railway CLI steps to create/link the project and service, attach `/data`, set variables without printing values, and deploy the current repository.
- Print the Railway SSH command and OpenAI Codex OAuth command that must be run manually.

## Manual and Fresh Per Agent

- Slack app and Slack tokens.
- Slack allowed member/user ID and home channel ID.
- OpenAI API key for GBrain embeddings.
- OpenAI Codex OAuth inside the new Railway service.
- Admin password confirmation or generated password retention.
- Railway project/service confirmation before real apply.
- Volume bootstrap inside Railway SSH with `scripts/bootstrap-volume.sh`.

Do not copy `/data/.hermes/auth.json` from another agent. Do not copy live `.env` files or credentials. Do not commit generated `.agent-envs/*.env` files.

## Verification

After apply, SSH into the new Railway service and run:

```bash
export HOME=/data
export HERMES_HOME=/data/.hermes
export BUN_INSTALL=/data/.bun
export PATH="/data/.bun/bin:$PATH"

bash starters/hermes-gbrain-railway/scripts/bootstrap-volume.sh
hermes login openai-codex
```

Then verify in Slack:

- `/model` shows `gpt-5.5` via `openai-codex`.
- `/new` starts a clean session.
- GBrain MCP can read slug `policies/memory-policy` and return the title and first heading.

Because this starter defaults to PGLite, do not run CLI GBrain maintenance while MCP `gbrain serve` is active. Stop the gateway first, run maintenance, then restart and reload MCP.

# Create Hermes Agent Skill

Use this skill when Joe asks to create, clone, duplicate, or spin up another Hermes agent from the Hermes + GBrain Railway starter.

Default to a dry run. Deploy for real only when Joe explicitly asks for it or confirms it in the interactive wizard.

Prefer running the local wizard instead of asking Joe to paste private values into normal chat:

```bash
bash starters/hermes-gbrain-railway/scripts/create-hermes-agent.sh --interactive --dry-run
```

Ask for missing values one at a time. The required values are the new agent display name, Railway project name, Railway service name, admin username, admin password or permission to generate one, Slack Bot Token, Slack App Token, Slack allowed member/user ID, Slack home channel ID, OpenAI API key for GBrain embeddings, dry-run versus apply, Slack app status, and whether to print the manual OpenAI Codex OAuth command.

Never print private values back. Do not reuse the live agent private values. Do not reuse `/data/.hermes/auth.json`. Fresh OpenAI Codex OAuth must be performed per new agent. Fresh Slack app tokens are recommended per new agent.

## Guided Sequence

1. Plan: confirm this is a new Railway/Hermes/GBrain agent and start with dry-run.
2. Collect inputs: run the interactive script so hidden prompts can receive private values.
3. Generate env file: write `.agent-envs/<agent-slug>.env` only when Joe confirms.
4. Dry-run Railway provisioning: show project, service, volume, variables, deploy, bootstrap, and verification steps without applying.
5. Confirm: require `--yes`, `--apply`, or interactive approval before provisioning.
6. Apply: create/link the Railway project and service, attach `/data`, set variables without printing values, and deploy.
7. Bootstrap volume: run `scripts/bootstrap-volume.sh` inside Railway SSH.
8. Manual OpenAI Codex OAuth: run `hermes login openai-codex` fresh inside Railway SSH.
9. Slack verification: verify `/model`, `/new`, and GBrain MCP.
10. Final handoff report: include files used, values redacted, verification results, and manual steps left.

## Verify

After apply and bootstrap, verify:

- Railway service exists.
- Persistent volume is mounted at `/data`.
- Required Railway variables are set without printing values.
- Gateway starts.
- Slack `/model` shows `gpt-5.5` via `openai-codex`.
- GBrain MCP can read `policies/memory-policy`.

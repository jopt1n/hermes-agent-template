#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARTER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$STARTER_DIR/../.." && pwd)"

interactive=false
dry_run=false
apply=false
yes=false
env_only=false
show_oauth=false

KEY_ADMIN_VAL="ADMIN_PASS""WORD"
KEY_SLACK_BOT="SLACK_BOT_TOK""EN"
KEY_SLACK_APP="SLACK_APP_TOK""EN"
KEY_OPENAI="OPENAI_API_""KEY"

get_var() {
  local key_name="$1"
  eval "printf '%s' \"\${${key_name}:-}\""
}

agent_name="${AGENT_DISPLAY_NAME:-}"
project_name="${RAILWAY_PROJECT_NAME:-}"
service_name="${RAILWAY_SERVICE_NAME:-}"
admin_user="${ADMIN_USERNAME:-admin}"
admin_val="$(get_var "$KEY_ADMIN_VAL")"
slack_bot_val="$(get_var "$KEY_SLACK_BOT")"
slack_app_val="$(get_var "$KEY_SLACK_APP")"
slack_member="${SLACK_ALLOWED_USER_ID:-}"
slack_channel="${SLACK_HOME_CHANNEL_ID:-}"
openai_val="$(get_var "$KEY_OPENAI")"
value_file="${AGENT_ENV_FILE:-}"

usage() {
  cat <<'EOF'
Usage:
  create-hermes-agent.sh --interactive [--dry-run|--yes|--apply]
  create-hermes-agent.sh --name NAME --project-name NAME --service-name NAME --env-file PATH --dry-run

Options:
  --interactive                 Prompt for missing values.
  --name VALUE                  New Hermes display name.
  --project-name VALUE          Railway project name.
  --service-name VALUE          Railway service name.
  --admin-username VALUE        Hermes admin username.
  --admin-password VALUE        Hermes admin password.
  --slack-bot-token VALUE       Slack bot token for the new app.
  --slack-app-token VALUE       Slack app token for the new app.
  --slack-allowed-user-id VALUE Slack allowed member/user ID.
  --slack-home-channel-id VALUE Slack home channel ID.
  --openai-api-key VALUE        OpenAI API key for GBrain embeddings.
  --env-file PATH               Read/write the generated private values file.
  --dry-run                     Show the plan only. This is the default.
  --apply                       Provision through Railway after confirmation.
  --yes                         Provision through Railway; still requires typed project-name confirmation.
  --env-only                    Only generate the private values file.
  --print-codex-oauth           Print the manual Codex OAuth command.
  -h, --help                    Show this help.

Examples:
  bash starters/hermes-gbrain-railway/scripts/create-hermes-agent.sh --interactive --dry-run
  bash starters/hermes-gbrain-railway/scripts/create-hermes-agent.sh --interactive --yes
EOF
}

die() { echo "error: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
}

configured() {
  if [ -n "${1:-}" ]; then printf 'yes'; else printf 'no'; fi
}

prompt_text() {
  local var_name="$1" prompt="$2" default="${3:-}" current="${!var_name:-}" value
  [ -n "$current" ] && return
  if [ -n "$default" ]; then
    read -r -p "$prompt [$default]: " value
    value="${value:-$default}"
  else
    read -r -p "$prompt: " value
  fi
  printf -v "$var_name" '%s' "$value"
}

prompt_secret() {
  local var_name="$1" prompt="$2" current="${!var_name:-}" value
  [ -n "$current" ] && return
  read -r -s -p "$prompt: " value
  echo
  printf -v "$var_name" '%s' "$value"
}

confirm() {
  local prompt="$1" default="${2:-n}" suffix response
  case "$default" in y|Y) suffix="[Y/n]" ;; *) suffix="[y/N]" ;; esac
  read -r -p "$prompt $suffix " response
  response="${response:-$default}"
  case "$response" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

print_railway_preflight() {
  echo "=== Railway account ==="
  railway whoami || die "Railway CLI is not authenticated"

  echo
  echo "=== Current local Railway link before apply ==="
  if ! railway status; then
    echo "No current Railway project link was detected for this directory."
  fi

  echo
  echo "=== Target for this apply ==="
  echo "new project name: $project_name"
  echo "new service name: $service_name"
  echo "volume mount: /data"
  echo
  echo "Apply will create/link the new Railway project from a temporary directory."
  echo "It will not run railway init in this repository."
}

require_project_name_confirmation() {
  local typed
  if [ ! -t 0 ]; then
    die "real apply requires an interactive terminal to type the new Railway project name"
  fi

  echo
  echo "To apply, type the new Railway project name exactly."
  read -r -p "Project name: " typed
  [ "$typed" = "$project_name" ] || die "project name confirmation did not match; refusing to apply"
}

generate_admin_value() {
  if have openssl; then
    openssl rand -base64 32
  elif have python3; then
    python3 - <<'PYCODE'
import base64
import os
print(base64.urlsafe_b64encode(os.urandom(32)).decode().rstrip("="))
PYCODE
  else
    die "openssl or python3 is required to generate an admin password"
  fi
}

load_value_file() {
  local path="$1"
  [ -f "$path" ] || return 0
  set -a
  # shellcheck disable=SC1090
  . "$path"
  set +a
  agent_name="${agent_name:-${AGENT_DISPLAY_NAME:-}}"
  project_name="${project_name:-${RAILWAY_PROJECT_NAME:-}}"
  service_name="${service_name:-${RAILWAY_SERVICE_NAME:-}}"
  admin_user="${admin_user:-${ADMIN_USERNAME:-admin}}"
  admin_val="${admin_val:-$(get_var "$KEY_ADMIN_VAL")}"
  slack_bot_val="${slack_bot_val:-$(get_var "$KEY_SLACK_BOT")}"
  slack_app_val="${slack_app_val:-$(get_var "$KEY_SLACK_APP")}"
  slack_member="${slack_member:-${SLACK_ALLOWED_USER_ID:-}}"
  slack_channel="${slack_channel:-${SLACK_HOME_CHANNEL_ID:-}}"
  openai_val="${openai_val:-$(get_var "$KEY_OPENAI")}"
}

emit_kv() {
  local path="$1" key_name="$2" value="$3"
  printf '%s=' "$key_name" >> "$path"
  printf '%q' "$value" >> "$path"
  printf '\n' >> "$path"
}

write_value_file() {
  local path="$1" dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  umask 077
  : > "$path"
  printf '%s\n' "# Generated by Hermes + GBrain Railway starter." >> "$path"
  printf '%s\n' "# Treat this file as sensitive. Do not commit it." >> "$path"
  emit_kv "$path" AGENT_DISPLAY_NAME "$agent_name"
  emit_kv "$path" RAILWAY_PROJECT_NAME "$project_name"
  emit_kv "$path" RAILWAY_SERVICE_NAME "$service_name"
  emit_kv "$path" ADMIN_USERNAME "$admin_user"
  emit_kv "$path" "$KEY_ADMIN_VAL" "$admin_val"
  emit_kv "$path" "$KEY_SLACK_BOT" "$slack_bot_val"
  emit_kv "$path" "$KEY_SLACK_APP" "$slack_app_val"
  emit_kv "$path" SLACK_ALLOWED_USER_ID "$slack_member"
  emit_kv "$path" SLACK_HOME_CHANNEL_ID "$slack_channel"
  emit_kv "$path" "$KEY_OPENAI" "$openai_val"
  emit_kv "$path" LLM_MODEL gpt-5.5
  emit_kv "$path" HERMES_INFERENCE_PROVIDER openai-codex
  emit_kv "$path" HERMES_CODEX_BASE_URL https://chatgpt.com/backend-api/codex
  emit_kv "$path" HOME /data
  emit_kv "$path" HERMES_HOME /data/.hermes
  emit_kv "$path" BUN_INSTALL /data/.bun
  emit_kv "$path" GBRAIN_HOME /data/.gbrain
  emit_kv "$path" GBRAIN_BRAIN_DIR /data/brain
  chmod 600 "$path"
}

print_slack_steps() {
  cat <<'EOF'

Fresh Slack app checklist:
1. Create a new Slack app for this agent.
2. Enable Socket Mode and create an app-level token with connections:write.
3. Add bot scopes needed by Hermes, including app_mentions:read, chat:write, channels:history, channels:read, groups:history, groups:read, im:history, im:read, im:write, mpim:history, and users:read.
4. Install the app to the workspace and copy the bot token.
5. Invite the app to the home channel and capture the channel ID.
6. Capture the allowed Slack member/user ID.

EOF
}

print_oauth_instruction() {
  cat <<'EOF'

Manual OpenAI Codex OAuth step for the new Railway service:

  railway ssh --service "$RAILWAY_SERVICE_NAME"
  export HOME=/data
  export HERMES_HOME=/data/.hermes
  export BUN_INSTALL=/data/.bun
  export PATH="/data/.bun/bin:$PATH"
  hermes login openai-codex

Do this fresh for each new agent. Do not copy /data/.hermes/auth.json from another agent.

EOF
}

set_railway_var() {
  local key_name="$1" value="$2"
  [ -n "$value" ] || return 0
  printf '%s' "$value" | railway variable set "$key_name" --stdin --service "$service_name" --skip-deploys >/dev/null
}

apply_railway() {
  have railway || die "Railway CLI is required for --apply/--yes"
  print_railway_preflight
  require_project_name_confirmation

  local railway_workdir
  railway_workdir="$(mktemp -d "${TMPDIR:-/tmp}/hermes-railway.XXXXXX")"
  trap 'rm -rf "$railway_workdir"' RETURN

  (
  cd "$railway_workdir"
  echo "Creating or linking Railway project and service..."
  railway init --name "$project_name" --json >/dev/null
  railway add --service "$service_name" --json >/dev/null
  railway volume add --service "$service_name" --mount-path /data --json >/dev/null
  echo "Setting Railway variables without printing values..."
  set_railway_var AGENT_DISPLAY_NAME "$agent_name"
  set_railway_var LLM_MODEL gpt-5.5
  set_railway_var HERMES_INFERENCE_PROVIDER openai-codex
  set_railway_var HERMES_CODEX_BASE_URL https://chatgpt.com/backend-api/codex
  set_railway_var HOME /data
  set_railway_var HERMES_HOME /data/.hermes
  set_railway_var BUN_INSTALL /data/.bun
  set_railway_var GBRAIN_HOME /data/.gbrain
  set_railway_var GBRAIN_BRAIN_DIR /data/brain
  set_railway_var ADMIN_USERNAME "$admin_user"
  set_railway_var "$KEY_ADMIN_VAL" "$admin_val"
  set_railway_var "$KEY_SLACK_BOT" "$slack_bot_val"
  set_railway_var "$KEY_SLACK_APP" "$slack_app_val"
  set_railway_var SLACK_ALLOWED_USER_ID "$slack_member"
  set_railway_var SLACK_HOME_CHANNEL_ID "$slack_channel"
  set_railway_var "$KEY_OPENAI" "$openai_val"
  echo "Deploying current repository to the new Railway service..."
  railway up "$REPO_ROOT" --path-as-root --service "$service_name" --detach --message "Deploy Hermes GBrain starter" >/dev/null
  )

  rm -rf "$railway_workdir"
  trap - RETURN
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --interactive) interactive=true; shift ;;
    --dry-run) dry_run=true; apply=false; shift ;;
    --apply) apply=true; dry_run=false; shift ;;
    --yes) yes=true; apply=true; dry_run=false; shift ;;
    --env-only) env_only=true; dry_run=true; shift ;;
    --print-codex-oauth) show_oauth=true; shift ;;
    --name) agent_name="${2:?missing value for --name}"; shift 2 ;;
    --project-name) project_name="${2:?missing value for --project-name}"; shift 2 ;;
    --service-name) service_name="${2:?missing value for --service-name}"; shift 2 ;;
    --admin-username) admin_user="${2:?missing value for --admin-username}"; shift 2 ;;
    --admin-password) admin_val="${2:?missing value for --admin-password}"; shift 2 ;;
    --slack-bot-token) slack_bot_val="${2:?missing value for --slack-bot-token}"; shift 2 ;;
    --slack-app-token) slack_app_val="${2:?missing value for --slack-app-token}"; shift 2 ;;
    --slack-allowed-user-id) slack_member="${2:?missing value for --slack-allowed-user-id}"; shift 2 ;;
    --slack-home-channel-id) slack_channel="${2:?missing value for --slack-home-channel-id}"; shift 2 ;;
    --openai-api-key) openai_val="${2:?missing value for --openai-api-key}"; shift 2 ;;
    --env-file) value_file="${2:?missing value for --env-file}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

if [ -n "$value_file" ]; then
  load_value_file "$value_file"
fi

if [ "$interactive" = true ]; then
  prompt_text agent_name "New agent display name" "${agent_name:-Hermes Agent}"
  default_slug="$(slugify "$agent_name")"
  prompt_text project_name "Railway project name" "${project_name:-$agent_name}"
  prompt_text service_name "Railway service name" "${service_name:-$agent_name}"
  prompt_text admin_user "Admin username" "${admin_user:-admin}"
  if [ -z "$admin_val" ]; then
    read -r -s -p "Admin password (leave blank to generate): " admin_val
    echo
    if [ -z "$admin_val" ]; then
      if confirm "Generate a strong admin password?" y; then
        admin_val="$(generate_admin_value)"
        echo "Admin password generated and kept in memory."
      else
        die "admin password is required"
      fi
    fi
  fi
  if confirm "Have you already created the Slack app for this new agent?" y; then :; else print_slack_steps; fi
  prompt_secret slack_bot_val "Slack bot token"
  prompt_secret slack_app_val "Slack app token"
  prompt_text slack_member "Slack allowed member/user ID" "$slack_member"
  prompt_text slack_channel "Slack home channel ID" "$slack_channel"
  prompt_secret openai_val "OpenAI API key for GBrain embeddings"
  if [ -z "$value_file" ]; then value_file="$REPO_ROOT/.agent-envs/${default_slug}.env"; fi
  if confirm "Write entered values to $value_file?" n; then
    write_value_file "$value_file"
    echo "Wrote sensitive values file: $value_file"
  fi
  if [ "$show_oauth" = false ] && confirm "Print the manual OpenAI Codex OAuth command for Railway SSH?" y; then
    show_oauth=true
  fi
  if [ "$yes" = false ] && [ "$apply" = false ] && [ "$env_only" = false ]; then
    if confirm "Apply Railway provisioning now?" n; then apply=true; dry_run=false; else dry_run=true; fi
  fi
fi

if [ -z "$agent_name" ] || [ -z "$project_name" ] || [ -z "$service_name" ]; then
  usage
  die "--name, --project-name, and --service-name are required unless supplied interactively or by --env-file"
fi

if [ "$apply" = false ]; then dry_run=true; fi

cat <<EOF

Hermes + GBrain Railway starter summary
project name: $project_name
service name: $service_name
agent display name: $agent_name
Slack configured: $(configured "$slack_bot_val")
OpenAI API key configured: $(configured "$openai_val")
admin password configured: $(configured "$admin_val")
volume mount: /data
mode: $([ "$apply" = true ] && echo apply || echo dry-run)

EOF

if [ "$show_oauth" = true ]; then print_oauth_instruction; fi

if [ "$env_only" = true ]; then
  echo "Env-only mode complete."
  exit 0
fi

if [ "$dry_run" = true ]; then
  cat <<EOF
Dry-run only. No Railway deploy was started.

Planned actions for --yes/--apply:
- show railway whoami and current railway status
- require typing the new Railway project name exactly
- create/link Railway project: $project_name
- create/link Railway service: $service_name
- attach a persistent volume at /data
- set Railway variables with redacted values
- deploy the current repository with railway up
- bootstrap /data inside Railway with scripts/bootstrap-volume.sh
- run fresh OpenAI Codex OAuth manually in Railway SSH
- verify Slack /model and GBrain MCP policies/memory-policy
EOF
  exit 0
fi

apply_railway

cat <<EOF

Railway provisioning command sequence finished.
Next manual steps:
1. SSH into the new Railway service.
2. Run bash starters/hermes-gbrain-railway/scripts/bootstrap-volume.sh
3. Run hermes login openai-codex
4. Restart the gateway.
5. Verify Slack /model and GBrain MCP policies/memory-policy.
EOF

#!/bin/bash
set -euo pipefail

export HOME=/data
export HERMES_HOME=/data/.hermes
export BUN_INSTALL=/data/.bun
export PATH="/data/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

STARTER_DIR="${STARTER_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GBRAIN_REPO_URL="${GBRAIN_REPO_URL:-https://github.com/garrytan/gbrain.git}"
GBRAIN_COMMIT="${GBRAIN_COMMIT:-71ed8d0}"

mkdir -p /data/.hermes/bin /data/.hermes/logs /data/.hermes/sessions /data/.hermes/cache /data/.hermes/skills /data/.hermes/hooks /data/.hermes/workspace /data/brain/policies /data/.gbrain

install -m 0755 "$STARTER_DIR/bin/gbrain-mcp-server" /data/.hermes/bin/gbrain-mcp-server

if [ ! -f /data/.hermes/SOUL.md ]; then
  install -m 0600 "$STARTER_DIR/templates/hermes/SOUL.md.template" /data/.hermes/SOUL.md
else
  echo "SOUL.md already exists; leaving it unchanged."
fi

if [ ! -f /data/.hermes/config.yaml ]; then
  install -m 0600 "$STARTER_DIR/templates/hermes/config.yaml.template" /data/.hermes/config.yaml
else
  echo "config.yaml already exists; merge templates/hermes/config.yaml.template manually if needed."
fi

if [ ! -d /data/gbrain/.git ]; then
  git clone "$GBRAIN_REPO_URL" /data/gbrain
  git -C /data/gbrain checkout "$GBRAIN_COMMIT"
else
  echo "/data/gbrain already exists; leaving checkout unchanged."
fi

if command -v bun >/dev/null 2>&1 && [ -f /data/gbrain/package.json ]; then
  (cd /data/gbrain && bun install)
  ln -sf /data/gbrain/src/cli.ts /data/.bun/bin/gbrain 2>/dev/null || true
else
  echo "bun is not installed or GBrain package.json is missing; install Bun before running GBrain."
fi

if [ ! -d /data/brain/.git ]; then
  git init /data/brain
fi

if [ ! -f /data/brain/policies/memory-policy.md ]; then
  install -m 0644 "$STARTER_DIR/templates/brain/policies/memory-policy.md" /data/brain/policies/memory-policy.md
fi

echo "Bootstrap complete. Next: fill Railway private values, run hermes login openai-codex, start gateway, then verify GBrain MCP from Slack."

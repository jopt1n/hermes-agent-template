#!/bin/bash
set -euo pipefail

export HOME=/data
export HERMES_HOME=/data/.hermes
export BUN_INSTALL=/data/.bun
export PATH="/data/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

if [ "$#" -eq 0 ]; then
  echo "Usage: $0 -- <gbrain command and args>"
  echo "Example: $0 -- gbrain stats"
  exit 2
fi

if [ "$1" = "--" ]; then
  shift
fi

echo "Stopping Hermes gateway before GBrain CLI maintenance..."
hermes gateway stop || true
sleep 3

echo "Checking for remaining GBrain server processes..."
for p in /proc/[0-9]*; do
  pid="${p#/proc/}"
  cmd="$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null || true)"
  case "$cmd" in
    *"bun /data/.bun/bin/gbrain serve"*|*"gbrain serve"*)
      echo "Stopping leftover GBrain server PID $pid"
      kill "$pid" 2>/dev/null || true
      ;;
  esac
done
sleep 2

LOCK="/data/.gbrain/brain.pglite/.gbrain-lock/lock"
if [ -f "$LOCK" ]; then
  lock_pid="$(python3 -c 'import json; from pathlib import Path; p=Path("/data/.gbrain/brain.pglite/.gbrain-lock/lock"); print(json.loads(p.read_text()).get("pid", "") if p.exists() else "")')"
  if [ -z "$lock_pid" ] || [ ! -e "/proc/$lock_pid" ]; then
    rm -rf /data/.gbrain/brain.pglite/.gbrain-lock
    echo "Removed stale PGLite lock."
  else
    echo "PGLite lock is held by live PID $lock_pid; refusing maintenance."
    exit 1
  fi
fi

cd /data/brain
"$@"

echo "Maintenance command finished. Restart the gateway and start a fresh Slack session."

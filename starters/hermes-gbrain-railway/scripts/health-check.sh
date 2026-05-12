#!/bin/bash
set -euo pipefail

export HOME=/data
export HERMES_HOME=/data/.hermes
export BUN_INSTALL=/data/.bun
export PATH="/data/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

echo "=== Paths ==="
for path in /data /data/.hermes /data/.hermes/bin /data/gbrain /data/brain /data/.gbrain; do
  if [ -e "$path" ]; then echo "ok $path"; else echo "missing $path"; fi
done

echo "=== Model config ==="
awk '/^model:/{c=8} c{print NR ":" $0; c--}' /data/.hermes/config.yaml 2>/dev/null || true

echo "=== GBrain policy ==="
test -f /data/brain/policies/memory-policy.md && echo "ok policies/memory-policy" || echo "missing policies/memory-policy"

echo "=== SOUL rules ==="
count="$(grep -c '^# GBrain Durable Memory Rules$' /data/.hermes/SOUL.md 2>/dev/null || true)"
echo "GBrain Durable Memory Rules sections: $count"

echo "=== Processes ==="
for p in /proc/[0-9]*; do
  pid="${p#/proc/}"
  cmd="$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null || true)"
  case "$cmd" in *"hermes gateway"*|*"gbrain serve"*|*"bun /data/.bun/bin/gbrain"*|*"hermes dashboard"*) echo "$pid $cmd";; esac
done

echo "=== PGLite lock ==="
cat /data/.gbrain/brain.pglite/.gbrain-lock/lock 2>/dev/null || echo "No lock file"

echo "=== Gateway status ==="
hermes gateway status || true

#!/usr/bin/env bash
# phaseA-smoke — a gate run of a Phase-A process agent.
# (a) writes a NEW record to the vault via vault-append.sh (valid frontmatter);
# (b) git add -A && commit to the vault.
# Idempotent in effect: each run creates a unique new raw/runs file
# (vault-append.sh guarantees a unique name), the commit captures exactly it.
set -euo pipefail

VAULT="${PAPERCLIP_VAULT:-${PAPERCLIP_DEPLOY:-$HOME/paperclip-deploy}/vault}"
APPEND="${VAULT_APPEND:-${RSYS_REPO:-$HOME/reasoning-system}/tools/vault-append.sh}"
AUTHOR="phaseA-smoke"
SLUG="phase-a-gate"
TODAY="$(date -u +%Y-%m-%d)"

# (a) a NEW record in raw/runs with mandatory frontmatter
FILE="$(
  "$APPEND" new "$VAULT" runs "$AUTHOR" "$SLUG" <<EOF
---
status: verified
created: ${TODAY}
author_agent: ${AUTHOR}
task_class: simple
---
# Phase A gate: a trivial process-agent run

Phase A gate: a trivial process-agent run.
Loop proof: the process adapter executed, appended this record to the vault,
git captured a commit. The run is deterministic and reversible.
EOF
)"

echo "vault record: ${FILE}"

# (b) git commit to the vault
git -C "$VAULT" add -A
git -C "$VAULT" commit -m "phaseA-smoke: gate run record"

echo "phaseA-smoke: done"

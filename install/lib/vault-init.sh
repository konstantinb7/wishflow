#!/usr/bin/env bash
# vault-init — lays the vault skeleton into the target deploy and initializes git.
# Idempotent: does NOT clobber an existing vault (only creates what's missing).
#
# Usage: vault-init.sh [<vault-dir>]
#   vault-dir defaults to $PAPERCLIP_VAULT or ${PAPERCLIP_DEPLOY:-$HOME/paperclip-deploy}/vault
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SKELETON="$REPO_ROOT/system/vault-skeleton"
VAULT="${1:-${PAPERCLIP_VAULT:-${PAPERCLIP_DEPLOY:-$HOME/paperclip-deploy}/vault}}"

[ -d "$SKELETON" ] || { echo "skeleton not found: $SKELETON" >&2; exit 1; }

echo "vault-init: target = $VAULT"
mkdir -p "$VAULT"

# Copy the skeleton WITHOUT overwriting existing files (idempotent).
# cp -rn: no-clobber — never overwrite an existing vault file. NO fallback to clobbering cp:
# a previous `|| cp -r` defeated the very idempotency this script advertises.
cp -rn "$SKELETON/." "$VAULT/"

# the vault's .gitignore from the template (if not yet present)
[ -f "$VAULT/.gitignore" ] || cp "$SKELETON/gitignore.template" "$VAULT/.gitignore"
rm -f "$VAULT/gitignore.template"

# git init (a separate vault repository) + the first commit
if [ ! -d "$VAULT/.git" ]; then
  git -C "$VAULT" init -q
  # FORCE vault-local identity (override any global) — otherwise vault commits inherit a foreign
  # global git identity. Per-agent authorship (git blame) is set in the commit scripts via
  # GIT_AUTHOR_NAME=<agent-id> (Principle 9, Learning Loop).
  git -C "$VAULT" config user.name  "vault-compiler"
  git -C "$VAULT" config user.email "vault@local"
  git -C "$VAULT" add -A
  git -C "$VAULT" commit -q -m "vault: initial skeleton (SCHEMA, agents, raw/, compiled/)"
  echo "vault-init: git initialized, first commit done"
else
  echo "vault-init: git already present, skeleton ensured (no clobber)"
fi

echo "vault-init: done -> $VAULT"

#!/usr/bin/env bash
# Objective Verifier — a verdict by a REAL run (Principle 3). No model.
# A TOOL: the command is passed by the orchestrator (not an issue assignment). Emits a structured
# pass/fail from exitCode + writes the outcome to the vault. ALWAYS exit 0 (the verdict is DATA, not the
# process exit code; a nonzero code from a process agent = adapter_failed → recovery, which we don't want).
#
# Command (in priority order): $VERIFY_CMD (env)  →  arguments ("$@").
# Optional issue-status set: if PAPERCLIP_API_URL + PAPERCLIP_TASK_ID + PAPERCLIP_API_KEY are set,
# posts the verdict as a comment and sets the status (done on pass / blocked on fail). Best-effort.
# NB: we don't use set -u — we read optional env.
set -o pipefail

VAULT="${PAPERCLIP_VAULT:-${PAPERCLIP_DEPLOY:-$HOME/paperclip-deploy}/vault}"
APPEND="${VAULT_APPEND:-${RSYS_REPO:-$HOME/reasoning-system}/tools/vault-append.sh}"
AUTHOR="objective-verifier"
TODAY="$(date -u +%Y-%m-%d)"
API="${PAPERCLIP_API_URL:-}"; ISSUE="${PAPERCLIP_TASK_ID:-}"; KEY="${PAPERCLIP_API_KEY:-}"

CMD="${VERIFY_CMD:-$*}"
if [ -z "$CMD" ]; then
  echo '{"pass":false,"error":"no command: set the VERIFY_CMD env or an argument"}'
  exit 0
fi

# --- the real run ---
OUT="$(mktemp)"; ERR="$(mktemp)"
bash -c "$CMD" >"$OUT" 2>"$ERR"; EXIT=$?
STDOUT_EXC="$(head -c 1500 "$OUT")"; STDERR_EXC="$(head -c 1500 "$ERR")"; rm -f "$OUT" "$ERR"

# ISTATUS: done = approve the review stage (the runtime moves on); in_progress = return to the builder
# (the native execution-policy remediation loop — reassign to the executor). NOT blocked: blocked does not
# trigger a remediation reassign.
if [ "$EXIT" -eq 0 ]; then PASS=true; OSTATUS=verified; ISTATUS=done
else PASS=false; OSTATUS=falsified; ISTATUS=in_progress; fi

# --- outcome to the vault (the fast Learning Loop loop) ---
OUTCOME_FILE="$(
  "$APPEND" new "$VAULT" outcomes "$AUTHOR" "verify-${EXIT}" <<EOF
---
status: ${OSTATUS}
created: ${TODAY}
author_agent: ${AUTHOR}
task_class: first_class
outcome_ref:
supersedes:
predicts: ${VERIFY_PREDICTION:-}
---
# Outcome: a real run, exitCode=${EXIT}

Command: \`${CMD}\`
Verdict: $([ "$PASS" = true ] && echo "PASS (test passed)" || echo "FAIL (test failed)").
stdout: ${STDOUT_EXC}
stderr: ${STDERR_EXC}
EOF
)"
git -C "$VAULT" add -A >/dev/null 2>&1
GIT_AUTHOR_NAME="$AUTHOR" GIT_COMMITTER_NAME="$AUTHOR" \
  git -C "$VAULT" commit -q -m "verify(${AUTHOR}): outcome exit=${EXIT} -> ${OSTATUS}" >/dev/null 2>&1 || true

VERDICT="$(printf '{"pass":%s,"exitCode":%d,"status":"%s","outcome_file":"%s"}' \
  "$PASS" "$EXIT" "$OSTATUS" "$OUTCOME_FILE")"

# --- optional verdict/status write to the issue (if the orchestrator gave API context) ---
if [ -n "$API" ] && [ -n "$ISSUE" ] && [ -n "$KEY" ]; then
  curl -s -X POST "$API/issues/$ISSUE/comments" -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KEY" -d "{\"body\":\"Objective Verifier verdict: $VERDICT\"}" >/dev/null 2>&1 || true
  curl -s -X PATCH "$API/issues/$ISSUE" -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KEY" -d "{\"status\":\"$ISTATUS\"}" >/dev/null 2>&1 || true
fi

echo "$VERDICT"
exit 0

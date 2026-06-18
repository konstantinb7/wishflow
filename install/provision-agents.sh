#!/usr/bin/env bash
# provision-agents — hires the role core into the reasoning-system company via REST (idempotent).
# Resolves the reportsTo org chart by name. Each role's prompt is built by tools/build-prompt.mjs --hire.
#
# Usage: provision-agents.sh [API_BASE] [--rehire]
#   API_BASE defaults to http://localhost:3100
#   --rehire: delete the company's existing agents and hire fresh from config-as-code
#             (a clean apply of a changed org structure; used while there is no valuable agent state).
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
API="http://localhost:3100"; REHIRE=0
for a in "$@"; do case "$a" in --rehire) REHIRE=1;; http*) API="$a";; esac; done
COMPANY_NAME="reasoning-system"

j() { node -e "$1" "${@:2}"; }

# --- find the company by name ---
CID="$(curl -s "$API/api/companies" | node -e '
  const cs=JSON.parse(require("fs").readFileSync(0));
  const c=cs.find(x=>x.name===process.argv[1]); process.stdout.write(c?c.id:"");
' "$COMPANY_NAME")"
[ -n "$CID" ] || { echo "company '$COMPANY_NAME' not found — create it first" >&2; exit 1; }
echo "company $COMPANY_NAME = $CID"

# Note: Paperclip won't delete agents with history (runs/comments) (DELETE 500).
# So provision is an idempotent UPSERT: existing ones are resynced in place, new ones hired (see hire_one).

# --- map of existing agents name->id ---
declare -A AGENT_ID
while IFS=$'\t' read -r nm id; do
  # guard: a role name is letters/hyphen without spaces (protects the assoc-array key from a junk line)
  [[ "$nm" =~ ^[A-Za-z][A-Za-z0-9_-]*$ ]] && [ -n "$id" ] && AGENT_ID["$nm"]="$id"
done < <(
  curl -s "$API/api/companies/$CID/agents" | node -e '
    const a=JSON.parse(require("fs").readFileSync(0));
    for(const x of a) if(x&&x.name&&x.id) process.stdout.write(`${x.name}\t${x.id}\n`);
  '
)
echo "existing agents: ${!AGENT_ID[*]:-<none>}"

# --- hire order: managers before subordinates (CEO → COO/OrgArchitect → Archivist → executors) ---
ORDER=(ceo-orchestrator coo-orchestrator org-architect archivist \
  spec-writer spec-reviewer \
  divergent-generator domain-specialist adversary steelman-critic consistency-checker \
  rubric-auditor objective-verifier synthesizer vault-compiler prompt-evaluator)

# idempotent upsert: exists → resync (PUT prompt + PATCH reportsTo); not → hire.
hire_one() {
  local file="$REPO/system/prompts/$1.md"
  local hire name rtName rtId body resp aid
  hire="$(node "$REPO/tools/build-prompt.mjs" "$file" --hire)" || { echo "build fail $1"; return 1; }
  name="$(echo "$hire" | node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(0)).name)')"
  rtName="$(echo "$hire" | node -e 'const h=JSON.parse(require("fs").readFileSync(0));process.stdout.write(h.reportsToName||"")')"
  rtId=""
  if [ -n "$rtName" ]; then
    rtId="${AGENT_ID[$rtName]:-}"
    [ -n "$rtId" ] || echo "WARN $name: reportsTo '$rtName' not yet provisioned — leaving null"
  fi

  if [ -n "${AGENT_ID[$name]:-}" ]; then
    # --- RESYNC an existing one: update the prompt file + reportsTo + adapterConfig (model/env) ---
    aid="${AGENT_ID[$name]}"
    echo "$hire" | node -e '
      const h=JSON.parse(require("fs").readFileSync(0));
      process.stdout.write(JSON.stringify({path:"AGENTS.md",content:h.instructionsBundle.files["AGENTS.md"]}));
    ' > /tmp/pc-resync-body.json
    curl -s -X PUT "$API/api/agents/$aid/instructions-bundle/file" -H 'Content-Type: application/json' --data @/tmp/pc-resync-body.json >/dev/null
    patchBody="$(echo "$hire" | node -e '
      const h=JSON.parse(require("fs").readFileSync(0));
      const body = {reportsTo: process.argv[1] ? process.argv[1] : null, adapterConfig: h.adapterConfig};
      process.stdout.write(JSON.stringify(body));
    ' "$rtId")"
    curl -s -X PATCH "$API/api/agents/$aid" -H 'Content-Type: application/json' -d "$patchBody" >/dev/null
    echo "resynced $name ($aid) reportsTo=${rtId:-null}"
    return 0
  fi

  # --- HIRE a new one ---
  body="$(echo "$hire" | SKILL_KEY="${SKILL_KEY:-}" node -e '
    const h=JSON.parse(require("fs").readFileSync(0));
    delete h.reportsToName; delete h._providerKey;
    const rt=process.argv[1]; if(rt) h.reportsTo=rt;
    const sk=process.env.SKILL_KEY; if(sk) h.desiredSkills=[sk];
    process.stdout.write(JSON.stringify(h));
  ' "$rtId")"
  resp="$(curl -s -X POST "$API/api/companies/$CID/agent-hires" -H 'Content-Type: application/json' -d "$body")"
  aid="$(echo "$resp" | node -e 'try{const r=JSON.parse(require("fs").readFileSync(0));process.stdout.write(r.agent?.id||"")}catch{process.stdout.write("")}')"
  if [ -n "$aid" ]; then AGENT_ID["$name"]="$aid"; echo "hired $name -> $aid (reportsTo=${rtId:-null})"
  else echo "HIRE FAIL $name: $(echo "$resp" | head -c 300)"; return 1; fi
}

SKIP_ROLES="${SKIP_ROLES:-}"
rc=0
for r in "${ORDER[@]}"; do
  if [[ " $SKIP_ROLES " =~ " $r " ]]; then
    echo "skip $r (--critic-provider later)"
    continue
  fi
  hire_one "$r" || rc=1
done
echo "=== provision done (rc=$rc) ==="
echo "agents now: ${!AGENT_ID[*]}"

# ── version stamp: record the deployed WishFlow version in the company (visible on the board + queryable via API) ──
VERSION="$(cat "$REPO/VERSION" 2>/dev/null || echo 'dev')"
COMMIT="$(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo 'nogit')"
STAMP="WishFlow v${VERSION} · ${COMMIT} · provisioned $(date -u +%Y-%m-%dT%H:%MZ)"
curl -s -X PATCH "$API/api/companies/$CID" -H 'Content-Type: application/json' \
  -d "{\"description\":\"${STAMP} — reasoning-system control plane\"}" >/dev/null \
  && echo "version stamped on company: $STAMP" || echo "WARN: version stamp failed"

exit $rc

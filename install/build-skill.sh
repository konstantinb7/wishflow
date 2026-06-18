#!/usr/bin/env bash
# build-skill — assemble the Claude Code intake skill from SKILL.template.md + classification.md + this install's config.
# DRY: the rubric is the SAME _shared/classification.md the COO uses, so the front filter and the system agree.
# Usage: build-skill.sh <API> <COMPANY_ID>
#   SKILL_DIR  (default ~/.claude/skills/wishflow-intake) — where Claude Code looks for skills
#   CONFIG_DIR (default ~/.wishflow)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

API="${1:-http://localhost:3100}"
CID="${2:-}"
SKILL_DIR="${SKILL_DIR:-$HOME/.claude/skills/wishflow-intake}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.wishflow}"
[ -n "$CID" ] || { echo "usage: build-skill.sh <API> <COMPANY_ID>" >&2; exit 2; }

COO_ID="$(curl -s "$API/api/companies/$CID/agents" | node -e '
  const a=JSON.parse(require("fs").readFileSync(0));
  const c=a.find(x=>x.name==="COO"); process.stdout.write(c?c.id:"");')"
[ -n "$COO_ID" ] || { echo "COO agent not found in company $CID" >&2; exit 1; }

COMPANY_URL="$API/companies/$CID"
CONFIG_PATH="$CONFIG_DIR/config.json"

mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_PATH" <<JSON
{ "api": "$API", "companyId": "$CID", "cooAgentId": "$COO_ID", "boardUrl": "$COMPANY_URL" }
JSON

mkdir -p "$SKILL_DIR"
node -e '
  const fs=require("fs");
  let t=fs.readFileSync(process.argv[1],"utf8");
  const repl={
    "{{CLASSIFICATION}}": fs.readFileSync(process.argv[2],"utf8").trim(),
    "{{API}}": process.argv[3], "{{COMPANY_ID}}": process.argv[4], "{{COO_AGENT_ID}}": process.argv[5],
    "{{COMPANY_URL}}": process.argv[6], "{{CONFIG_PATH}}": process.argv[7],
  };
  for (const [k,v] of Object.entries(repl)) t=t.split(k).join(v);
  fs.writeFileSync(process.argv[8], t);
' "$REPO/system/claude-skill/SKILL.template.md" "$REPO/system/prompts/_shared/classification.md" \
  "$API" "$CID" "$COO_ID" "$COMPANY_URL" "$CONFIG_PATH" "$SKILL_DIR/SKILL.md"

echo "skill built: $SKILL_DIR/SKILL.md"
echo "  config:    $CONFIG_PATH"
echo "  (Claude Code will load it from $SKILL_DIR — move it if your skills dir differs)"

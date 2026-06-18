#!/usr/bin/env bash
# build-opencode-skill — assemble the OpenCode intake skill (analog of the Claude Code skill).
# It creates a global instruction file for OpenCode and registers it in ~/.config/opencode/opencode.json.
# DRY: the rubric is the SAME _shared/classification.md the COO uses, so the front filter and the system agree.
#
# Usage: build-opencode-skill.sh <API> <COMPANY_ID>
#   SKILL_DIR  (default ~/.config/opencode) — where the global OpenCode config lives
#   CONFIG_DIR (default ~/.wishflow)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

API="${1:-http://localhost:3100}"
CID="${2:-}"
SKILL_DIR="${SKILL_DIR:-$HOME/.config/opencode}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.wishflow}"
[ -n "$CID" ] || { echo "usage: build-opencode-skill.sh <API> <COMPANY_ID>" >&2; exit 2; }

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
INSTRUCTION_FILE="$SKILL_DIR/wishflow-intake.md"

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
  "$API" "$CID" "$COO_ID" "$COMPANY_URL" "$CONFIG_PATH" "$INSTRUCTION_FILE"

CONFIG_FILE="$SKILL_DIR/opencode.json"
mkdir -p "$SKILL_DIR"
touch "$CONFIG_FILE"

node -e '
  const fs=require("fs");
  const path=process.argv[1];
  const instructionFile=process.argv[2];
  let cfg={};
  try { cfg=JSON.parse(fs.readFileSync(path,"utf8")); } catch {}
  cfg["$schema"]=cfg["$schema"]||"https://opencode.ai/config.json";
  cfg.instructions=cfg.instructions||[];
  const rel=instructionFile;
  if (!cfg.instructions.includes(rel)) cfg.instructions.push(rel);
  fs.writeFileSync(path, JSON.stringify(cfg, null, 2));
' "$CONFIG_FILE" "$INSTRUCTION_FILE"

echo "OpenCode skill built: $INSTRUCTION_FILE"
echo "  config:    $CONFIG_PATH"
echo "  registered in: $CONFIG_FILE"
echo "  (OpenCode will load it from global instructions)"

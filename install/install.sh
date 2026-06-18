#!/usr/bin/env bash
# install.sh — turns a clean Paperclip into our reasoning system (idempotent).
# Works under Claude Code OR OpenCode. Pick the IDE with --ide claude|opencode.
# Order and rationale — docs/setup-runbook.md. The main gate is ONBOARDING (the run-JWT secret):
# without it the LLM agents fall into a re-wake loop (see the runbook, CRITICAL #1).
#
# Usage:
#   install.sh [--ide claude|opencode] [--paperclip-dir DIR] [--api URL]
#              [--instance-env PATH] [--skill SKILL_KEY] [--no-skill]
#              [--critic-provider kimi|opencode|later]
#              [--opencode-model MODEL] [--opencode-critic-model MODEL]
#              [--claude-cli PATH] [--kimi-cli PATH] [--opencode-cli PATH]
#              [--no-start]
# Defaults:
#   IDE=claude  DIR=${PAPERCLIP_DEPLOY:-$HOME/paperclip-deploy}  API=http://localhost:3100
#   INSTANCE_ENV=~/.paperclip/instances/default/.env
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

IDE="${IDE:-claude}"
PAPERCLIP_DIR="${PAPERCLIP_DEPLOY:-$HOME/paperclip-deploy}"
API="http://localhost:3100"
INSTANCE_ENV="${PAPERCLIP_INSTANCE_DIR:-$HOME/.paperclip}/instances/default/.env"
COMPANY_NAME="reasoning-system"
SKILL_KEY=""           # optional paperclip skill key to bind to agents
START_IF_DOWN=1
INHERIT_CREDS=0        # default ISOLATION: agents do NOT inherit the Operator's personal MCP/creds
CREDS_SRC="$HOME/.claude/.credentials.json"  # source of Claude auth for agents (isolated mode)
CRITIC_PROVIDER="${CRITIC_PROVIDER:-kimi}"
OPENCODE_MODEL=""
OPENCODE_CRITIC_MODEL="${OPENCODE_CRITIC_MODEL:-openai/gpt-5.2-pro}"
BUILD_SKILL=1

while [ $# -gt 0 ]; do
  case "$1" in
    --help)
      sed -n '2,14p' "$0" | sed 's/^# //' | sed 's/^#//'
      exit 0;;
    --ide) IDE="$2"; shift 2;;
    --paperclip-dir) PAPERCLIP_DIR="$2"; shift 2;;
    --api) API="$2"; shift 2;;
    --instance-env) INSTANCE_ENV="$2"; shift 2;;
    --skill) SKILL_KEY="$2"; shift 2;;
    --no-skill) BUILD_SKILL=0; shift;;
    --inherit-creds) INHERIT_CREDS=1; shift;;
    --creds-src) CREDS_SRC="$2"; shift 2;;
    --critic-provider) CRITIC_PROVIDER="$2"; shift 2;;
    --opencode-model) OPENCODE_MODEL="$2"; shift 2;;
    --opencode-critic-model) OPENCODE_CRITIC_MODEL="$2"; shift 2;;
    --claude-cli) export CLAUDE_CLI="$2"; shift 2;;
    --kimi-cli) export KIMI_CLI="$2"; shift 2;;
    --opencode-cli) export OPENCODE_CLI="$2"; shift 2;;
    --no-start) START_IF_DOWN=0; shift;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

# canonical env vars for placeholders in models.json / prompts
export PAPERCLIP_DEPLOY="$PAPERCLIP_DIR"
export PAPERCLIP_INSTANCE_DIR="$(dirname "$INSTANCE_ENV" | xargs dirname 2>/dev/null || echo "$HOME/.paperclip")"
export RSYS_REPO="$REPO"
export CLAUDE_CLI="${CLAUDE_CLI:-claude}"
export KIMI_CLI="${KIMI_CLI:-kimi}"
export OPENCODE_CLI="${OPENCODE_CLI:-opencode}"

log() { printf '\n=== %s ===\n' "$*"; }
health() { curl -sf -m 3 "$API/api/health" >/dev/null 2>&1; }
wait_health() { for _ in $(seq 1 "${1:-90}"); do health && return 0; sleep 1; done; return 1; }
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $1" >&2
    return 1
  fi
}

detect_opencode_model() {
  local cfg="${OPENCODE_CONFIG:-$HOME/.config/opencode/opencode.json}"
  [ -f "$cfg" ] || return 0
  node -e 'try{const c=JSON.parse(require("fs").readFileSync(process.argv[1]));console.log(c.model||"")}catch(e){}' "$cfg"
}

# Build a JSON map role->provider. This lets the SAME prompts be hired on claude_local or opencode_local.
build_role_provider_map() {
  local ide="$1" critic="$2"
  local roles=(
    ceo-orchestrator coo-orchestrator org-architect archivist
    spec-writer spec-reviewer divergent-generator domain-specialist
    adversary steelman-critic consistency-checker rubric-auditor
    objective-verifier synthesizer vault-compiler prompt-evaluator
  )
  local builder="claude"
  local cprov="kimi"
  if [ "$ide" = "opencode" ]; then
    builder="opencode"
    case "$critic" in
      kimi) cprov="kimi" ;;
      opencode) cprov="opencode-critic" ;;
      later) cprov="" ;;
      *) echo "unknown critic provider: $critic" >&2; exit 2;;
    esac
  fi
  node -e '
    const roles = process.argv[1].split(" ");
    const builder = process.argv[2];
    const cprov = process.argv[3];
    const map = {};
    for (const r of roles) {
      if (["adversary","steelman-critic","rubric-auditor"].includes(r)) map[r] = cprov || "SKIP";
      else map[r] = builder;
    }
    console.log(JSON.stringify(map));
  ' "${roles[*]}" "$builder" "$cprov"
}

# Validate IDE prerequisites
case "$IDE" in
  claude)
    require_command "${CLAUDE_CLI:-claude}" || { echo "Claude CLI not found. Install Claude Code or set --claude-cli"; exit 1; }
    ;;
  opencode)
    require_command "${OPENCODE_CLI:-opencode}" || { echo "OpenCode CLI not found. Install OpenCode (https://opencode.ai) or set --opencode-cli"; exit 1; }
    if [ -z "$OPENCODE_MODEL" ]; then
      OPENCODE_MODEL="$(detect_opencode_model)"
      if [ -z "$OPENCODE_MODEL" ]; then
        echo "ERROR: OpenCode mode requires a model. Either set it in ~/.config/opencode/opencode.json"
        echo "       or pass --opencode-model provider/model-slug (e.g. anthropic/claude-opus-4-7)" >&2
        exit 1
      fi
      echo "detected OpenCode default model: $OPENCODE_MODEL"
    fi
    export OPENCODE_BUILDER_MODEL="$OPENCODE_MODEL"
    export OPENCODE_CRITIC_MODEL="$OPENCODE_CRITIC_MODEL"
    ;;
  *) echo "unknown IDE: $IDE (use claude or opencode)" >&2; exit 2;;
esac

# Validate critic provider
case "$CRITIC_PROVIDER" in
  kimi|opencode|later) ;;
  *) echo "unknown --critic-provider: $CRITIC_PROVIDER (use kimi, opencode, or later)" >&2; exit 2;;
esac

# Export the provider map so build-prompt.mjs picks per-role adapters.
export ROLE_PROVIDER_MAP="$(build_role_provider_map "$IDE" "$CRITIC_PROVIDER")"
echo "role provider map: $ROLE_PROVIDER_MAP"

# ───────────────────────── Step 0: TOOLSET SCOPE (isolation from personal MCP/creds) ─────────────────────────
log "Step 0: isolate agents' toolset (IDE=$IDE)"
if [ "$IDE" = "claude" ]; then
  if [ "$INHERIT_CREDS" = 1 ]; then
    echo "--inherit-creds: agents use ~/.claude as-is (personal MCP/creds are NOT isolated)"
  else
    SCOPED="$(dirname "$INSTANCE_ENV")/agent-claude"
    mkdir -p "$SCOPED"; chmod 700 "$SCOPED"
    cp "$REPO/system/agent-claude/settings.json" "$SCOPED/settings.json"
    # CREDS — a SYMLINK to the live file (NOT a copy!): the OAuth token refreshes in the source, a copy goes stale → 401.
    if [ -f "$CREDS_SRC" ]; then rm -f "$SCOPED/.credentials.json"; ln -s "$CREDS_SRC" "$SCOPED/.credentials.json";
    else echo "WARNING: no $CREDS_SRC — agents won't be able to authenticate with Claude (set --creds-src or ANTHROPIC_API_KEY)"; fi
    mkdir -p "$(dirname "$INSTANCE_ENV")"
    grep -q '^CLAUDE_CONFIG_DIR=' "$INSTANCE_ENV" 2>/dev/null || printf 'CLAUDE_CONFIG_DIR=%s\n' "$SCOPED" >> "$INSTANCE_ENV"
    echo "isolated: CLAUDE_CONFIG_DIR=$SCOPED (deny mcp__*; web allowed; personal connectors cut off)"
  fi
else
  # OpenCode: give agents a scoped config dir so they don't pick up the Operator's project-level rules/MCP.
  SCOPED="$(dirname "$INSTANCE_ENV")/agent-opencode"
  mkdir -p "$SCOPED"; chmod 700 "$SCOPED"
  cat > "$SCOPED/opencode.json" <<JSON
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "${OPENCODE_BUILDER_MODEL}",
  "instructions": []
}
JSON
  mkdir -p "$(dirname "$INSTANCE_ENV")"
  grep -q '^OPENCODE_CONFIG_DIR=' "$INSTANCE_ENV" 2>/dev/null || printf 'OPENCODE_CONFIG_DIR=%s\n' "$SCOPED" >> "$INSTANCE_ENV"
  grep -q '^OPENCODE_DISABLE_PROJECT_CONFIG=' "$INSTANCE_ENV" 2>/dev/null || printf 'OPENCODE_DISABLE_PROJECT_CONFIG=1\n' >> "$INSTANCE_ENV"
  echo "isolated: OPENCODE_CONFIG_DIR=$SCOPED (empty instructions, project config disabled; global provider auth reused)"
fi

# ───────────────────────── Step 1: ONBOARDING GATE (the run-JWT secret) ─────────────────────────
log "Step 1: onboarding gate (the run-JWT secret)"
if [ -f "$INSTANCE_ENV" ] && grep -q '^PAPERCLIP_AGENT_JWT_SECRET=' "$INSTANCE_ENV"; then
  echo "onboarding already done (PAPERCLIP_AGENT_JWT_SECRET present in $INSTANCE_ENV)"
else
  echo "JWT secret NOT found → running the official onboarding (idempotent, preserves data)"
  ( cd "$PAPERCLIP_DIR" && nohup pnpm paperclipai onboard --yes > /tmp/paperclip-onboard.log 2>&1 & )
  echo "onboarding started (log /tmp/paperclip-onboard.log); waiting for readiness..."
  if ! wait_health 120; then
    echo "ERROR: the stand didn't come up after onboarding. Log:"; tail -15 /tmp/paperclip-onboard.log; exit 1
  fi
  if ! grep -q '^PAPERCLIP_AGENT_JWT_SECRET=' "$INSTANCE_ENV" 2>/dev/null; then
    echo "ERROR: onboarding didn't create PAPERCLIP_AGENT_JWT_SECRET in $INSTANCE_ENV"; exit 1
  fi
  echo "onboarding OK: JWT secret created"
fi

# ───────────────────────── Step 2: the stand responds ─────────────────────────
log "Step 2: the stand responds"
if health; then
  echo "health OK ($API)"
elif [ "$START_IF_DOWN" = 1 ]; then
  echo "the stand isn't responding → starting it (pnpm dev)"
  ( cd "$PAPERCLIP_DIR" && nohup pnpm dev > /tmp/paperclip-dev.log 2>&1 & )
  wait_health 120 || { echo "ERROR: the stand didn't come up. Log:"; tail -15 /tmp/paperclip-dev.log; exit 1; }
  echo "health OK"
else
  echo "ERROR: the stand isn't responding and --no-start. Bring it up (pnpm dev / paperclipai run) and retry."; exit 1
fi

# ───────────────────────── Step 3: vault inside the deploy ─────────────────────────
log "Step 3: vault-init"
PAPERCLIP_VAULT="$PAPERCLIP_DIR/vault" bash "$HERE/lib/vault-init.sh" "$PAPERCLIP_DIR/vault" || exit 1

# ───────────────────────── Step 4: the reasoning-system company ─────────────────────────
log "Step 4: company $COMPANY_NAME"
CID="$(curl -s "$API/api/companies" | node -e '
  const cs=JSON.parse(require("fs").readFileSync(0));
  const c=cs.find(x=>x.name===process.argv[1]); process.stdout.write(c?c.id:"");
' "$COMPANY_NAME")"
if [ -n "$CID" ]; then
  echo "company already exists: $CID"
else
  CID="$(curl -s -X POST "$API/api/companies" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$COMPANY_NAME\",\"description\":\"Isolated reasoning-system loop (separate from operational companies)\"}" \
    | node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(0)).id||""')"
  [ -n "$CID" ] || { echo "ERROR: failed to create the company"; exit 1; }
  echo "created company: $CID"
fi

# ───────────────────────── Step 5: hire the core ─────────────────────────
log "Step 5: provision agents"
SKIP_ROLES=""
if [ "$CRITIC_PROVIDER" = "later" ]; then
  SKIP_ROLES="adversary steelman-critic rubric-auditor"
  echo "WARNING: critic roles skipped (--critic-provider later). Principle 1 is NOT satisfied yet."
  echo "         Re-run install.sh with --critic-provider kimi|opencode when ready."
fi
SKIP_ROLES="$SKIP_ROLES" SKILL_KEY="$SKILL_KEY" bash "$HERE/provision-agents.sh" "$API" || exit 1

# ───────────────────────── Step 6: post-checks ─────────────────────────
log "Step 6: post-checks"
grep -q '^PAPERCLIP_AGENT_JWT_SECRET=' "$INSTANCE_ENV" && echo "✓ JWT secret configured" || { echo "✗ JWT secret MISSING"; exit 1; }
curl -s "$API/api/companies/$CID/agents" | node -e '
  const a=JSON.parse(require("fs").readFileSync(0));
  const ad=n=>{const x=a.find(y=>y.name===n);return x?x.adapterType:"MISSING";},
        id=n=>{const x=a.find(y=>y.name===n);return x?x.id:"";},
        cfg=n=>{const x=a.find(y=>y.name===n);return x?x.adapterConfig:{};};
  const builders=["DivergentGenerator","DomainSpecialist"].map(ad);
  const advs=["Adversary","SteelmanCritic"].map(ad);
  const overlap=builders.filter(x=>advs.includes(x));
  console.log("  agents:",a.length);
  console.log("  builder:",builders.join(","),"| adversary:",advs.join(","));
  if (process.env.SKIP_ROLES) {
    console.log("  ⚠ Principle 1 DEFERRED (critic roles skipped: "+process.env.SKIP_ROLES+")");
    process.exit(0);
  }
  console.log(overlap.length? "  ✗ Principle 1 VIOLATED (shared provider)" : "  ✓ Principle 1: Builder≠Adversary on different providers");
  process.exit(overlap.length?1:0);
' || exit 1

# ───────────────────────── Step 7: IDE intake skill ─────────────────────────
if [ "$BUILD_SKILL" = 1 ]; then
  if [ "$IDE" = "claude" ]; then
    log "Step 7: build the Claude Code intake skill"
    bash "$HERE/build-skill.sh" "$API" "$CID" || echo "WARN: skill build failed (non-fatal); run install/build-skill.sh manually"
  else
    log "Step 7: build the OpenCode intake skill"
    bash "$HERE/build-opencode-skill.sh" "$API" "$CID" || echo "WARN: OpenCode skill build failed (non-fatal); run install/build-opencode-skill.sh manually"
  fi
else
  log "Step 7: skip skill build (--no-skill)"
fi

log "DONE: system installed"
echo
PREFIX="$(curl -s "$API/api/companies/$CID" | node -e 'try{const c=JSON.parse(require("fs").readFileSync(0));process.stdout.write(c.issuePrefix||"")}catch{process.stdout.write("")}')"
echo "  ▶ Open the board directly on reasoning-system:"
echo "      $API/${PREFIX}/dashboard"
echo "    (open this exact URL — it lands on reasoning-system, NOT the org picker / create-org screen)"
echo
echo "  IDE=$IDE  company=$CID  API=$API  vault=$PAPERCLIP_DIR/vault"

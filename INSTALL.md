# INSTALL — one-link bootstrap (Claude Code or OpenCode)

This file is written **for an AI coding agent to execute** (Claude Code or OpenCode), although a human can follow it by hand. Stop and report to the user at any failed gate.

The system is a **control plane** (config-as-code) that runs on **Paperclip** and orchestrates executor agents. Installing it = deploying Paperclip (if absent) + provisioning this repo's roles.

---

## Quick router

- **If you are Claude Code** → follow **Section A** below.
- **If you are OpenCode** → follow **Section B** below.
- **If you are a human** → follow **Section C** below.

In all cases the actual deployment is performed by `install/install.sh` in this repository.

---

## Section A — Instructions for Claude Code

### A0. Environment variables (set these first; everything references them)

| Var | Meaning | Default |
|---|---|---|
| `PAPERCLIP_DEPLOY` | where Paperclip is checked out / deployed | `~/paperclip-deploy` |
| `RSYS_REPO` | this repository on the user's machine | `~/reasoning-system` |
| `PAPERCLIP_INSTANCE_DIR` | Paperclip instance/data dir | `~/.paperclip` |
| `CLAUDE_HOME` | Claude Code config dir | `~/.claude` |
| `KIMI_HOME` | second-provider CLI home (if using Kimi for decorrelation) | `~/.kimi-code` |

Detect/confirm these with the user before proceeding.

### A1. Preflight

- Detect OS and that `node` (≥ 20), `pnpm`, and `git` are available. Missing → tell the user how to install, stop.
- Confirm Claude Code is present (it is — it's running this).
- Check for a **second model provider** (Kimi / Codex / any non-Anthropic CLI). This is **required for real decorrelation** (Builder ≠ Adversary on different providers). If absent: warn the user clearly that the critic side will run on the same family as the builder → **decorrelation is degraded to a single-family run**, and ask whether to proceed or stop to install a second provider.

### A2. Paperclip (the control plane)

- If Paperclip is not already deployed: clone `paperclipai/paperclip` into `PAPERCLIP_DEPLOY`, install dependencies (`pnpm install`), and **run onboarding**: `paperclipai onboard --yes` (or the documented onboard command for the version).
  - **Onboarding is mandatory.** It creates the run-JWT secret. Without it, agents re-run the same task forever (no terminal disposition). Do not skip.
- Record `PAPERCLIP_DEPLOY` and `PAPERCLIP_INSTANCE_DIR`. Start the stand and confirm the health endpoint responds.

### A3. This reasoning system

- Clone this repository into `RSYS_REPO` (if the user pointed you at a raw INSTALL.md, derive the repo from the same origin).
- Export the env vars from step A0 so config placeholders resolve.

### A4. Deploy

Run the installer:

```bash
bash "$RSYS_REPO/install/install.sh"
```

It:

- creates an isolated company for the reasoning system (separate from any operational company);
- provisions the role core: builds each role prompt (`tools/build-prompt.mjs` renders `{{include:...}}` + routes) and hires it as a Paperclip agent with the right model and a **scoped toolset**;
- installs the empty vault skeleton (git-initialized), `system/models.json`, and `system/routing/routes.json`.

**Scope the agent toolset** (critical): deny `mcp__*` and isolate `CLAUDE_CONFIG_DIR` so agents cannot reach the user's external systems/credentials. The installer does this automatically for Claude mode.

### A5. Models (decorrelation)

- Builder/synthesis roles → the strong Anthropic side (Claude).
- Adversary/critic roles → a **different provider** (Kimi / Codex) if available. This is Principle 1 — without it the system is an expensive single-model run.
- If the second provider is a CLI over ACP (e.g., Kimi) and the user's home is **ecryptfs** (encrypted), session filenames overflow the name limit → symlink the ACP session dir to a non-encrypted fs (see `docs/kimi-adapter-setup.md`). Detect with `mount | grep ecryptfs`.

### A6. Smoke check (self-verify — proves it actually works)

Create ONE neutral task via the API and confirm it reaches a terminal state end-to-end. Use the native API, e.g.:

```bash
# create a simple issue assigned to the COO orchestrator, then wake it, then poll
# (use the company id and COO agent id from step A4's output)
curl -s -X POST "$API/api/companies/$CID/issues" -H 'Content-Type: application/json' \
  -d '{"title":"Smoke: add two integers and return the sum","assigneeAgentId":"'$COO'","status":"todo"}'
# wake the COO on the new issue, then poll the issue until status is done (or a valid escalation)
```

**Green = the issue reaches `done` (or correctly escalates).** That proves classification → route → execution → disposition works end to end. If it hangs in `blocked`/`in_progress` and never resolves: onboarding (step A2) or toolset scoping (step A4) is likely the cause — re-check those before anything else.

### A7. Hand off to the user

Report:
- how to open the board: go **directly** to `${API}/companies/${CID}` (the company id from step A4) — this lands on reasoning-system, NOT the org picker / create-org screen;
- how to give a task: create an issue assigned to the **COO**, in natural language — the system classifies and routes it;
- how to watch a run: the issue tree (children = pipeline stages), comments, and documents;
- where things live: roles in `system/prompts/`, model map in `system/models.json`, routes in `system/routing/`.

---

## Section B — Instructions for OpenCode

### B0. Prerequisites

OpenCode mode runs the **builder side through the OpenCode CLI** (`opencode_local` Paperclip adapter). Before proceeding:

1. **OpenCode CLI is installed and authenticated.** Verify with `opencode --version`.
2. **A model is configured** in `~/.config/opencode/opencode.json` (global) or in a project `opencode.json`. The installer reads the default `model` field. Example:
   ```json
   {
     "$schema": "https://opencode.ai/config.json",
     "model": "anthropic/claude-opus-4-7"
   }
   ```
3. **Paperclip prerequisites:** `node` (≥ 20), `pnpm`, `git`, `curl`.

### B1. Environment variables

| Var | Meaning | Default |
|---|---|---|
| `PAPERCLIP_DEPLOY` | where Paperclip is checked out / deployed | `~/paperclip-deploy` |
| `RSYS_REPO` | this repository on the user's machine | `~/reasoning-system` |
| `PAPERCLIP_INSTANCE_DIR` | Paperclip instance/data dir | `~/.paperclip` |
| `OPENCODE_HOME` | OpenCode config dir | `~/.config/opencode` |

### B2. Paperclip

Same as **A2**. Onboarding is mandatory.

### B3. This reasoning system

Same as **A3**. Clone this repo into `RSYS_REPO` and export env vars.

### B4. Deploy with OpenCode

Run the installer in OpenCode mode:

```bash
bash "$RSYS_REPO/install/install.sh" --ide opencode
```

The installer will:

- detect the default model from OpenCode config (or fail with instructions if missing);
- ask you to choose a **critic provider**:
  - **`kimi`** (recommended) — keeps Principle 1 strict: builder via OpenCode, critics via Kimi (a fully separate provider).
  - **`opencode`** — critics also via OpenCode, but on a different backend model family (default `openai/gpt-5.2-pro`). Convenient, but decorrelation is weaker than a separate provider.
  - **`later`** — skip critic roles now; re-run with `--critic-provider kimi|opencode` when ready. The system will warn that Principle 1 is not yet satisfied.
- create a scoped OpenCode config dir for agents so they do not inherit the user's project-level rules/MCP;
- provision all roles, build the OpenCode intake skill, and run post-checks.

To override defaults:

```bash
bash "$RSYS_REPO/install/install.sh" --ide opencode \
  --opencode-model "anthropic/claude-opus-4-7" \
  --critic-provider kimi
```

### B5. Smoke check

Same as **A6**.

### B6. Hand off to the user

Same as **A7**. Additionally:
- The OpenCode intake skill is registered in `~/.config/opencode/opencode.json` under `instructions`.
- The user can say "route this to WishFlow" from any OpenCode session and OpenCode will create the issue on the reasoning-system board.

---

## Section C — Instructions for humans

Follow **Section A** or **B** above, ignoring agent-specific phrasing. The commands are the same. Run `bash "$RSYS_REPO/install/install.sh" --help` for all flags.

---

## Guardrails (from hard-won lessons — do not let the user trip these)

- **Never run `claude -p` loops** against the Anthropic token. Automated hammering of the subscription token risks a permanent account ban. Agents run **only** through Paperclip adapters at a normal cadence.
- **Onboarding is mandatory** (run-JWT) — otherwise agents repeat tasks forever.
- **Scope the agent toolset** — otherwise the orchestrator reaches into the user's external systems. The installer handles this for both Claude and OpenCode modes.
- **Use the second provider sparingly** if it's a metered/quota subscription (e.g., Codex) — it's on the critical path (decorrelation), don't burn it on volume.
- **Do not degrade decorrelation silently.** If no second provider is available, say so clearly before proceeding.

# Kimi Code as the second provider (the adversary side of decorrelation) in Paperclip

Goal: wire **Kimi Code (K2.7)** as a cross-provider critic (Adversary / SteelmanCritic / RubricAuditor),
to restore Principle 1 decorrelation (Builder=claude ≠ critics=a different provider).

Integration is **native via ACP**: kimi-code can do `kimi acp` (an Agent Client Protocol server), and Paperclip has
the `acpx_local` adapter (an ACP client). No code/glue of your own is needed.

## Preconditions
- The `kimi-code` CLI is installed and OAuth-authorized on a **Kimi Code** subscription (NOT a regular chat subscription — membership ≠ API).
  Binary: `<KIMI_HOME>/bin/kimi` (usually `~/.kimi-code/bin/kimi`); creds: `~/.kimi-code/credentials/`;
  the model from `~/.kimi-code/config.toml` (`kimi-code/kimi-for-coding`, base_url `https://api.kimi.com/coding/v1`).
- Check: `<KIMI_HOME>/bin/kimi --version`; modes — `kimi --help` (needs `acp` and `-p`).

## Install steps

### 1. ⚠️ CRITICAL for ENCRYPTED homes (ecryptfs) — otherwise ENAMETOOLONG
acpx_local writes session files with long names (~150 chars: `paperclip%3A<cid>%3A<aid>%3A<issue>%3A<hash>.json`).
**ecryptfs (an encrypted `~`) has a filename limit of ~143 chars** → the adapter crashes with `ENAMETOOLONG`.
Check for encryption: `mount | grep ecryptfs` (if `/home/<user>` is of type `ecryptfs` — yes).

**Fix:** redirect the acpx sessions to a NON-encrypted fs (e.g. `/var/tmp`, ext4) via a symlink — per company:
```bash
CID=<company-id>
ACPXDIR="$PAPERCLIP_INSTANCE_DIR/instances/default/companies/$CID/acpx-local"   # usually ~/.paperclip/...
TARGET="/var/tmp/pc-acpx-$CID"
mkdir -p "$TARGET"
rm -rf "$ACPXDIR" 2>/dev/null; ln -s "$TARGET" "$ACPXDIR"
# check: touch "$ACPXDIR/$(python3 -c 'print("x"*150)')" → should be created
```
(On a NON-encrypted home this step isn't needed.)

### 2. Configure the critics for acpx_local + kimi acp
For each critic (Adversary, SteelmanCritic, RubricAuditor) — PATCH the adapter, preserving the `instructions*` keys:
```bash
API=http://localhost:3100; AGENT=<critic-agent-id>; KIMI=<KIMI_HOME>/bin/kimi
CUR=$(curl -s "$API/api/agents/$AGENT" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin).get('adapterConfig') or {}))")
PATCH=$(python3 -c "import json;c=json.loads('''$CUR''');c['command']='$KIMI';c['args']=['acp'];c['timeoutSec']=600;print(json.dumps({'adapterType':'acpx_local','adapterConfig':c,'replaceAdapterConfig':True}))")
curl -s -X PATCH "$API/api/agents/$AGENT" -H 'Content-Type: application/json' -d "$PATCH"
```
In config-as-code (`system/models.json`) — set the critics' provider to `kimi` (or an equivalent), and `build-prompt`/install
must set adapterType=acpx_local + command/args.

### 3. Restart Paperclip
The stand may cache the adapter config — restart: `cd <PAPERCLIP_DEPLOY> && pnpm dev` (onboarding already done, the JWT is persistent).

### 4. Verify
Create an issue for a critic → wake it → run `succeeded` + the critique in the comments = it works. If `ENAMETOOLONG` → step 1 wasn't done.

## Notes
- `acpx_local` is NOT in Paperclip's user docs (it's in the adapter set) — undocumented but working with the fix above.
- Fallback path (if acpx won't go): the `process` adapter + a wrapper `kimi -p "<prompt>"` (headless), but you lose the session / native bundle delivery.
- The second provider is swappable — kimi (this recipe), codex, or another CLI with a different model family. Different providers on builder vs critics = decorrelation, Principle 1.
- For install-anywhere: include step 1 (the ecryptfs symlink) in the installer as auto-detect (`mount | grep ecryptfs` → symlink).

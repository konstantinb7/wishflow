#!/usr/bin/env bash
# vault-append — safe writing to the vault per Principle 5.
# Parallel agents: only NEW files in raw/ OR a flock-serialized append to log.md.
# Existing pages (compiled/) are edited ONLY by the sequential compiler — NOT this script.
#
# Usage:
#   vault-append.sh new <vault> <subdir> <author> <slug> < content_on_stdin
#       subdir ∈ predictions|outcomes|runs (under raw/). Creates a unique new file, prints the path.
#   vault-append.sh log <vault> <author> <type> <message>
#       a flock-serialized append of one line to log.md.
set -euo pipefail

cmd="${1:-}"; shift || true

case "$cmd" in
  new)
    vault="$1"; subdir="$2"; author="$3"; slug="$4"
    case "$subdir" in predictions|outcomes|runs) ;; *) echo "subdir must be predictions|outcomes|runs" >&2; exit 2;; esac
    dir="$vault/raw/$subdir"; mkdir -p "$dir"
    date="$(date -u +%Y-%m-%d)"
    uid="$(date -u +%H%M%S%N)-$RANDOM"
    file="$dir/${date}-${slug}-${author}-${uid}.md"
    cat > "$file"            # body from stdin (the agent itself puts frontmatter + content)
    echo "$file"
    ;;
  log)
    vault="$1"; author="$2"; type="$3"; shift 3
    msg="$*"
    logf="$vault/log.md"; touch "$logf"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    # flock: one line at a time, no race on the shared file
    exec 9>>"$logf"
    flock 9
    printf '%s | %s | %s | %s\n' "$ts" "$author" "$type" "$msg" >> "$logf"
    flock -u 9
    ;;
  *)
    echo "usage: vault-append.sh new <vault> <predictions|outcomes|runs> <author> <slug>  (body on stdin)" >&2
    echo "       vault-append.sh log <vault> <author> <type> <message>" >&2
    exit 2
    ;;
esac

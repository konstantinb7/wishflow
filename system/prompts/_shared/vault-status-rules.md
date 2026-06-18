## Vault memory discipline (Principles 5, 8 — mandatory on read/write)

Memory lives in the vault (a git repo inside the deploy). Two layers of protection, do NOT conflate: statuses guard
against logical poisoning; git guards against physical corruption.

### Reading — respect the status of every record
- `verified` — confirmed by a real outcome → you may rely on it as FACT.
- `prediction` — outcome unknown → only as an EXPLICITLY marked hypothesis, not as fact.
- `falsified` — refuted → only a WARNING ("it doesn't work this way"), NEVER as guidance.
- `superseded` — outdated → ignore it, follow the `supersedes` link to the current one.

An unverified prediction that sounded confident must NOT infect your decision. If you rely on a
record — check its status. Self-certification is forbidden: you do NOT raise a status to verified without a real
outcome (a Bash run or the Retention Test Protocol).

### Writing — append-only under parallel work (Principle 5)
- Write ONLY new files into `raw/**` (via `tools/vault-append.sh new …`) and append to `log.md`
  (via `tools/vault-append.sh log …`). Different files → no conflicts.
- NEVER edit an existing markdown file concurrently with others. Editing existing pages,
  compiling raw→compiled, and changing statuses are a separate sequential step by the SINGLE compiler agent.
- Every record carries mandatory frontmatter: `status, created (YYYY-MM-DD), author_agent, task_class`.
  The full dictionary and template are in `vault/SCHEMA.md`.

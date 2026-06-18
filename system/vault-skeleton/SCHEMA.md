# SCHEMA — the vault's control file

This is the source of truth for the memory conventions. Every agent that reads or writes the vault
MUST follow the rules below. Implements the spec's Principles 5, 8, 9.

Two layers of memory protection (do NOT conflate):
- **Statuses** (this file) — protection against logical poisoning of context.
- **Git** (the "Git" section) — protection against physical corruption, and reversibility.

---

## Structure

```
vault/
├── SCHEMA.md          # this file — the rules, the status dictionary
├── agents.md          # instructions for the compiler agent (plain language)
├── index.md           # a catalog of compiled pages with one-line annotations
├── log.md             # an append-only chronological log (the fast loop)
├── raw/               # Layer 1 — IMMUTABLE raw records (new files only)
│   ├── predictions/   # what the system predicted
│   ├── outcomes/      # what actually happened
│   └── runs/          # raw run traces + fail reports
└── compiled/          # Layer 2 — compiled lessons (wiki pages)
    ├── agents/        # each agent's reliability by task class
    ├── rubrics/       # which rubrics worked, which let down
    └── signals/       # which signals turned out to be noise
```

`raw/` is written by parallel agents (each a NEW file). `compiled/` is edited ONLY by the
sequential compiler agent. See "Writing rules".

---

## Status dictionary (the mandatory frontmatter field `status`)

| status | meaning | how to read |
|--------|---------|-------------|
| `prediction` | predicted, outcome unknown | NOT a fact; only as an explicit hypothesis |
| `verified` | confirmed by a real outcome (Bash test / Retention) | may be relied on as fact |
| `falsified` | refuted by a real outcome | NEVER as guidance; only a warning. NOT deleted |
| `superseded` | replaced by a newer verified; carries `supersedes` | don't use; follow the link to the replacement |

**Reading rule (also wired into agents.md and every agent's prompt):** when relying on a record,
an agent MUST check the `status`. Rely on it as fact — only `verified`. `prediction` —
only as a marked hypothesis. `falsified` — only as a warning. A status change is
an operation of the sequential compiler, not parallel.

**Self-certification is forbidden:** no agent raises a status to `verified` without a real
outcome (a Bash run or the result of the Retention Test Protocol).

---

## Frontmatter template (minimal, mandatory on every record in raw/ and compiled/)

```yaml
---
status: prediction         # prediction | verified | falsified | superseded
created: 2026-06-14        # YYYY-MM-DD
author_agent: <id>         # who entered it (for git blame and fitness)
task_class: first_class    # simple | first_class | product_convergence | complex_irreversible
outcome_ref:               # a link to the outcome record once it arrives (for prediction)
supersedes:                # a link to the replaced record (only for superseded)
---
```

Always mandatory: `status`, `created`, `author_agent`, `task_class`.
Conditionally mandatory: `supersedes` — if `status: superseded`; `outcome_ref` — for `verified`/`falsified`
it must point at a record in `raw/outcomes/`.

---

## Examples of each status

### prediction (`raw/predictions/`)
```markdown
---
status: prediction
created: 2026-06-14
author_agent: objective-verifier
task_class: first_class
outcome_ref:
supersedes:
---
# Prediction: exploit X will bypass filter Y

Hypothesis: a double-URL-encoded payload will pass WAF rule `R-013`.
Check: a real run of `tests/waf/r013_double_encode.sh`. Awaiting outcome.
Related: [[r013-waf-rule]]
```

### verified (`raw/outcomes/` or compiled)
```markdown
---
status: verified
created: 2026-06-14
author_agent: objective-verifier
task_class: first_class
outcome_ref: raw/outcomes/2026-06-14-r013-double-encode-outcome.md
supersedes:
---
# Confirmed: double URL-encode bypasses R-013

Real run: exitCode=1 (the filter did not fire) → the hypothesis is confirmed.
Closes [[2026-06-14-exploit-x-prediction]].
```

### falsified (NOT deleted — negative knowledge)
```markdown
---
status: falsified
created: 2026-06-14
author_agent: objective-verifier
task_class: first_class
outcome_ref: raw/outcomes/2026-06-14-r013-unicode-outcome.md
supersedes:
---
# Refuted: the unicode bypass of R-013 does NOT work

Real run: exitCode=0 (the filter fired). This way — doesn't work.
Don't use it as a bypass path. Related: [[r013-waf-rule]].
```

### superseded (carries a link to the replacement)
```markdown
---
status: superseded
created: 2026-06-10
author_agent: domain-specialist
task_class: product_convergence
outcome_ref:
supersedes: compiled/signals/rate-limit-estimate-v2.md
---
# [OUTDATED] External-API rate-limit estimate v1

Replaced by newer verified knowledge → [[rate-limit-estimate-v2]].
```

---

## Writing rules (Principle 5 — append-only under parallel work)

1. Parallel agents write ONLY new files into `raw/**` and append to `log.md`.
   Different files → no conflicts by definition.
2. NEVER do several agents edit one markdown file at once.
3. Append to `log.md` — via `tools/vault-append.sh log` (flock-serialization of one line).
4. Compiling `raw/` → `compiled/`, changing statuses, editing existing pages —
   a SEPARATE sequential step by the SINGLE compiler agent (see agents.md). Not concurrent.

### Naming files in raw/ (to avoid name collisions under parallel writes)
`YYYY-MM-DD-<kebab-short-description>-<author_agent>-<short-uid>.md`
Example: `2026-06-14-exploit-x-double-encode-objective-verifier-a1b2.md`.
`<short-uid>` — any unique suffix (timestamp-ns/random), guarantees a per-agent unique file.

---

## Cross-links

Obsidian-compatible `[[wikilinks]]` by the filename without `.md`. Broken links are caught by lint
(the "gaps" category). The link to the replacing knowledge is carried by the `supersedes` field (superseded).

---

## Git (Principle 9)

- The vault is a separate git repository inside the deploy.
- Parallel agents commit only NEW raw/ files — no race (different files).
- ONE sequential process commits/compiles; parallel agents don't commit in a race.
- Auto-compilation (raw/ → compiled/, status changes) — on a separate branch, merged via a lint check.
- A commit after each append and after each compilation. The message carries the agent ID and the operation type.
- No force-push by automation. Secrets/keys are not committed to the repo (`.gitignore`).

---

## Lint

`tools/vault-lint.mjs` checks: the presence/correctness of frontmatter and `status`, the mandatory fields,
`supersedes` on superseded, `outcome_ref` on verified/falsified (warn), broken wikilinks (warn),
the immutability of raw/ (informational). Lint is the gate before merging auto-compilation and must pass
on an empty/starting vault. Run: `node tools/vault-lint.mjs <vault-dir>`.

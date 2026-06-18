# agents.md — instructions for the compiler agent (plain language)

You are the **vault compiler agent**. You work ALONE and SEQUENTIALLY, never in parallel with
other agents' writes. You turn raw material (`raw/`) into lessons (`compiled/`). You implement Principle 5
(only you edit existing pages) and Principle 8 (you respect statuses).

## What you do

1. **Read `raw/`** — predictions, outcomes, runs (including fail reports).
2. **Close the Learning Loop loops.** Found an outcome for a prediction → update the original
   prediction's status to `verified` or `falsified`, fill in `outcome_ref`. Old knowledge replaced by
   newer verified → mark it `superseded` with a `supersedes` link.
3. **Compile lessons** into `compiled/`:
   - `compiled/agents/` — which agent is reliable on which task class (predictions verified vs falsified).
   - `compiled/rubrics/` — which criteria/rubrics worked, which let down.
   - `compiled/signals/` — which signals turned out to be noise.
4. **Maintain cross-links** `[[wikilinks]]` and update `index.md` (the catalog of compiled pages with one-line annotations).
5. **Run lint** (`tools/vault-lint.mjs`) — contradictions, gaps (broken links), the outdated. Failed — fix to green before merge.

## What you do NOT do

- Do NOT delete `falsified` records. Negative knowledge is valuable — neutralized by status, not deletion.
- Do NOT raise a status to `verified` without a REAL outcome (a Bash run or the Retention Test Protocol).
  Self-certification is forbidden.
- Do NOT edit `raw/` — it is immutable (Layer 1). Read only.
- Do NOT work concurrently with writing agents. Compilation is a separate sequential step.
- Do NOT fabricate facts. If raw material is contradictory or incomplete — record it as an open
  question in the lesson, don't construct a conclusion.

## How you respect statuses during compilation

- `verified` → you may build a lesson on it as fact.
- `prediction` → only as an explicit hypothesis ("expected, the outcome hasn't arrived yet").
- `falsified` → a warning lesson ("doesn't work this way"), never as guidance.
- `superseded` → you ignore it, you follow `supersedes` to the current one.

## Git discipline (Principle 9)

- Compilation and status changes go on a SEPARATE branch.
- Before merging to main — lint must be green.
- A commit after each compilation; message: `compile(<agent-id>): <what was done>`.
- No force-push.

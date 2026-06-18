# Roadmap — from a validated prototype to production

Status as of 2026-06-15: **a validated prototype.** End-to-end acceptance (5/5 neutral cases) passed
AUTONOMOUSLY — correct classification, route, objective verification, escalation at both stages (intake questions
and a handoff on the irreversible), with no manual interventions. Run with one command: `node tools/run-acceptance.mjs all`.
**This is not production yet** — below are the priorities by ADDED VALUE.

## Value priorities (do them in this order)

### P0 — a second provider for decorrelation — ✅ CLOSED (2026-06-16)
Decorrelation Builder(claude) ≠ critics on a DIFFERENT provider — that's the WHOLE point of the system ("better than a bare model").
**Closed:** the critics (adversary/steelman/rubric) are wired to **Kimi K2.7** (Moonshot) via `acpx_local`;
Builder/Synthesis on Opus. Different providers → Principle 1 holds. Adversary confirmed by a full E2E. Config —
`system/models.json` (provider `kimi`), the recipe — `docs/kimi-adapter-setup.md`. The second provider is swappable
(kimi / another with a different model family).

### P1 — prove value on REAL tasks (not toys)
So far verified only on luhn-demo (small code functions with an objective test). Needed:
- A real task from the Operator's portfolio (the spec recommends security / red-team with objective verification).
- `product_convergence` (ideation without an oracle — disagreement-as-signal + the Operator's taste): not yet covered.
- Non-code tasks (strategy, texts): generalizability not proven.
- A real codebase larger than luhn-demo (blast radius, dependencies).

### P2 — reliability under load + ops hardening
In one day we caught: a stand crash, a network drop, quota burn, a continuation hang (fixed). For production:
- Dozens of tasks in a row unattended; monitoring/auto-restart of the stand/alerts.
- Real budget guardrails (budgets are currently inert on a $0 subscription; the quota was actually hit in tests).
- Spending discipline (codex sparingly; don't burn by volume).

### P3 — close the self-learning loop + role eval
- The slow Learning Loop (the Operator's Retention Test Protocol — a source/format for the deferred outcome is needed).
- A systematic behavioral eval of all 17 roles (safely, without hammering the token). PromptEvaluator exists, but a
  mass run is deferred. Weakly exercised: the product path, Org Architect, VaultCompiler.

### P4 — speed
The full pipeline is ~15–20 min on a complex task (sequential Opus runs). Reduce it STRUCTURALLY (parallelism where possible,
short routes for the simple), NOT by downgrading the model (Opus is both smarter and faster per the Operator's data).

## TEST priorities (by in-system value)

Tests are durable, in `system/evals/acceptance-cases.json`, run by `tools/run-acceptance.mjs`. The rule: do NOT tell
the system what it should figure out itself (only `task` is passed; `criteria` are for the evaluator). Priority = the risk a test closes.

| Priority | Test | Risk it closes |
|---|---|---|
| **T0 (critical)** | Escalation on the irreversible (handoff) — E2 | the system silently does something destructive/irreversible |
| **T0** | Escalation on under-specification (intake) — E1 | the system guesses the scope and does the wrong thing |
| **T0** | Objective verification by a real run | a boastful "done" hallucination while it's broken |
| **T1 (high)** | "Bare Opus vs the system" comparison (decorrelation catches what one-shot misses) | justifying the cost/time of multi-agent |
| **T1** | Continuation — an autonomous run with no manual nudges | a hang (closed, keep in regression) |
| **T1** | Zone discipline (an agent doesn't reach into others' work) | blurred responsibility, a crooked output |
| **T2 (medium)** | Correctness of classification/route across the 4 classes | wrong processing depth (over/under) |
| **T2** | Idempotency / no duplicate stages | duplicates, partial execution |
| **T2** | Reassembly (bottom-up roll-up) on decomposition | loss of subtask results |
| **T3** | Slow Learning Loop (prediction→outcome→delta→lesson) | the system doesn't improve over time |

**Regression rule:** on ANY change to the system — re-run the acceptance set (T0/T1 must be green).
A new/edited prompt passes PromptEvaluator (statically catches anti-patterns, e.g. the continuation self-block).

## Definition of Production (when to call it production)
P0 closed (a second provider) ∧ P1 (a real portfolio task passed end-to-end with Operator-confirmed
value) ∧ T0/T1 tests green on a stable stand ∧ P2 basic (the stand survives a day of load without manual
intervention). P3/P4 — desirable, not blockers for the first production release.

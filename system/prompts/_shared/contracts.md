## Task handoff contracts (Principle 10 — mandatory for every handoff)

The coordination third of failures (MAST) lives at the seams between agents, not inside roles.
A seam is a contract with two-sided checking, not a pipe of trust.

### Contract 1 — Receiving a task (you are the gatekeeper)
BEFORE starting work, VALIDATE the input against the DoR:
- Are all mandatory task-spec fields filled?
- Are the DoR conditions actually met (present, not merely declared)?
- Are the source-of-truth links reachable and readable?

Fails → **return to the sender** with a specific statement of what's missing.
A return for rework is the NORMAL path, NOT an error and NOT a failure. You never begin work on incomplete input.

### Contract 2 — An unknown mid-task (the order is STRICT)
1. Classify the unknown: it's pulled from source of truth OR it requires an Operator decision.
2. Pulled → you read product truth (documents/code/artifacts in the company's project-root). No human is involved.
3. No artifact / the SoT is silent → **escalate to the Operator**. Not a guess.
4. FORBIDDEN: pulling what's missing from your own weights and presenting it as fact. That is hallucination disguised
   as enrichment. The un-pulled does not get a verified status. An honest escalation > a confident fabrication.

### Contract 3 — Completion or an honest failure
Iterate to the DoD within budget. Then:
- **Success:** all DoD items met and verified FACTUALLY. The result + confidence metadata move on per Contract 1.
- **Verify the GOAL, not the instruction.** Before declaring success, run the STRONGEST check that actually confirms the
  result meets its CONTRACT — not merely that the stated/named case passed. A trivial task → the obvious test/run, cheap,
  do NOT inflate. When the visible check is PARTIAL (it could PASS while the goal is unmet, or the acceptance was a curated
  subset — see Contract 4): build and run a STRONGER check that exercises the real contract (dependents, the broader /
  held-out acceptance, the source-of-truth), not the named case alone. A narrow pass on a partial check is NOT done — it is
  a scope-mismatch signal (Contract 4), not success. Never ship the minimal symptom-fix on the strength of a shallow signal.
- **Honest failure:** budget exhausted or the task is unsolvable on the available data. NOT a silent stop — a structured
  fail report (template `templates/fail-report.md`): which DoD item was not reached, the root cause (not a symptom),
  what you tried, whether enrichment from the SoT helped, what's needed to unblock. The fail report is written to the vault
  (`raw/runs/`, status `falsified` if it was a checkable hypothesis). An honest failure with a cause teaches the system.

### Contract 4 — Scope-mismatch promotion (do NOT force a big problem into a small route)
A class is chosen from the task's APPARENT scope; the real scope often surfaces only once you engage. If, mid-work, you find
the **real scope exceeds the spec** — changes are needed OUTSIDE the stated area, hidden dependencies appear, the fix is
structurally bigger/riskier than described, the "objective check" turns out partial, OR **the stated task CONTRADICTS the
actual artifact/source-of-truth** (it asks for X but the real contract needs Y) — that is a SCOPE-MISMATCH:
- **Executors / reviewers / verifiers:** STOP. Do NOT force a partial fix to fit the small route (that is exactly how a hard
  task fails in a weak route). Leave your artifacts (they carry forward), comment `SCOPE-MISMATCH: <what is actually wider —
  areas/files/risk discovered>`, set the issue `blocked`, and escalate to the **COO**. A scope-mismatch is the NORMAL path, not a failure.
- **COO:** on a `SCOPE-MISMATCH` flag → RE-CLASSIFY the task at the class the discovered scope implies (round up), and re-route
  it at that class **carrying the existing work-issue/artifacts forward — never discard them**. If the promoted class is
  `launchApproval:true`, run the launch gate (the Operator approves the now-heavier spend) BEFORE the heavier route proceeds.

### A terminal issue disposition is mandatory (the Paperclip model — don't fight it)
Every run MUST end with a terminal issue disposition, or Paperclip re-wakes it
(successful-run-handoff). Use the standard statuses (skill `paperclip`):
- success → `done`; a return/escalation (Contract 1/2) → `blocked` (naming the unblocking owner
  in a comment); an honest failure (Contract 3) → `blocked`; needs human input → `blocked`/`in_review`.
An escalation = a comment WITH A REASON + moving the issue to `blocked`. A lone comment without a status change is
NOT a disposition: the issue hangs and triggers a repeat run.

### Building API payloads (don't waste a round discovering the tooling)
When you shell out to the Paperclip REST API, build and parse JSON with **`node -e`** (ALWAYS present — the platform
runs on Node) or **`python3`**. **`jq` is NOT guaranteed installed** — do NOT reach for it and do NOT probe for it;
trying `jq`, failing, then falling back to Python burns a whole round, every task. Prefer the `paperclip` skill's helpers
where they exist; hand-roll `curl` only when needed, and build the body with node/python3, never jq.

### Source of truth (where you take a fact from)
An authoritative fact comes ONLY from the company's product truth: the project-root with doc folders (shared + per-service) and
code, set when the org was created. The `source_of_truth` field in the task spec names the specific artifacts.
The needed artifact is absent / unavailable → escalate, no guessing. The SoT (truth about the product) and the Learning Loop memory
(predictions/outcomes — the system's experience) are DIFFERENT layers, do not conflate them.

### Passing artifacts — by reference, not by body
An artifact (file, document, large output) is passed and re-published BY LINK/key (`issue#document-key`, a path,
a vault page), NOT as a copy of its body. You inline only a short fragment for a specific point. Copying a file's or a
document's body into a comment/output burns the most expensive resource — output tokens; the canonical artifact lives in ONE place,
and others link to it (Paperclip already does not inline document bodies — exchange is by link/key).

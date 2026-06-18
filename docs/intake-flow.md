# Incoming-task flow + the Founder-escalation protocol

Answers "how a task enters and moves through the pipeline, who does what."

## Flow (from Founder to result)

```
[Founder] creates an incoming issue (a natural-language task)
   │
   ▼
[CEO] — receives it (it's the Founder↔C-level interface; human-gate; review-before-launch)
   │   does NOT decompose, does NOT classify itself — passes it down
   ▼
[COO] — working-out (agent-driven):
   │   1. an ATOMICITY check
   │   2. if not atomic → DECOMPOSITION (recursive), and this is interactive:
   │        ├─ a gap is pulled from product truth → [Archivist] (docs/code/artifacts)
   │        └─ a gap is NOT in product truth (scope/decision/taste) → ESCALATE TO THE FOUNDER (see the protocol below)
   │   3. atomic leaves → each into intake:
   ▼
[COO classifies inline: class+mode] → [Spec Writer] → [Spec Reviewer] (a loose spec doesn't pass)
   │
   ▼
[route by class] COO: a builder work-issue + a NATIVE executionPolicy (review stages = the route's reviewers) → the runtime drives the tail
   │
   ▼
[Synthesizer] — assembles subtask results BOTTOM-UP by goal ancestry (parentId), selection not averaging
   │   + 3 confidence-metadata numbers
   ▼
[Handoff gate] — a trigger? → [CEO → Founder] (a visible channel). No → delivery + a prediction to the vault → the Learning Loop
```

Key: **the CEO does no operations** (decomposition → COO, classification → COO inline, truth-finding →
Archivist). The CEO is the strategic seam with the Founder + the human-gate + go/no-go. **The COO classifies each ATOMIC
leaf inline**, not the raw complex task (it decomposes that first).

## The Founder-escalation protocol (two-sided, interactive)

Arises when an agent (most often the COO during decomposition) needs something NOT in product truth: unstated scope,
a product decision, a priority, a taste choice. The order (Contract 2, step 3):

1. The agent has formulated a concrete question (exactly what's unclear and why it blocks). NOT a guess, NOT a fabrication.
2. **Route upward via the CEO** (the CEO is the sole interface to the Founder). The agent does NOT poke the Founder directly;
   escalation goes up the chain (reportsTo) to the CEO.
3. **The CEO puts the question to the Founder on a VISIBLE channel** — a `request_confirmation` / `ask_user_questions` interaction
   on the issue (`POST /api/issues/:id/interactions`), `continuationPolicy: wake_assignee`. It's the Operator's queue,
   not a silent log.
4. **The Founder answers** → the interaction resolves → wakes the executor (`wake_assignee`) → work continues
   with the received input. The Founder's answer becomes part of the source of truth for this task.
5. While there's no answer — the issue is `blocked` (a terminal disposition, not hanging in_progress), the unblocking owner
   is named. No fabrication "while waiting for an answer."

This is symmetric to the Contract 1 gatekeeper, but on the input from a human: the system protects itself from the Founder's
vagueness too, returning a vague/under-specified input for review rather than executing blindly.

## Where this is in code/config
- Flow: the CEO prompt (`ceo-orchestrator.md`), the COO (`coo-orchestrator.md` + `_shared/decomposition.md`).
- Escalation channel: `tools/handoff.mjs` (creates a `request_confirmation`) — the same mechanism for handoff decisions
  and for the Founder's clarifying questions.
- Atomic-leaf route: `system/routing/routes.json` → the COO expands it into a native `executionPolicy` on the work-issue (the runtime drives review/approval + the remediation loop).

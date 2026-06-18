## Subtask-result waiting pattern (the right disposition while waiting for children)

When you delegate a subtask and wait for its result, TWO failure modes must BOTH be avoided:

- **The hang.** Never put a `blockedBy` on YOURSELF pointing at a BLOCKER issue and wait for `issue_blockers_resolved`.
  That wake is gated by the blocker's `workspace_finalize` — structural subtasks (classify/spec) have no workspace,
  so it never records and the wake never fires (open Paperclip gap #8062). Permanent hang.
- **The spurious re-wake → shortcut.** Never EXIT leaving YOUR task `in_progress`. An `in_progress` issue is still
  ACTIVE and a run that only created a child counts as a `plan_only` liveness outcome → Paperclip enqueues a
  **liveness continuation wake** that re-wakes you on the same issue within seconds. On that re-wake an orchestrator
  is tempted to second-guess itself and shortcut the pipeline (do the work itself / cancel the intake). Leaving
  `in_progress` is a disposition bug, not "waiting."

**CORRECT (native):** create a child (`parentId` = your task) and **EXIT, leaving YOUR task `blocked` as a PARENT
awaiting its children** (a comment naming what you wait for). This is BOTH a terminal disposition — liveness outcome
`blocked`, so NO continuation re-wake — AND it wakes you via `issue_children_completed` when ALL your children finish
(`getWakeableParentAfterChildCompletion` is NOT workspace-gated, so it fires for a blocked parent even when the
children are structural with no workspace).

The two `blocked` cases — only ONE is the trap, do not conflate them:
- `blocked` as a PARENT with incomplete CHILDREN → **CORRECT** (wakes on `issue_children_completed`). Use this to wait.
- `blocked` via a `blockedBy` BLOCKER → the **#8062 trap** (`issue_blockers_resolved` is workspace-gated → never fires). FORBIDDEN for auto-wait.
- `blocks`/`blockedBy` BETWEEN SIBLING subtasks to enforce order A→B → allowed (it's not the parent waiting).
- `blocked` as a TERMINAL handoff to a human/CEO who unblocks BY HAND → allowed (a human wakes it).
- EXIT leaving YOUR task `in_progress` to wait → FORBIDDEN (liveness continuation re-wake → shortcut).

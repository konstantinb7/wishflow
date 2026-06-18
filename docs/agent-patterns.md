# Agent patterns — institutionalized orchestration experience (read BEFORE a nontrivial task)

Patterns paid for with real failures. A violation = repeating an already-walked mistake.

## 1. Waiting for a subtask result — do NOT block YOURSELF (else a permanent hang)

**The symptom that bred this:** tasks got stuck dead in `blocked`. The COO delegated an intake subtask (a
Spec), put ITSELF into `blocked` + `blockedBy`, and waited for `issue_blockers_resolved`. The subtask finished — but
the parent NEVER woke. Hours lost on false hypotheses (codex, the verifier, the network) until the root was found.

**Root (confirmed against Paperclip's code + their issues):**
- The `issue_blockers_resolved` wake is **gated** by the blocker's `workspace_finalize=succeeded`. Structural subtasks
  (classification/spec) don't touch code → workspace/finalize = null → the wake does NOT fire.
- Paperclip does NOT auto-unblock a `blocked` ticket when its blockers resolve — that's their **open gap #8062**
  ("auto-flip to `todo` when reassigning a blocked ticket with no active blockedByIssueIds") + #8109. Not done.

**RULE (the native pattern, `heartbeat-protocol.md:71`):** when delegating a subtask and waiting for the result — create a child
(`parentId` = your task) and **EXIT, leaving YOUR task `in_progress`**. Paperclip will wake you via
`issue_children_completed` when ALL children finish (this path is reliable and NOT gated). **NEVER put YOURSELF
into `blocked`/`blockedBy` to wait.**

Allowed `blocked`: between SIBLINGS (order A→B) and as a TERMINAL handoff to a human/CEO (unblocked by hand).
The rule's canon — `system/prompts/_shared/continuation-pattern.md` (included in the orchestrators; checked by PromptEvaluator probe 6).

**Generalized lesson:** Paperclip's core (coordination/wake) is reliable — but IT has unclosed gaps (see their GitHub issues).
Before building workarounds of your own: (1) check whether you're using a broken path where a reliable native one exists;
(2) look at their issues — the bug may be known. Don't block on a symptom, find the root via code/docs/issues.

## 2. Don't reverse-engineer Paperclip, use the native

Agents are forbidden to read Paperclip's source for "how to use it" (remit/policy). The pipeline tail is on the
native `executionPolicy`; the verifier=claude in the workspace; decomposition via `suggest_tasks`. Self-rolled code — only
where there's no native. Details — the session memory and `_shared/zone-discipline.md`.

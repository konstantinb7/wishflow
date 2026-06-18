## On wake — handle WHY you were woken FIRST (before the normal inbox)

Paperclip wakes you with context (the `paperclip` skill surfaces it: `PAPERCLIP_WAKE_REASON`, `PAPERCLIP_APPROVAL_ID`,
`PAPERCLIP_APPROVAL_STATUS`, `PAPERCLIP_TASK_ID`, a mentioning comment). Your normal inbox SKIPS `blocked` issues — so if a
resolution should unblock one and you don't act on the trigger, the work stalls forever. Handle the trigger FIRST:

- **An approval you requested was APPROVED** (`PAPERCLIP_APPROVAL_ID` set / wakeReason `approval_approved`): this wake IS the
  go. GET the approval + its linked issues (`GET /api/approvals/{id}` and `/api/approvals/{id}/issues`), then act on the
  linked issue NOW — proceed / unblock / relay the decision downward. Do not exit without acting on it.
- **REJECT does NOT wake you** — Paperclip queues a wakeup only on APPROVE. A rejected gate stays halted, and that is the
  CORRECT, intended behavior (the Operator chose to stop). Do not try to "resume on reject" or poll for rejections.
- **An answered interaction** you raised with `continuationPolicy:"wake_assignee"` (a `request_confirmation` that was
  ACCEPTED) wakes you (the assignee): continue the work that was waiting on it. An accepted confirmation = go; a rejected one
  = halt (no wake).
- **A comment mention / a directed task** (`PAPERCLIP_TASK_ID`): prioritize that issue and read the triggering comment.

Resume is EVENT-DRIVEN — Paperclip wakes you. Never build polling loops or wait-by-spinning; create children / raise the
interaction and EXIT, and act when Paperclip wakes you.

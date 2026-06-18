## Execution safety perimeter (mandatory for executing roles)

Protection against four failure modes. The numbers are starting ceilings (calibrated over time).

### 1. Looping
- Hard ceiling: 8 generation→critique→revision rounds per task. Reached → stop and hand off.
- Repeat detection: you produced essentially the same thing as a round ago (no semantic progress) — stop. Two unproductive rounds = looping.
- No progress on DoD across 3 rounds → stop and hand off.

### 2. Hallucination
- A statement made as fact but uncheckable and lacking a `verified` status / a source — is a STOP signal, not material
  to continue on. Either verify it (verifier / search in the SoT), or mark it a hypothesis, or escalate. "Sounds confident" ≠ verification.
- You do not raise a status to `verified` without a real outcome. Self-certification is forbidden.

### 3. Attempt limit
- Ceiling of attempts per subtask: 3. Exhausted without success → not a fourth attempt, but stop + a fail report to the Operator.
- A multiple of the expected step/time budget = a signal of drift or underestimated complexity → stop and report.

### 4. Task drift / scope drift (structural constraint)
- The current task's DoD is a BOUNDARY, not just a finish line. An action that advances no DoD item is NOT performed.
- Before every significant action: "which item of which DoD does this advance?" No answer — don't do it.
- No cascading initiative: do not refactor adjacent code, do not "improve along the way," do not fix things noticed outside the DoD,
  do not add components outside the task.
- Channel your observance: noticed something important out of scope → do NOT touch it silently and do NOT ignore it. Write an
  observation record (observed-out-of-scope) to `vault/raw/runs/` and continue your task. If the noticed thing
  BLOCKS the task — escalate to the Operator, not a self-authorized fix.

Right: "did what was asked + a list of what I noticed, tell me whether to take it on." Wrong: "fixed five unrequested things."

### 5. Commit discipline (for roles that change files)
- Produced a file deliverable (code/test/config) — **commit it** to the working repo with a clear message
  in English before declaring the subtask done. An uncommitted result = the task is NOT closed.
- The working tree after your work is **clean** (`git status` empty except for deliberately ignored files).
  Junk artifacts (caches, temporaries) go in `.gitignore`, not in the commit.
- The orchestrator/reviewer does NOT close a task with a dirty tree: no deliverable commit → return to the executor.

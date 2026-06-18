## Classification (you classify INLINE — class + mode set the route)

Classifying the task is YOUR routing decision: the route depth follows from the class. You do it INLINE — you do NOT
spawn a separate agent for it. Classifying is NOT "doing the task": it's deciding which verification pipeline the task needs.
The decision is independent of how much you'd like to route it cheaply — under-classing to save work is forbidden.

Assign EXACTLY one CLASS by what can go wrong and whether a CHEAP CHECK catches it — NOT by surface difficulty.
The discriminator is the STRENGTH of the objective oracle + reversibility:
- `simple` — a single competent executor can produce it AND a STRONG objective oracle (a test/run) FULLY confirms
  correctness. The oracle is the safety net → no decorrelated critic panel needed, even if the task looks tricky. This is
  the FAST path: one executor + the objective check, no spec-gate, no panel. The system should feel ~as fast as a capable
  model solo here — DO NOT inflate it. (`fix_one_digit` with a full Luhn test, `is_odd`, a clear CRUD endpoint → simple.)
- `first_class` — there IS an objective answer but the oracle is PARTIAL/WEAK: a test confirms some properties yet not full
  correctness, optimality, or safety (a subtle exploit, a perf target, a proof), OR producing a correct candidate genuinely
  needs search/exploration one pass won't reliably give. ONLY here do Adversary/Synthesis/Steelman earn their cost.
- `product_convergence` — NO objective oracle at all (taste / naming / strategy / concept): divergence + disagreement-as-
  signal + the Operator's taste.
- `complex_irreversible` — irreversible / high blast radius: the full pipeline + a MANDATORY human gate, REGARDLESS of the oracle.

**The oracle's strength is the MAIN simple↔first_class discriminator — surface difficulty is NOT.** A FULL oracle (a test
that confirms correctness completely) on reversible work → `simple`, however tricky it looks: the oracle catches errors and
the runtime loops the builder to fix them, so a critic panel adds cost at zero safety gain. Promote to `first_class` ONLY
when the oracle is partial/weak or a candidate needs real search. A 20-minute 4-agent pipeline to check one digit is the
exact failure to avoid.

**FULL vs PARTIAL oracle — the decisive test (separates a real `simple` from a trap that only LOOKS verifiable):**
An oracle is **PARTIAL** (→ `first_class`) if EITHER —
  (a) **the check could PASS while the real goal is still unmet** — the result silences the named symptom but is wrong or
      incomplete, or breaks something the check does not cover, or the real acceptance is broader / held-out; OR
  (b) **acceptance is given as a CURATED / NAMED subset** ("make these cases pass", "fix this test/symptom") rather than a
      complete specification — someone curated which checks, so there is almost certainly more the visible check does not pin.
An oracle is **FULL** (→ `simple`) only if passing it genuinely PROVES the goal — it CANNOT pass while the result is wrong.
This is NOT triggered by size or file-count: a multi-file rename with a covering test stays `simple` (it can't false-pass).
It IS triggered by false-pass-possibility / curated acceptance — universal, no domain list (a benchmark "make these named
tests green", a "fix exactly this" symptom report → PARTIAL → `first_class`).

When in doubt, be axis-specific (do NOT round up blindly):
- STRICTER on the irreversibility / no-oracle axis — an unrecoverable or unverifiable mistake is the dangerous one; round UP.
- LEAN to `simple` when a strong FULL oracle exists and the work is reversible — over-classing a fully-checkable reversible
  task is pure waste at zero safety gain. Under-classing bites only where the oracle can't catch the error or you can't undo it.
"It's trivial, let me just do it myself" is still the forbidden shortcut: a `simple` task goes to one executor + the objective
check (FAST), never to your own hands. `simple` ≠ skip the executor; it = the lean, quick route.

Assign the MODE (factual | generative) by the switching rule (see `modes.md`): is the answer ALREADY in a source-of-truth
record that you retrieve/assemble (`factual`), or do you AUTHOR a new artifact (`generative`)? Authoring code/text to a
spec is `generative` even when it's mechanical and its result is checkable — "verifiable" is NOT "factual". `factual` is
only retrieval/assembly from existing product truth. Mark a mixed task so factual sub-questions stay factual on a generative route.

EMPHASIZED: `complex_irreversible` GUARANTEES the Rubric Auditor BEFORE generation AND a mandatory handoff to the Operator
at the final — built-in class gates, not optional. Omitting either is forbidden.

Record the verdict TERSELY on the task: `class` + `mode` + ONE line of justification (the deciding factor: oracle strength
— full / partial / none — plus reversibility). Keep it internally consistent: a FULL oracle supports `simple`, it does not
argue against it. Then proceed to the route (`routes.json`). No reasoning dump.
If the task is so under-specified that you cannot assign a class → escalate via the CEO (`ask_user_questions`), don't guess.

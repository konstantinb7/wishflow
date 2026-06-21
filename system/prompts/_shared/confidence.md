## Confidence metadata (mandatory on a decision; never collapse into a single number)

A decision is not a bare answer. Accompany it with three SEPARATE numbers (0–100):

- `confidence_score` — how sure you are of the decision itself.
- `disagreement_score` — how far the agents/hypotheses diverged. Low disagreement on a high-complexity task is
  SUSPICIOUS (a whiff of a shared blind spot) — flag it.
- `evidence_score` — how much the decision rests on objective verification/facts versus pure reasoning. A check whose
  expected values are re-derived from the artifact under test (a circular self-check) does NOT count as evidence — score it
  as reasoning, not fact. Agent agreement without independent grounds is consensus, not evidence — it does not raise this score.

A decision at 95% and at 55% are different objects; the Operator must see the numbers, not guess from tone.

This metadata feeds the handoff gate: escalate to the Operator on high disagreement, on low confidence/evidence on an
important task, on a suspiciously smooth consensus on a complex task, or on class complex_irreversible (always).

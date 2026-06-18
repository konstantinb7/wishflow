# Source of truth — the convention (set when the org structure is created)

Source of truth = product truth: the documents, code, and artifacts accumulated in the company's knowledge base.
This is the authoritative layer of FACTS about the product — separate from the Learning Loop memory layer (predictions/outcomes
= the system's experience, NOT truth about the product). Don't conflate them.

## How it's set (confirmed by the Operator)
The SoT is bound **when the company/org structure is created** — the company is given a **project-root**: the project
folder with doc subfolders (shared design docs + per-service docs) and code folders.
Example: `<project-root>/docs/**` (shared + per-service) + `<project-root>/<service>/**` (code).

The concrete paths arrive when the org is set up and are recorded:
- in the company config / the agents' environment (the project-root is readable by agents);
- in the `source_of_truth` field of each task spec (which specific artifacts are authoritative for that task).

## What counts as SoT by class
- **security / red-team:** the technical requirements, the specifications of the system under protection, its code/config — as artifacts.
  The real, testable system is the source of OBJECTIVE verification (via the Objective Verifier / Bash).
- **product:** the fixed design docs, code, hard-barriers — as artifacts.
  The Operator is the final arbiter where a document is silent or the question is a matter of taste.
- **code:** the repository itself + the tests as the objective check.

## Availability rule
- The artifact exists and is reachable → the agent reads it and enriches context (Contract 2, step 2).
- No artifact / unreachable → escalate to the Operator, no guessing (Contract 2, step 3).
- An artifact that SHOULD be SoT doesn't exist yet → that is itself a task (create/record it),
  not a reason to fabricate. Escalate.

## Prohibition
Pulling what's missing from the model's own weights and presenting it as fact is forbidden (Principle 10/11).
That's hallucination disguised as enrichment. An honest escalation beats a confident fabrication.

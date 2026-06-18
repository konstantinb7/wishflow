---
name: wishflow-intake
description: >-
  Triage a task before doing it: decide whether it needs the WishFlow reasoning system
  (decorrelated multi-agent verification) or is better done directly. Use when the user
  hands over a substantial task, a decision with no clear test, an irreversible/high-blast
  change, or anything where being confidently wrong is costly. Classifies the task and, if
  it needs the system, submits it to WishFlow (Paperclip) with the chosen class.
---

# WishFlow intake — filter + control plane

You are the entry point to the WishFlow reasoning system. The user must NOT have to know whether a task needs the
system — YOU triage it. Most tasks you just do; only some earn the multi-agent pipeline. This skill is built at install
from the same classification rubric the system's COO uses, so your verdict and the system's agree.

## 1. Classify the task (same rubric as the system)

{{CLASSIFICATION}}

## 2. Decide: do it here, or route to WishFlow?

The system earns its cost ONLY where a single capable model is not trustworthy enough. Map the class:

- **`simple`** → **do it yourself, here, now.** A trivial, reversible, fully-checkable task: a solo model + a test is faster
  and just as safe. Routing it to WishFlow is pure overhead. Don't even ask — just do it (run the test to confirm).
- **`first_class`** → **usually do it here; offer WishFlow for high stakes.** There's an objective answer but the oracle is
  partial. You can solve+verify it solo; WishFlow adds decorrelated adversarial critique. Recommend solo unless the cost of a
  subtle wrong answer is high (security, money, a published artifact) — then offer to route.
- **`product_convergence`** → **recommend WishFlow.** No objective oracle (taste / naming / strategy). Solo gives ONE
  confident opinion with no signal about how much to trust it; WishFlow gives decorrelated options + disagreement-as-signal +
  your arbitration. Offer to route; note solo is an option if they just want a quick take.
- **`complex_irreversible`** → **strongly recommend WishFlow.** High blast radius / irreversible. WishFlow adds a rubric
  audit before generation + adversarial review + a MANDATORY human gate before anything acts. Doing this solo risks a
  confident, unrecoverable mistake. Recommend routing; if they insist on solo, proceed only with explicit confirmation.

## 3. Ask the user (their call — you propose)

Use your question tool to present, briefly: the class + the ONE-line why + your recommendation, and the choices —
**[Do it here now]**, **[Route to WishFlow as `<class>`]**, and (when relevant) **[Route as a different class]**. Keep it
short; the user decides. Do not route silently and do not refuse to do it solo if they choose that.

## 4. Route to WishFlow (if chosen)

Read the install config (written at install time) for the API base, company id, and the COO agent id:

```
cat {{CONFIG_PATH}}
```

Create the issue assigned to the COO, with the class marked in the body so the COO trusts it and skips its own classifier
and the launch gate (the user already chose this path here):

```
curl -s -X POST "{{API}}/api/companies/{{COMPANY_ID}}/issues" \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "<short title>",
    "description": "CLASS: <class>\nMODE: <factual|generative>\n\n<the full task statement + any context/constraints>",
    "assigneeAgentId": "{{COO_AGENT_ID}}"
  }'
```

Then tell the user where to watch it: **{{COMPANY_URL}}** (the reasoning-system board), and that the system will come back
to them via a board approval / question if it needs a decision. Build the JSON with `node`/`python3`, never `jq`.

## 5. Do it here (if chosen)

Just do the task directly with your normal tools. Nothing enters WishFlow.

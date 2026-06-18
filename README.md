# WishFlow — a verified decision layer
### A control plane ABOVE your AI agents that makes them reliable on high-stakes work

> This is **not another agent.** It is a control plane that sits above executors (Claude Code, OpenClaw, Hermes, any CLI agent) and turns their fast — but sometimes confidently wrong — output into a **verified, decorrelated, calibrated decision** — spending resources exactly in proportion to task difficulty.

---

## Why hire it

A single top model is fast and often right. But when it's wrong, it's wrong **confidently** — and on high-stakes, irreversible tasks that confident error is expensive: you don't see it until it's too late.

Hire this layer if your work is:

- **security / red-team** with real verification (exploit fired or not — a fact, not an opinion);
- **code that must work**, not just "look done";
- **product design and strategy** — where there's no "right answer" but there is a costly mistake;
- **decisions you can't roll back.**

You don't need "another model" — you need a system that **knows when it's right, checks itself against reality, escalates when it isn't sure, and improves over time.**

---

## What it solves

| Pain of a lone agent | How the layer closes it |
|---|---|
| The model hallucinates **confidently** — correlated blind spots of one model family | **Decorrelation:** the generator and the critic run on **different providers**. A different model family sees what yours can't. |
| "Done" you can't trust (model says it works; it doesn't) | **Objective verification:** the verdict comes from a **real run** (test/exploit exit code), not a model's opinion. |
| Multi-agent systems collapse at the **seams** (~⅓ of failures are lost context at handoff, not model errors) | **Handoff contracts:** every handoff is validated by a gatekeeper before work begins. |
| Memory **poisons itself** — an unverified assumption starts being treated as fact | **Status-bearing memory:** every record carries `prediction / verified / falsified`; only what a real outcome confirmed is trusted. No self-certification. |
| Uncontrolled agent **sprawl** | **Human-gated growth:** a new role is created only with proven need and your approval. |

---

## How it works — two tiers

```
        ┌─ CONTROL PLANE (this layer) ──────────────────────────────┐
TASK  → │  simplicity gate → route by class → decorrelation →        │ → DECISION
        │  objective check → synthesis → escalation / delivery       │   + calibration
        │  → status-bearing memory (Learning Loop)                   │   (confidence /
        └───────────────────────┬─── calls ─────────────────────────┘    disagreement /
                                ▼                                          evidence)
   EXECUTORS (substrate):  Claude Code · OpenCode · OpenClaw · Hermes · other models
   (fast, tool-rich — but lone and self-certifying)
```

**Key idea:** you don't throw away your fast agents — you put a layer above them that decides **which** executor is needed, applies decorrelation and verification, remembers with status, and escalates. Processing depth scales **with task difficulty**, not by default.

**Task path:**

1. **Simplicity gate.** A simple task takes the short route (1–2 agents) — nearly free. The expensive multi-stage pipeline runs **only** where the stakes justify it.
2. **Classification and mode.** Task class (simple / search+verify / convergent-product / irreversible) and mode (factual / generative) determine the route.
3. **Generation + decorrelated critique.** Builder ≠ Adversary, on different providers.
4. **Verification.** Where possible — by real run; where not — adversarially, not by voting.
5. **Synthesis.** Selection with a recorded reason for every item kept/dropped — not averaging.
6. **Escalation gate.** Disagreement / low confidence / suspiciously smooth consensus / irreversibility → the decision goes to **you**, not silently executed.
7. **Memory.** The decision is written as a prediction; later a real outcome confirms or refutes it — the system calibrates.

---

## Why people choose it: what the layer adds on top of ANY agent

| | Lone agent (Claude Code / OpenClaw / Hermes) | The same agent **under this layer** |
|---|---|---|
| Blind spots | correlated (one model family) | caught by a critic on a **different** provider |
| "Done" | model self-declaration | **verdict from a real run** |
| Memory | persistent, but no truth status | **verified / falsified**, poisoning-proof |
| Capability growth | autonomous, uncontrolled | new roles — **only with your approval** |
| Cost on simple tasks | cheap | **just as cheap** (the simplicity gate routes past the pipeline) |
| High-stakes task | cheap up front — **expensive later** (a silent error → cleanup or production) | more up front — **cheaper to a correct outcome**: catches the error before it starts costing |

What matters isn't speed-to-first-draft, it's **total cost to a CORRECT result.** A lone agent is fast to an answer you can't trust; this layer's cost is repaid by the **first caught error** a person or a fast agent would have missed. It's not a competitor to your agents — it's the layer that makes **any** of them fit for work where the price of a confident mistake is high.

---

## Non-negotiable principles

These are not settings — they are the substance of reliability. If a configuration forces a violation, the system stops and calls a human rather than silently working around it.

- **Builder ≠ Adversary, always on different providers.** Without this, decorrelation is fake.
- **Objective verification is a run, not a model's opinion.** Model voting only where a fact physically can't be checked.
- **Synthesis selects, it does not average.** Averaging kills sharp strong ideas.
- **Every memory record carries an epistemic status.** The unverified is never passed off as fact.
- **Org growth is human-controlled only.** The ability to grow ≠ the right to sprawl.
- **Simplicity parity.** At equal quality, the smaller blast radius wins.

---

## What it is **not**

- **Not a replacement** for your agents — it **uses** them as executors.
- **Not "faster to a draft."** Cheap on simple tasks (simplicity gate); on high-stakes it spends more **up front** — and **less in total**, because it catches the error before it has to be cleaned up.
- **Not an autonomous swarm.** No self-replicating agents: every new role goes through your approval.
- **Not question-answer.** It's a full task cycle: decomposition → execution → verification → memory → escalation.

---

## Architecture

- **Config-as-code.** The whole system is versioned role prompts, a model map, and routes. Transparent, reviewed in git, portable anywhere.
- **Runs on [Paperclip](https://github.com/paperclipai/paperclip) as the control plane** (issues, handoffs, execution policy, budgets). Coordination reliability comes from it; thinking quality comes from heterogeneous models and operator prompts.
- **Any executor via an adapter.** A model/CLI agent plugs in as a backend; roles are assigned to models deliberately (a strong model for nuanced reasoning, a different provider for critique).

---

## Status

Config-as-code, deployed with a single command. The role core, decorrelation, objective verification, the Learning Loop, and controlled self-extension are assembled and pass end-to-end acceptance on the reference stand.

---

## Quick start

Point your AI coding agent — **Claude Code or OpenCode** — at the installer and let it do the work:

```
Install the system following https://raw.githubusercontent.com/konstantinb7/wishflow/main/INSTALL.md
```

Your agent (Claude Code or OpenCode) will preflight the environment, install Paperclip if missing, deploy the reasoning system, run a smoke check, and hand you a working pipeline. See `INSTALL.md` for the steps and `ROADMAP.md` for value priorities.

---

## Who it's for

Anyone running **high-stakes tasks** who needs **reliability of output**, not just speed-to-draft. Especially **solo founders and small teams**: they have the least attention to spend on cleanup and no backstop to catch a silent error — so escalation ("look here") and decorrelated blind-spot catching are worth **more** to them, not less. If a confident model error costs you nothing — use a lone agent. If it costs you something — the price of this layer is repaid by the first error it catches.

---

## Author

Konstantin Bogolepov · k@juft.com · GitHub [@konstantinb7](https://github.com/konstantinb7)

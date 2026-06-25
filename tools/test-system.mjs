#!/usr/bin/env node
// test-system — deterministic structural invariants of the config-as-code system.
// No LLM runs: it renders prompts via build-prompt and asserts the contracts hold.
// Covers: (1) output-discipline auto-injected everywhere without killing decomposition,
//         (2) the launch-approval gate (routes flags + COO/CEO wiring).
// Run: node tools/test-system.mjs   (exit 0 = all pass, 1 = a failure)
import { readFileSync, readdirSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const SELF = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(SELF, '..');
const PROMPTS = join(REPO, 'system/prompts');
const render = (rel) => execFileSync('node', [join(SELF, 'build-prompt.mjs'), join(PROMPTS, rel)], { encoding: 'utf8' });

// role prompts = top-level .md in system/prompts, excluding _shared/* and the parked classifier
const roles = readdirSync(PROMPTS).filter(f => f.endsWith('.md') && f !== 'classifier.md');

let pass = 0, fail = 0;
const check = (name, cond, detail = '') => {
  if (cond) { pass++; console.log(`  PASS ${name}`); }
  else { fail++; console.log(`  FAIL ${name}${detail ? ' — ' + detail : ''}`); }
};

console.log('# Output discipline (noise rule)');
for (const r of roles) {
  const out = render(r);
  const n = (out.match(/Output discipline \(every role/g) || []).length;
  check(`${r}: output-discipline injected exactly once`, n === 1, `found ${n}`);
}
// the rule must NOT suppress decomposition — the keep-clause is present
const disc = readFileSync(join(PROMPTS, '_shared/output-discipline.md'), 'utf8');
check('output-discipline keeps decomposition steps (anti-overcut guard)',
  /Decomposition into actual subtasks .* IS the work/.test(disc));
check('output-discipline bans procedural narration',
  /I'll start by|Let me load|do not announce it/.test(disc));

console.log('# Launch-approval gate');
const routes = JSON.parse(readFileSync(join(REPO, 'system/routing/routes.json'), 'utf8')).routes;
check('routes.simple.launchApproval === false', routes.simple.launchApproval === false);
for (const c of ['first_class', 'product_convergence', 'complex_irreversible'])
  check(`routes.${c}.launchApproval === true`, routes[c].launchApproval === true);

const coo = render('coo-orchestrator.md');
check('COO honors an explicit class from the task body (control-plane)', /If the task body carries an EXPLICIT class/.test(coo));
check('COO scope-then-route: estimates scope before classifying (Plan-then-Route)', /estimate SCOPE FIRST/i.test(coo));
check('COO confidence threshold: low scope-confidence rounds UP', /LOW-confidence[\s\S]{0,80}round UP/i.test(coo));
check('classification: full-vs-partial oracle trigger (false-pass / curated acceptance)',
  /FULL vs PARTIAL oracle/i.test(coo) && /could PASS while the real goal/i.test(coo) && /CURATED \/ NAMED subset/i.test(coo));
const dg = render('divergent-generator.md');
check('executors carry the scope-mismatch contract (Contract 4)', /SCOPE-MISMATCH/.test(dg));
check('executors: verify the GOAL not the instruction (acceptance proxy)', /Verify the GOAL, not the instruction/i.test(dg));
check('Contract 4 covers statement-contradicts-artifact', /stated task CONTRADICTS the/i.test(dg));
check('COO handles scope-mismatch: re-classify up + gate on heavy promotion',
  /RE-CLASSIFY[\s\S]{0,300}launchApproval/i.test(coo));
check('COO skips the launch gate when class is explicit (no resume cycle)',
  /EXPLICIT class[\s\S]{0,400}SKIP the launch gate/i.test(coo));
check('COO has the launch-approval gate (Step A1)', /Step A1 — Launch approval for HEAVY classes/.test(coo));
check('COO hard-gate: router-not-doer, FORBIDDEN to implement deliverable on heavy classes',
  /YOU ARE A ROUTER, NOT A DOER/.test(coo) && /ABSOLUTELY FORBIDDEN/i.test(coo) && /Mandatory self-check BEFORE/i.test(coo));
check('COO rigor dial: cheap-by-default + mandatory markers + per-node on-contact + checks-not-authors (adaptive-rigor Phase 1)',
  /rigor dial/i.test(coo) && /default is the CHEAP path/i.test(coo) && /MANDATORY-ESCALATION markers/i.test(coo)
  && /Class is PER NODE, set ON CONTACT/i.test(coo) && /adds CHECKS, not authors/i.test(coo));
check('COO composite → DECOMPOSE FIRST then classify each subtask (marker escalates ONLY that subtask, not whole tree) — Phase 1.5',
  /COMPOSITE → DECOMPOSE FIRST/.test(coo) && /one\s+subtask issue per seam/i.test(coo)
  && /ONLY that subtask/.test(coo) && /never the whole tree/i.test(coo)
  && /applies to an ATOMIC node/i.test(coo));
check('COO composite ENACT: spawn child issues NOW, no whole-composite gate, no park (decompose-in-comment-only = FAILURE)',
  /ENACT it/i.test(coo) && /do NOT park/i.test(coo)
  && /zero child issues/i.test(coo) && /board-approval gate on the whole composite/i.test(coo));
check('COO forbids self-assigning lanes', /NEVER set .*assigneeAgentId.* to YOURSELF/i.test(coo));
check('COO invariant: no self-produced result on heavy tasks (children-before-result)',
  /NEVER produce the deliverable[\s\S]{0,200}child\s+subtasks BEFORE any result/i.test(coo) && /0 children/i.test(coo));

const ceo = render('ceo-orchestrator.md');
check('CEO presents launch approval via the FORMAL board queue', /request_board_approval/.test(ceo));
check('CEO gate is binary approve/reject (no request-revision dependency)', !/request_revision|request-revision/i.test(ceo));
check('CEO: approve→relay proceed, reject→honest stop (no auto-run-cheap)',
  /approve[\s\S]{0,80}proceed/i.test(ceo) && /reject[\s\S]{0,80}(stop|halt|not run|NOT woken|not woken)/i.test(ceo));
check('CEO+COO handle the approval-resolution wake (event-driven, not polling)',
  /approval_approved/.test(ceo) && /approval_approved/.test(coo) && /EVENT-DRIVEN|event-driven/.test(ceo));

// --- Evidence independence (verification must not be circular) ---
const ov = render('objective-verifier.md');
check('ObjectiveVerifier rejects circular self-checks but ALLOWS real autotesting',
  /anchored OUTSIDE the code under test/i.test(ov) && /CIRCULAR/.test(ov) && /autotesting is\s+fine/i.test(ov));
check('ObjectiveVerifier: cannot anchor → UNVERIFIED, not a self-mirroring PASS',
  /UNVERIFIED/.test(ov) && /do NOT green-light/i.test(ov));
check('Evidence-anchoring is a cross-cutting contract (reaches every role)',
  /Evidence must be anchored OUTSIDE the work being judged/i.test(dg) &&
  /self-consistency, not correctness/i.test(coo));
check('Rule drives constructive retry, not paralysis (manufacture independence)',
  /manufacture independence/i.test(dg) && /try a different approach/i.test(dg));
check('evidence_score discounts circular self-checks and bare consensus',
  /circular self-check\) does NOT count as evidence/i.test(ov));
check('Contract 2 routes a missing PARTICULAR through the Archivist (REUSE, never invent)',
  /Archivist/.test(dg) && /any concrete PARTICULAR/i.test(dg) && /REUSE it/i.test(dg) && /never invent a fresh one/i.test(dg));
check('Contract 2 rule is DOMAIN-NEUTRAL (cross-domain examples, not software-only)',
  /formulary/i.test(dg) && /citation/i.test(dg) && /ledger/i.test(dg));
check('Contract 3: a missing particular is a retrieval gap, not a builder loop (no self-close to done)',
  /missing PARTICULAR is not a defect in your work/i.test(dg) && /NEVER self-close to done/i.test(dg));
check('ObjectiveVerifier: missing value = source-of-truth gap routed to the Archivist, not a builder loop',
  /source-of-truth gap, not a builder defect/i.test(ov) && /Archivist/.test(ov) && /never an endless builder re-loop/i.test(ov));

console.log(`\n${fail === 0 ? 'OK' : 'FAILED'}: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);

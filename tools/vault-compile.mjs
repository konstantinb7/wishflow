#!/usr/bin/env node
// vault-compile — the SEQUENTIAL Learning Loop compiler (Principle 5: one process, not parallel).
// Deterministic (NO LLM). Closes the fast loop: an outcome with a `predicts:` field → finds the prediction →
// updates its status (verified/falsified) + outcome_ref → computes the delta → writes a lesson to compiled/agents/.
// Run: node tools/vault-compile.mjs [<vault-dir>]
import { readFileSync, writeFileSync, readdirSync, existsSync, appendFileSync } from 'node:fs';
import { dirname, join, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const SELF = dirname(fileURLToPath(import.meta.url));
const VAULT = process.argv[2] || (process.env.PAPERCLIP_VAULT || `${process.env.PAPERCLIP_DEPLOY || `${process.env.HOME}/paperclip-deploy`}/vault`);
const today = new Date().toISOString().slice(0, 10); // allowed: an ordinary node script (not a workflow)

function parseFm(text) {
  if (!text.startsWith('---')) return { fm: {}, body: text };
  const end = text.indexOf('\n---', 3);
  const block = text.slice(text.indexOf('\n') + 1, end); const fm = {};
  for (const l of block.split('\n')) { const m = l.match(/^([a-zA-Z_]+):\s*(.*?)\s*$/); if (m) fm[m[1]] = m[2]; }
  return { fm, body: text.slice(end + 4) };
}
function setFm(text, key, val) {
  // function replacer: val may contain `$&`/`$1`/`` $` `` (it is built from a user-controlled slug);
  // a string replacement would interpret those as backreferences and corrupt the written value.
  if (new RegExp(`^${key}:`, 'm').test(text)) return text.replace(new RegExp(`^${key}:.*$`, 'm'), () => `${key}: ${val}`);
  return text.replace(/^---\n/, () => `---\n${key}: ${val}\n`);
}
const rd = sub => { const d = join(VAULT, 'raw', sub); return existsSync(d) ? readdirSync(d).filter(f => f.endsWith('.md')) : []; };

let closed = 0;
const lessons = {};
for (const of of rd('outcomes')) {
  const opath = join(VAULT, 'raw/outcomes', of);
  const { fm: ofm } = parseFm(readFileSync(opath, 'utf8'));
  const predRef = (ofm.predicts || '').trim();
  if (!predRef) continue;
  const pname = basename(predRef);
  const ppath = join(VAULT, 'raw/predictions', pname);
  if (!existsSync(ppath)) { console.log(`skip: prediction ${pname} not found for ${of}`); continue; }
  let ptext = readFileSync(ppath, 'utf8');
  const { fm: pfm } = parseFm(ptext);
  if (pfm.status !== 'prediction') continue; // already closed — leave it

  // closure: prediction status → outcome status (verified|falsified), outcome_ref → outcome
  const newStatus = ofm.status === 'verified' ? 'verified' : 'falsified';
  ptext = setFm(ptext, 'status', newStatus);
  ptext = setFm(ptext, 'outcome_ref', `raw/outcomes/${of}`);
  writeFileSync(ppath, ptext);
  closed++;

  // delta: the prediction was confirmed (verified) or refuted (falsified)
  const author = pfm.author_agent || 'unknown';
  const delta = newStatus === 'verified' ? 'confirmed' : 'REFUTED (negative knowledge)';
  (lessons[author] ??= []).push(`- ${today}: prediction [[${pname.replace(/\.md$/, '')}]] → **${newStatus}** (${delta}); outcome [[${of.replace(/\.md$/, '')}]]`);
  console.log(`closed: ${pname} → ${newStatus} (author ${author})`);
}

// lessons into compiled/agents/<author>.md (agent reliability by class — Level 3)
for (const [author, lines] of Object.entries(lessons)) {
  const lf = join(VAULT, 'compiled/agents', `${author}.md`);
  if (!existsSync(lf)) writeFileSync(lf, `---\nstatus: verified\ncreated: ${today}\nauthor_agent: vault-compiler\ntask_class: first_class\noutcome_ref:\nsupersedes:\n---\n# Agent reliability: ${author}\n\nClosed predictions (Learning Loop):\n`);
  appendFileSync(lf, lines.join('\n') + '\n');
}

// index
if (closed) {
  const idx = join(VAULT, 'index.md');
  appendFileSync(idx, `\n<!-- compile ${today}: closed ${closed} prediction→outcome -->\n`);
  // lint + commit (the sequential step)
  try { execFileSync('node', [join(SELF, 'vault-lint.mjs'), VAULT], { stdio: 'pipe' }); } catch (e) { console.error('LINT FAIL:', e.stdout?.toString()); process.exit(1); }
  execFileSync('git', ['-C', VAULT, 'add', '-A']);
  try { execFileSync('git', ['-C', VAULT, '-c', 'user.name=vault-compiler', '-c', 'user.email=vault@local', 'commit', '-q', '-m', `compile: closed ${closed} prediction(s) -> outcome (delta + lessons)`]); } catch {}
}
console.log(`\nvault-compile: closed ${closed} prediction→outcome→delta→lesson loops`);

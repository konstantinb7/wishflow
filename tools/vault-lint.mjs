#!/usr/bin/env node
// vault-lint — a memory-discipline check (Principles 5, 8, 9). No external dependencies.
// Run: node tools/vault-lint.mjs <vault-dir>
// Exit 0 — no errors (warnings allowed). Exit 1 — there are errors. Exit 2 — vault not found.

import { readdirSync, readFileSync, statSync, existsSync } from 'node:fs';
import { join, relative, basename } from 'node:path';

const VAULT = process.argv[2] || '.';
const STATUSES = new Set(['prediction', 'verified', 'falsified', 'superseded']);
const REQUIRED = ['status', 'created', 'author_agent', 'task_class'];
// The root control files (SCHEMA/agents/index/log) are not records: we don't check their frontmatter or wikilinks.

if (!existsSync(VAULT)) { console.error(`vault not found: ${VAULT}`); process.exit(2); }

const errors = [];
const warnings = [];
const mdFiles = [];        // all .md under vault
const stems = new Set();   // names without .md — for wikilink checking

function walk(dir) {
  for (const name of readdirSync(dir)) {
    if (name === '.git' || name === 'node_modules') continue;
    const p = join(dir, name);
    const st = statSync(p);
    if (st.isDirectory()) walk(p);
    else if (name.endsWith('.md')) { mdFiles.push(p); stems.add(basename(name, '.md')); }
  }
}
walk(VAULT);

function parseFrontmatter(text) {
  if (!text.startsWith('---')) return null;
  const end = text.indexOf('\n---', 3);
  if (end === -1) return null;
  const block = text.slice(text.indexOf('\n') + 1, end);
  const fm = {};
  for (const line of block.split('\n')) {
    const m = line.match(/^([a-zA-Z_]+):\s*(.*?)\s*(#.*)?$/);
    if (m) fm[m[1]] = m[2].trim();
  }
  return fm;
}

// records = .md under raw/ or compiled/, except .gitkeep
function isRecord(p) {
  const rel = relative(VAULT, p).replace(/\\/g, '/');
  return (rel.startsWith('raw/') || rel.startsWith('compiled/')) && !rel.endsWith('.gitkeep');
}

for (const p of mdFiles) {
  const rel = relative(VAULT, p).replace(/\\/g, '/');
  const text = readFileSync(p, 'utf8');

  if (isRecord(p)) {
    const fm = parseFrontmatter(text);
    if (!fm) { errors.push(`${rel}: no valid frontmatter (--- ... ---)`); continue; }
    for (const f of REQUIRED) {
      if (!fm[f]) errors.push(`${rel}: missing mandatory frontmatter field '${f}'`);
    }
    if (fm.status && !STATUSES.has(fm.status))
      errors.push(`${rel}: invalid status '${fm.status}' (expected ${[...STATUSES].join('|')})`);
    if (fm.created && !/^\d{4}-\d{2}-\d{2}$/.test(fm.created))
      errors.push(`${rel}: created '${fm.created}' is not in YYYY-MM-DD format`);
    if (fm.status === 'superseded' && !fm.supersedes)
      errors.push(`${rel}: status=superseded requires a non-empty 'supersedes'`);
    // outcome records (raw/outcomes/) and compiled roll-ups are themselves outcomes/lessons — nothing for them to reference
    if ((fm.status === 'verified' || fm.status === 'falsified') && !fm.outcome_ref
        && !rel.startsWith('raw/outcomes/') && !rel.startsWith('compiled/'))
      warnings.push(`${rel}: status=${fm.status} without 'outcome_ref' (an outcome link is expected)`);

    // wikilinks are checked only in real records (in SCHEMA/agents they are illustrative)
    for (const m of text.matchAll(/\[\[([^\]|#]+)(?:[#|][^\]]*)?\]\]/g)) {
      const target = m[1].trim().replace(/\.md$/, '');
      if (!stems.has(target)) warnings.push(`${rel}: broken wikilink [[${target}]]`);
    }
  }
}

for (const w of warnings) console.warn(`WARN  ${w}`);
for (const e of errors) console.error(`ERROR ${e}`);
console.log(`\nvault-lint: ${mdFiles.length} .md, ${errors.length} errors, ${warnings.length} warnings`);
process.exit(errors.length ? 1 : 0);

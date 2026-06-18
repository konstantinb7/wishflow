#!/usr/bin/env node
// build-prompt — assembles the final role prompt (AGENTS.md) from system/prompts/<role>.md:
//   - expands {{include:_shared/NAME.md}} markers (DRY: shared blocks in one place)
//   - reads the role's flat frontmatter (hire metadata)
//   - --hire: prints the hire JSON payload (instructionsBundle + adapterType/adapterConfig from models.json)
//   - no flag: prints only the assembled prompt text
// Run: node tools/build-prompt.mjs <path/to/role.md> [--hire]
import { readFileSync } from 'node:fs';
import { dirname, resolve, join, basename, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const SELF = dirname(fileURLToPath(import.meta.url));
const PROMPTS_DIR = resolve(SELF, '../system/prompts');
const MODELS = JSON.parse(readFileSync(resolve(SELF, '../system/models.json'), 'utf8'));

function roleProviderMap() {
  if (!process.env.ROLE_PROVIDER_MAP) return {};
  try { return JSON.parse(process.env.ROLE_PROVIDER_MAP); } catch { return {}; }
}

// --- {{routes}} : render routes by class from routes.json (the single source of truth) ---
function renderRoutes() {
  const R = JSON.parse(readFileSync(resolve(SELF, '../system/routing/routes.json'), 'utf8'));
  const out = ['## Routes by class (from routes.json — SOURCE OF TRUTH, execute EXACTLY)',
    'The class is assigned (the COO classifies inline at intake, Step A) → execute its route by the MECHANISM below. Two mechanisms:',
    '- `execution_policy` (verifiable) → ONE work-issue: assignee = builder, on it `executionPolicy` with',
    '  reviewStages as review stages IN ORDER. The runtime drives the tail + the remediation loop. You do NOT spawn stages by hand.',
    '- `parallel` (product) → parallel sibling generation subtasks (NO blocks between them) → then mergeStages.', ''];
  const reviewList = (arr) => (arr || []).map(s => {
    const when = s.when ? ` (when: ${s.when})` : '';
    const note = s.note ? ` — ${s.note}` : '';
    return `${s.role}${when}${note}`;
  });
  for (const [cls, r] of Object.entries(R.routes)) {
    out.push(`### ${cls}  [mechanism: ${r.mechanism}]`);
    if (r.desc) out.push(`_${r.desc}_`);
    if (r.mechanism === 'execution_policy') {
      if (r.preStages && r.preStages.length)
        out.push(`- preStages (BEFORE the builder, separate subtasks): ${reviewList(r.preStages).join(' → ')}`);
      out.push(`- builder (executor work-issue): ${r.builder}`);
      out.push(`- executionPolicy reviewStages (in order): ${reviewList(r.reviewStages).join(' → ') || '(none)'}`);
    } else if (r.mechanism === 'parallel') {
      const g = r.parallelGeneration || {};
      out.push(`- parallel generation (sibling subtasks): ${(g.agents || []).join(' ∥ ')}${g.modes ? ` [modes: ${g.modes.join('/')}]` : ''}`);
      out.push(`- mergeStages (after merge): ${reviewList(r.mergeStages).join(' → ')}`);
    }
    out.push(`- handoff: ${JSON.stringify(r.handoff)}`, '');
  }
  return out.join('\n').trim();
}

const file = process.argv[2];
const wantHire = process.argv.includes('--hire');
if (!file) { console.error('usage: build-prompt.mjs <role.md> [--hire]'); process.exit(2); }

const raw = readFileSync(resolve(file), 'utf8');

// --- frontmatter (flat key: value) ---
let body = raw, fm = {};
if (raw.startsWith('---')) {
  const end = raw.indexOf('\n---', 3);
  // malformed frontmatter (opened with --- but never closed) → fail loud instead of
  // silently leaking the YAML into the prompt body and hiring with name: undefined.
  if (end === -1) { console.error(`malformed frontmatter (no closing '---') in ${file}`); process.exit(2); }
  const block = raw.slice(raw.indexOf('\n') + 1, end);
  for (const line of block.split('\n')) {
    const m = line.match(/^([a-zA-Z_]+):\s*(.*?)\s*$/);
    if (m) fm[m[1]] = m[2];
  }
  body = raw.slice(end + 4).replace(/^\n+/, '');
}

// --- expand includes (one level is enough) ---
function expand(text) {
  return text
    .replace(/\{\{routes\}\}/g, () => renderRoutes())
    .replace(/\{\{include:([^\}]+)\}\}/g, (_, p) => {
      const inc = readFileSync(join(PROMPTS_DIR, p.trim()), 'utf8').trim();
      return inc;
    });
}
// auto-append output discipline to EVERY role prompt (build-time global injection — no per-prompt include needed)
const OUTPUT_DISCIPLINE = readFileSync(join(PROMPTS_DIR, '_shared/output-discipline.md'), 'utf8').trim();
const assembled = expand(body).trim() + '\n\n' + OUTPUT_DISCIPLINE + '\n';

if (!wantHire) { process.stdout.write(assembled); process.exit(0); }

// --- hire payload ---
const roleName = basename(file, extname(file));
// Install-time override first (ROLE_PROVIDER_MAP), then prompt frontmatter, then canonical roleAssignment.
const providerKey = roleProviderMap()[roleName] || fm.provider || MODELS.roleAssignment[roleName] || 'claude';
const prov = MODELS.providers[providerKey];
if (!prov) { console.error(`unknown provider '${providerKey}' for ${file}`); process.exit(1); }

const adapterConfig = {};
if (prov.model) adapterConfig.model = prov.model;
// command/args from the PROVIDER (e.g. kimi via acpx_local: command=kimi, args=[--skills-dir,…,acp])
if (prov.command) adapterConfig.command = prov.command;
if (prov.args) adapterConfig.args = prov.args;
// process agents carry command/args in frontmatter (command, args — a JSON array as a string)
if (fm.command) adapterConfig.command = fm.command;
if (fm.args) { try { adapterConfig.args = JSON.parse(fm.args); } catch { adapterConfig.args = [fm.args]; } }
if (fm.timeoutSec) adapterConfig.timeoutSec = Number(fm.timeoutSec);

// resolve ${ENV} placeholders at hire time (install-anywhere: paths are parametrized on export,
// the installer sets the env vars per INSTALL.md; an unset var is left as the literal placeholder).
const resolveEnv = (s) => typeof s === 'string' ? s.replace(/\$\{(\w+)\}/g, (_, k) => process.env[k] ?? `\${${k}}`) : s;
if (adapterConfig.command) adapterConfig.command = resolveEnv(adapterConfig.command);
if (adapterConfig.model) adapterConfig.model = resolveEnv(adapterConfig.model);
if (Array.isArray(adapterConfig.args)) adapterConfig.args = adapterConfig.args.map(resolveEnv);
if (prov.env) {
  adapterConfig.env = {};
  for (const [k, v] of Object.entries(prov.env)) adapterConfig.env[k] = resolveEnv(v);
}

const hire = {
  name: fm.name,
  role: fm.role || 'general',
  title: fm.title || fm.name,
  adapterType: prov.adapterType,
  adapterConfig,
  instructionsBundle: { files: { 'AGENTS.md': assembled } },
  runtimeConfig: { heartbeat: {
    enabled: fm.heartbeatEnabled === 'true',
    wakeOnDemand: fm.wakeOnDemand !== 'false',
  } },
  budgetMonthlyCents: Number(fm.budgetMonthlyCents || 0),
  // reportsToName is resolved to a UUID by the installer after the manager is hired
  reportsToName: fm.reportsTo && fm.reportsTo !== 'null' ? fm.reportsTo : null,
  _providerKey: providerKey,
};
process.stdout.write(JSON.stringify(hire, null, 2) + '\n');

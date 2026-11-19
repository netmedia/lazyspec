// LazySpec's reading of a project's OpenSpec, as lazyspec.ps1 reads it: the specs, the changes with their
// workflow's documents, tasks and delta specs, the groups. No VS Code here: tested with node alone.

import * as fs from 'fs';
import * as path from 'path';

export const DASH = '–';
const MIDDOT = '·';

// --- small helpers ----------------------------------------------------------------------------------------

export function readText(file: string): string {
  try {
    let t = fs.readFileSync(file, 'utf8');
    if (t.charCodeAt(0) === 0xfeff) { t = t.slice(1); }
    return t;
  } catch { return ''; }
}
function isFile(p: string): boolean { try { return fs.statSync(p).isFile(); } catch { return false; } }
function isDir(p: string): boolean { try { return fs.statSync(p).isDirectory(); } catch { return false; } }
function subDirs(dir: string): string[] {
  try { return fs.readdirSync(dir, { withFileTypes: true }).filter(d => d.isDirectory()).map(d => d.name).sort(); } catch { return []; }
}
function lines(text: string): string[] { return text.replace(/\r/g, '').split('\n'); }
function count(text: string, rx: RegExp): number { return (text.match(new RegExp(rx.source, rx.flags.includes('g') ? rx.flags : rx.flags + 'g')) || []).length; }
function escapeRx(s: string): string { return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }

export function unquote(value: string): string {
  const v = value.trim();
  let m = /^"(.*)"\s*(#.*)?$/.exec(v) || /^'(.*)'\s*(#.*)?$/.exec(v);
  if (m) { return m[1]; }
  return v.replace(/\s+#.*$/, '').trim();
}
/** A top-level "key: value" of a YAML file. */
export function yamlValue(text: string, key: string): string {
  const m = new RegExp('^' + escapeRx(key) + ':[ \\t]*(.*?)[ \\t]*\\r?$', 'm').exec(text);
  return m ? unquote(m[1]) : '';
}
function inlineList(v: string): string[] {
  const m = /^\[(.*)\]$/.exec(v.trim());
  const body = m ? m[1] : v;
  return body.split(',').map(x => unquote(x).replace(/^["']|["']$/g, '')).filter(x => x);
}
/** A markdown section's body: from "## <Heading>" to the next "## ". */
export function section(text: string, heading: string): string {
  const m = new RegExp('^##\\s+' + escapeRx(heading) + '\\s*$([\\s\\S]*?)(?=^##\\s|(?![\\s\\S]))', 'm').exec(text);
  return m ? m[1].replace(/^[\r\n]+|[\r\n]+$/g, '') : '';
}
/** "open-questions" -> "Open questions". */
export function artifactTitle(id: string): string {
  const t = id.replace(/[-_]/g, ' ');
  return t ? t[0].toUpperCase() + t.slice(1) : t;
}
/** A schema's "generates" glob (* ** ? {a,b}) as a regex over a path with forward slashes. */
export function globRegex(pattern: string): RegExp {
  let out = '^';
  let braces = 0;
  for (let i = 0; i < pattern.length; i++) {
    const c = pattern[i];
    if (c === '*' && pattern[i + 1] === '*') {
      if (pattern[i + 2] === '/') { out += '(?:.*/)?'; i += 2; } else { out += '.*'; i++; }
    }
    else if (c === '*') { out += '[^/]*'; }
    else if (c === '?') { out += '[^/]'; }
    else if (c === '{') { out += '(?:'; braces++; }
    else if (c === '}' && braces) { out += ')'; braces--; }
    else if (c === ',' && braces) { out += '|'; }
    else { out += escapeRx(c); }
  }
  return new RegExp(out + '$');
}
function walk(dir: string, base = dir, out: string[] = []): string[] {
  let entries: fs.Dirent[] = [];
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return out; }
  for (const e of entries) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) { walk(p, base, out); } else if (e.isFile()) { out.push(p); }
  }
  return out;
}
export function artifactFiles(dir: string, generates: string): string[] {
  const pattern = generates.replace(/\\/g, '/').replace(/^[./]+/, '');
  if (!/[*?{]/.test(pattern)) {
    const p = path.join(dir, pattern);
    return isFile(p) ? [p] : [];
  }
  const rx = globRegex(pattern);
  return walk(dir).filter(f => rx.test(path.relative(dir, f).replace(/\\/g, '/'))).sort();
}

// --- the workflow (an OpenSpec schema) ----------------------------------------------------------------------

export interface Artifact { id: string; generates: string; requires: string[] }
export interface Workflow { name: string; tracks: string; missing: string; language: string; grouping: string[]; artifacts: Artifact[] }

export const DEFAULT_WORKFLOW: Workflow = {
  name: 'spec-driven', tracks: 'tasks.md', missing: '', language: '', grouping: [],
  artifacts: [
    { id: 'proposal', generates: 'proposal.md', requires: [] },
    { id: 'specs', generates: 'specs/**/*.md', requires: ['proposal'] },
    { id: 'design', generates: 'design.md', requires: ['proposal'] },
    { id: 'tasks', generates: 'tasks.md', requires: ['specs', 'design'] },
  ],
};

/** A schema.yaml: its artifacts (id, generates, requires), apply.tracks, language:, grouping:. */
export function parseWorkflow(text: string, name: string): Workflow | null {
  const artifacts: Artifact[] = [];
  let tracks = '', language = '';
  const grouping: string[] = [];
  let sectionName = '', itemIndent = -1, keyIndent = -1, listKey = '';
  let cur: Artifact | null = null;
  for (const line of lines(text)) {
    if (!line.trim() || line.trimStart().startsWith('#')) { continue; }
    let m = /^([A-Za-z_][\w-]*):\s*(.*)$/.exec(line);
    if (m) {
      sectionName = m[1]; itemIndent = -1; keyIndent = -1; cur = null;
      if (sectionName === 'language') { language = unquote(m[2]).toLowerCase(); }
      if (sectionName === 'grouping' && /^\[.*\]$/.test(unquote(m[2]))) { grouping.push(...inlineList(unquote(m[2]))); }
      continue;
    }
    const indent = line.length - line.trimStart().length;
    if (sectionName === 'grouping') { m = /^\s*-\s+(.+?)\s*$/.exec(line); if (m) { grouping.push(unquote(m[1])); } continue; }
    if (sectionName === 'artifacts') {
      let k = '', v = '';
      m = /^(\s*)-\s+([\w-]+):\s*(.*)$/.exec(line);
      if (m && (itemIndent < 0 || m[1].length === itemIndent)) {
        itemIndent = m[1].length; keyIndent = line.indexOf(m[2]);
        cur = { id: '', generates: '', requires: [] }; artifacts.push(cur); listKey = '';
        k = m[2]; v = m[3];
      }
      else if (cur && indent === keyIndent && (m = /^\s*([\w-]+):\s*(.*)$/.exec(line))) { k = m[1]; v = m[2]; listKey = ''; }
      else if (cur && listKey === 'requires' && indent > keyIndent && (m = /^\s*-\s+([\w-]+)\s*$/.exec(line))) { cur.requires.push(m[1]); continue; }
      else { continue; }
      if (!cur) { continue; }
      if (k === 'id') { cur.id = unquote(v); }
      else if (k === 'generates') { cur.generates = unquote(v); }
      else if (k === 'requires') { listKey = 'requires'; const iv = unquote(v); if (/^\[.*\]$/.test(iv)) { cur.requires = inlineList(iv); } }
    }
    else if (sectionName === 'apply') {
      if (keyIndent < 0) { keyIndent = indent; }
      m = /^\s*tracks:\s*(.*)$/.exec(line);
      if (indent === keyIndent && m) { tracks = unquote(m[1]); }
    }
  }
  const arts = artifacts.filter(a => a.id && a.generates);
  if (!arts.length) { return null; }
  if (!tracks) { const t = arts.find(a => a.id === 'tasks'); if (t) { tracks = t.generates; } }
  return { name, tracks, missing: '', language, grouping, artifacts: arts };
}

// --- the project's settings (openspec/config.yaml) --------------------------------------------------------

export interface GroupDef { id: string; name: string; description: string; requires: string[] }
export interface Bundle { id: string; title: string; changes: string[]; groups: string[] }
export interface ProjectConfig {
  schema: string;
  values: Record<string, string>;            // lazyspec: key: value
  groupLabel: string; groupPlural: string; groups: GroupDef[];
  bundles: Bundle[];
}

export function groupOrder(id: string): number {
  if (!id) { return Number.MAX_VALUE; }
  return /^\d+$/.test(id) ? parseInt(id, 10) : Number.MAX_VALUE / 2;
}
function byGroupOrder(a: string, b: string): number { return groupOrder(a) - groupOrder(b) || a.localeCompare(b); }

export function parseConfig(text: string): ProjectConfig {
  const cfg: ProjectConfig = { schema: yamlValue(text, 'schema'), values: {}, groupLabel: '', groupPlural: '', groups: [], bundles: [] };
  cfg.groupLabel = yamlValue(text, 'groupLabel') || 'Group';
  cfg.groupPlural = yamlValue(text, 'groupLabelPlural') || `${cfg.groupLabel}s`;
  // groups: (top level), a list of id, name, description, requires.
  let inGroups = false, cur: GroupDef | null = null, itemIndent = -1, listKey = '', keyIndent = -1;
  // lazyspec: values and its bundles: (an entry each: title, changes or groups).
  let inLazy = false, lazyIndent = -1, sub = '', entryIndent = -1, entry: Bundle | null = null;
  for (const line of lines(text)) {
    if (!line.trim() || line.trimStart().startsWith('#')) { continue; }
    const indent = line.length - line.trimStart().length;
    if (indent === 0 && !line.startsWith('-')) {
      inGroups = /^groups:\s*(#.*)?$/.test(line); cur = null; itemIndent = -1;
      inLazy = /^lazyspec:\s*(#.*)?$/.test(line); lazyIndent = -1; sub = ''; entry = null;
      continue;
    }
    const t = line.trimStart();
    if (inGroups) {
      if (cur && listKey === 'description' && indent > keyIndent) { cur.description = `${cur.description} ${t.trim()}`.trim(); continue; }
      let m = /^-\s+([\w-]+):\s*(.*)$/.exec(t);
      let k = '', v = '';
      if (m && (itemIndent < 0 || indent === itemIndent)) {
        itemIndent = indent; keyIndent = indent + 2;
        cur = { id: '', name: '', description: '', requires: [] }; cfg.groups.push(cur);
        k = m[1]; v = m[2];
      }
      else if (cur && listKey === 'requires' && (m = /^-\s+(.+)$/.exec(t))) { cur.requires.push(unquote(m[1])); continue; }
      else if (cur && (m = /^([\w-]+):\s*(.*)$/.exec(t))) { k = m[1]; v = m[2]; keyIndent = indent; }
      else { continue; }
      listKey = '';
      const uv = unquote(v);
      if (!cur) { continue; }
      if (k === 'id') { cur.id = uv; }
      else if (k === 'name') { cur.name = uv; }
      else if (k === 'description') { if (/^[|>][-+]?$/.test(uv)) { listKey = 'description'; } else { cur.description = uv; } }
      else if (k === 'requires') { listKey = 'requires'; if (/^\[.*\]$/.test(uv)) { cur.requires = inlineList(uv); } else if (uv) { cur.requires = [uv]; } }
      continue;
    }
    if (inLazy) {
      const m = /^\s*("[^"]*"|'[^']*'|[^:#]+?):(?:\s+(.*))?$/.exec(line);
      if (!m) { continue; }
      if (lazyIndent < 0) { lazyIndent = indent; }
      const k = unquote(m[1]);
      const v = m[2] ? unquote(m[2]) : '';
      if (indent === lazyIndent) { sub = v ? '' : k; entryIndent = -1; entry = null; if (v) { cfg.values[k] = v; } continue; }
      if (sub !== 'bundles') { continue; }
      if (entryIndent < 0) { entryIndent = indent; }
      if (indent === entryIndent) { entry = { id: k, title: '', changes: [], groups: [] }; cfg.bundles.push(entry); continue; }
      if (!entry) { continue; }
      if (k === 'title') { entry.title = v; }
      else if (k === 'changes') { entry.changes = inlineList(v); }
      else if (k === 'groups') { entry.groups = inlineList(v); }
    }
  }
  cfg.groups = cfg.groups.filter(g => g.id).sort((a, b) => byGroupOrder(a.id, b.id));
  return cfg;
}

// --- specs and changes ----------------------------------------------------------------------------------------

export interface Scenario { name: string; line: number }
export interface Requirement { name: string; line: number; scenarios: Scenario[]; op: string }
export interface Spec {
  type: 'spec'; name: string; short: string; platform: boolean; title: string; reqs: number; scenarioCount: number;
  path: string; dir: string; requirements: Requirement[]; purpose: string;
}
export interface Capability { name: string; added: number; modified: number; removed: number; renamed: number; path: string; requirements: Requirement[] }
export interface Doc { id: string; title: string; generates: string; files: string[]; requires: string[]; isSpecs: boolean; extra: boolean }
export interface Task { num: string; text: string; done: boolean; line: number; path: string; group: string }
export interface TaskGroup { title: string; line: number; path: string; tasks: Task[] }
export type Stage = 'Draft' | 'In Progress' | 'Completed' | 'Archived';
export interface Change {
  type: 'change'; name: string; title: string; stage: Stage; archived: boolean; done: number; total: number;
  modified: number; dir: string; path: string; caps: Capability[]; workflow: Workflow; docs: Doc[];
  tasksDoc: Doc | null; taskGroups: TaskGroup[]; group: string; groupFrom: '' | 'x-group' | 'title' | 'folder';
}

/** The requirements and scenarios of a spec or a delta spec, with their line numbers (1-based). */
export function parseRequirements(text: string): Requirement[] {
  const out: Requirement[] = [];
  let op = '';
  let cur: Requirement | null = null;
  lines(text).forEach((l, i) => {
    let m = /^##\s+(ADDED|MODIFIED|REMOVED|RENAMED)\s+Requirements\s*$/i.exec(l);
    if (m) { op = m[1].toUpperCase(); return; }
    m = /^###\s+(?:Requirement|Zahtjev|Anforderung):\s*(.+?)\s*$/.exec(l);
    if (m) { cur = { name: plainInline(m[1]), line: i + 1, scenarios: [], op }; out.push(cur); return; }
    m = /^####\s+(?:Scenario|Scenarij|Szenario):\s*(.+?)\s*$/.exec(l);
    if (m && cur) { cur.scenarios.push({ name: plainInline(m[1]), line: i + 1 }); }
  });
  return out;
}
/** Inline markup off (**bold**, `code`, [text](link)). */
export function plainInline(t: string): string {
  return t.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1').replace(/\*\*/g, '').replace(/`/g, '');
}
/** "## 1. Backend" and its "- [ ] 1.1 ..." lines, with their line numbers. */
export function parseTasks(text: string, file: string): TaskGroup[] {
  const groups: TaskGroup[] = [];
  let cur: TaskGroup | null = null;
  lines(text).forEach((l, i) => {
    let m = /^##\s+(.+?)\s*$/.exec(l);
    if (m) { cur = { title: plainInline(m[1]), line: i + 1, path: file, tasks: [] }; groups.push(cur); return; }
    m = /^\s*[-*]\s+\[([ xX])\]\s+(.+?)\s*$/.exec(l);
    if (!m) { return; }
    if (!cur) { cur = { title: '', line: i + 1, path: file, tasks: [] }; groups.push(cur); }
    const text2 = plainInline(m[2]);
    const n = /^(\d+(?:\.\d+)+)\.?\s/.exec(text2);
    cur.tasks.push({ num: n ? n[1] : '', text: text2, done: m[1] !== ' ', line: i + 1, path: file, group: cur.title });
  });
  return groups.filter(g => g.tasks.length);
}

export class Project {
  readonly osDir: string;
  config!: ProjectConfig;
  name = '';
  specs: Spec[] = [];
  changes: Change[] = [];
  private workflows = new Map<string, Workflow>();
  private schemaDirs: string[] | null = null;
  private specOrder: string[] = [];

  constructor(readonly root: string, private readonly env: NodeJS.ProcessEnv = process.env) {
    this.osDir = path.join(root, 'openspec');
  }

  static isProject(root: string): boolean { return isDir(path.join(root, 'openspec')); }

  load(): this {
    this.workflows.clear();
    this.config = parseConfig(readText(path.join(this.osDir, 'config.yaml')));
    this.name = this.config.values['name'] || path.basename(this.root);
    this.specOrder = [];
    for (const f of [path.join(this.root, 'tools', 'lazyspec', 'lazyspec.json'), path.join(this.root, 'lazyspec.json')]) {
      if (!isFile(f)) { continue; }
      try { const j = JSON.parse(readText(f)); if (Array.isArray(j.specOrder)) { this.specOrder = j.specOrder.map(String); } } catch { /* not ours */ }
      break;
    }
    this.specs = this.loadSpecs();
    this.changes = this.loadChanges();
    return this;
  }

  // The specs, in the project's order (lazyspec.json specOrder), then the overview, platform pages, capabilities.
  private loadSpecs(): Spec[] {
    const dir = path.join(this.osDir, 'specs');
    const list: Spec[] = [];
    for (const name of subDirs(dir)) {
      const file = path.join(dir, name, 'spec.md');
      if (!isFile(file)) { continue; }
      const text = readText(file);
      const platform = name.startsWith('platform-');
      const short = platform ? name.slice('platform-'.length) : name;
      const reqs = parseRequirements(text);
      list.push({
        type: 'spec', name, short, platform, title: this.docTitle(text, name), reqs: reqs.length,
        scenarioCount: reqs.reduce((n, r) => n + r.scenarios.length, 0), path: file, dir: path.join(dir, name),
        requirements: reqs, purpose: section(text, 'Purpose'),
      });
    }
    const rank = (s: Spec) => {
      const i = this.specOrder.indexOf(s.name);
      return i >= 0 ? i : s.short === 'overview' ? 1000 : s.platform ? 1001 : 1002;
    };
    return list.sort((a, b) => rank(a) - rank(b) || a.name.localeCompare(b.name));
  }
  /** A document's "# Title" without the project's name in front ("Acme Portal - Costs" -> "Costs"). */
  private docTitle(text: string, name: string): string {
    const m = /^#\s+(.+?)\s*$/m.exec(text);
    if (!m) { return ''; }
    let t = m[1];
    if (this.name) { t = t.replace(new RegExp('^' + escapeRx(this.name) + `\\s*[-${DASH}—]\\s*`), ''); }
    if (t.toLowerCase() === name.toLowerCase() || t.toLowerCase() === `${name} specification`.toLowerCase()) { return ''; }
    return t;
  }

  private getSchemaDirs(): string[] {
    if (this.schemaDirs) { return this.schemaDirs; }
    const dirs = [path.join(this.osDir, 'schemas')];
    if (this.env.XDG_DATA_HOME) { dirs.push(path.join(this.env.XDG_DATA_HOME, 'openspec', 'schemas')); }
    else if (this.env.LOCALAPPDATA) { dirs.push(path.join(this.env.LOCALAPPDATA, 'openspec', 'schemas')); }
    else if (this.env.HOME) { dirs.push(path.join(this.env.HOME, '.local', 'share', 'openspec', 'schemas')); }
    // The CLI's built-in schemas: next to the openspec command (npm, nvm), or in lib/node_modules.
    for (const bin of (this.env.PATH || this.env.Path || '').split(path.delimiter)) {
      if (!bin) { continue; }
      if (!['openspec', 'openspec.cmd', 'openspec.ps1'].some(f => isFile(path.join(bin, f)))) { continue; }
      for (const d of [path.join(bin, 'node_modules', '@fission-ai', 'openspec', 'schemas'), path.join(bin, '..', 'lib', 'node_modules', '@fission-ai', 'openspec', 'schemas')]) {
        if (isDir(d)) { dirs.push(d); break; }
      }
      break;
    }
    this.schemaDirs = dirs;
    return dirs;
  }
  /** As the CLI: the change's .openspec.yaml schema:, else config.yaml schema:, else spec-driven. */
  workflowFor(changeDir: string): Workflow {
    const name = yamlValue(readText(path.join(changeDir, '.openspec.yaml')), 'schema') || this.config.schema || 'spec-driven';
    const known = this.workflows.get(name);
    if (known) { return known; }
    let wf: Workflow | null = null;
    if (!/[\\/:]|^\.\.?$/.test(name)) {
      for (const d of this.getSchemaDirs()) {
        const f = path.join(d, name, 'schema.yaml');
        if (isFile(f)) { wf = parseWorkflow(readText(f), name); if (wf) { break; } }
      }
    }
    if (!wf) { wf = name === 'spec-driven' ? DEFAULT_WORKFLOW : { ...DEFAULT_WORKFLOW, missing: name }; }
    this.workflows.set(name, wf);
    return wf;
  }

  private loadChanges(): Change[] {
    const dir = path.join(this.osDir, 'changes');
    const list: Change[] = [];
    for (const n of subDirs(dir)) { if (n !== 'archive') { list.push(this.changeInfo(path.join(dir, n), false)); } }
    for (const n of subDirs(path.join(dir, 'archive'))) { list.push(this.changeInfo(path.join(dir, 'archive', n), true)); }
    return list;
  }
  changeInfo(dir: string, archived: boolean): Change {
    const wf = this.workflowFor(dir);
    const docs: Doc[] = [];
    const claimed = new Set<string>();
    for (const a of wf.artifacts) {
      const files = artifactFiles(dir, a.generates);
      files.forEach(f => claimed.add(f.toLowerCase()));
      docs.push({ id: a.id, title: artifactTitle(a.id), generates: a.generates, files, requires: a.requires, isSpecs: a.generates.replace(/\\/g, '/').replace(/^[./]+/, '').startsWith('specs/'), extra: false });
    }
    // Other documents in the change's folder that the workflow doesn't name: after its own.
    let extra: string[] = [];
    try { extra = fs.readdirSync(dir).filter(f => f.toLowerCase().endsWith('.md')).sort(); } catch { /* none */ }
    for (const f of extra) {
      const full = path.join(dir, f);
      if (!claimed.has(full.toLowerCase()) && isFile(full)) {
        const id = f.replace(/\.md$/i, '');
        docs.push({ id, title: artifactTitle(id), generates: f, files: [full], requires: [], isSpecs: false, extra: true });
      }
    }
    // The tasks: the file apply.tracks names (tasks.md by default).
    const tasksDoc = docs.find(d => wf.tracks && d.generates === wf.tracks) || docs.find(d => d.id === 'tasks') || null;
    const taskGroups: TaskGroup[] = [];
    if (tasksDoc) { for (const f of tasksDoc.files) { taskGroups.push(...parseTasks(readText(f), f)); } }
    let done = 0, total = 0;
    for (const g of taskGroups) { for (const t of g.tasks) { total++; if (t.done) { done++; } } }
    const stage: Stage = archived ? 'Archived' : total === 0 ? 'Draft' : done === total ? 'Completed' : 'In Progress';
    const caps: Capability[] = [];
    const specsDir = path.join(dir, 'specs');
    for (const c of subDirs(specsDir)) {
      const p = path.join(specsDir, c, 'spec.md');
      const t = readText(p);
      const n = (op: string) => count(section(t, `${op} Requirements`), /^###\s+Requirement:/m);
      caps.push({ name: c, added: n('ADDED'), modified: n('MODIFIED'), removed: n('REMOVED'), renamed: n('RENAMED'), path: p, requirements: parseRequirements(t) });
    }
    // The title and the file to open: the proposal, else the workflow's first document there is.
    let main = path.join(dir, 'proposal.md');
    if (!isFile(main)) { const first = docs.find(d => !d.isSpecs && d.files.length); if (first) { main = first.files[0]; } }
    const mainDoc = docs.find(d => d.files.includes(main));
    const prefix = ['Change', 'Proposal'].concat(mainDoc ? [escapeRx(mainDoc.title)] : []).join('|');
    let title = '';
    const h1 = /^#\s+(.+?)\s*$/m.exec(readText(main));
    if (h1) { title = h1[1].replace(new RegExp(`^(${prefix})\\s*:\\s*`), '').replace(new RegExp(`^[Gg]\\d+\\s*[${MIDDOT}:|${DASH}-]\\s*`), ''); }
    // Its group: x-group: <id>; else "<label>: <id>" under its first document's title; else g<id>- ('': none).
    let group = yamlValue(readText(path.join(dir, '.openspec.yaml')), 'x-group');
    let groupFrom: Change['groupFrom'] = group ? 'x-group' : '';
    if (!group) {
      const labels = [this.config.groupLabel, 'Group', 'Grupa', 'Gruppe', 'Groep'].filter(x => x).map(escapeRx).join('|');
      const first = docs.find(d => !d.isSpecs && d.files.length);
      if (first) {
        const ls = lines(readText(first.files[0]));
        const h = ls.findIndex(l => /^#\s+\S/.test(l));
        if (h >= 0) {
          const next = ls.slice(h + 1).find(l => l.trim());
          const m = next ? new RegExp(`^\\s*[*_]*(?:${labels})[*_]*\\s*:\\s*[*_]*\\s*([\\w.-]+)`, 'i').exec(next) : null;
          if (m) { group = m[1]; groupFrom = 'title'; }
        }
      }
      const f = /^(?:\d{4}-\d{2}-\d{2}-)?g(\d+)-/.exec(path.basename(dir));
      if (!group && f) { group = f[1]; groupFrom = 'folder'; }
    }
    let modified = 0;
    for (const f of walk(dir)) { try { modified = Math.max(modified, fs.statSync(f).mtimeMs); } catch { /* gone */ } }
    return {
      type: 'change', name: path.basename(dir), title, stage, archived, done, total, modified, dir, path: main, caps,
      workflow: wf, docs, tasksDoc, taskGroups, group, groupFrom,
    };
  }

  // --- groups -------------------------------------------------------------------------------------------

  /** Grouped: a schema that groups (grouping: [group]), or changes with x-group anyway. */
  get grouping(): boolean {
    return this.changes.some(c => c.groupFrom === 'x-group' || c.workflow.grouping.includes('group'));
  }
  groupDef(id: string): GroupDef | undefined { return this.config.groups.find(g => g.id === id); }
  /** "Group 1 - Phase 1" (the project's label), "Group 3" without a name, "Ungrouped". */
  groupTitle(id: string): string {
    if (!id) { return 'Ungrouped'; }
    const t = `${this.config.groupLabel} ${id}`;
    const d = this.groupDef(id);
    return d && d.name && d.name !== t ? `${t} ${DASH} ${d.name}` : t;
  }
  /** The groups chosen and the ones they require (and theirs), in order; added: the required ones. */
  groupSelection(ids: string[]): { ids: string[]; added: Set<string> } {
    const want = new Set<string>(), added = new Set<string>();
    const todo = [...ids];
    ids.forEach(i => want.add(i));
    while (todo.length) {
      const d = this.groupDef(todo.shift()!);
      for (const r of d ? d.requires : []) { if (!want.has(r)) { want.add(r); added.add(r); todo.push(r); } }
    }
    return { ids: [...want].sort(byGroupOrder), added };
  }
  /** The active changes by group: by id, ungrouped last. */
  groups(changes = this.changes.filter(c => !c.archived)): { id: string; changes: Change[]; done: number; total: number }[] {
    const ids = [...new Set(changes.map(c => c.group))].sort(byGroupOrder);
    return ids.map(id => {
      const cs = changes.filter(c => c.group === id);
      return { id, changes: cs, done: cs.reduce((n, c) => n + c.done, 0), total: cs.reduce((n, c) => n + c.total, 0) };
    });
  }
  /** A group's changes that name a change of another group in their documents (its folder's name). */
  groupDependencies(id: string): { change: Change; on: Change }[] {
    const active = this.changes.filter(c => !c.archived);
    const others = active.filter(c => c.group !== id);
    const out: { change: Change; on: Change }[] = [];
    for (const c of active.filter(x => x.group === id)) {
      const text = c.docs.filter(d => !d.isSpecs).flatMap(d => d.files).map(readText).join('\n');
      for (const o of others) { if (text.includes(o.name)) { out.push({ change: c, on: o }); } }
    }
    return out;
  }
}

/** What lists show: a spec's title (else its short name); a change's number and title (without g<id>-). */
export function itemTitle(item: Spec | Change): string {
  if (item.type === 'spec') { return item.title || item.short; }
  const name = item.name.replace(/^g\d+-/, '');
  if (item.title) {
    const m = /^(\d+)-/.exec(name);
    return m ? `${m[1]} ${item.title}` : item.title;
  }
  return name;
}

// --- find --------------------------------------------------------------------------------------------------

export type EntryKind = 'task' | 'req' | 'scn' | 'sec';
export interface Entry {
  kind: EntryKind; item: Spec | Change; where: string; cap: string; context: string; num: string; text: string;
  done: boolean; path: string; line: number; hay: string; art: string;
}

function sectionEntries(list: Entry[], item: Spec | Change, file: string, where: string, art: string) {
  const ls = lines(readText(file));
  let fence = false;
  const heads: { i: number; level: number; text: string }[] = [];
  ls.forEach((l, i) => {
    if (l.trim().startsWith('```')) { fence = !fence; return; }
    const m = !fence && /^(#{2,6})\s+(.+?)\s*#*$/.exec(l);
    if (m) { heads.push({ i, level: m[1].length, text: m[2] }); }
  });
  heads.forEach((h, k) => {
    if (/^(Requirement|Zahtjev|Anforderung|Scenario|Scenarij|Szenario):/.test(h.text) || /^(\w+\s+)?Requirements$/i.test(h.text)) { return; }
    let end = ls.length;
    for (const n of heads.slice(k + 1)) { if (n.level <= h.level) { end = n.i; break; } }
    const text = plainInline(h.text);
    const body = plainInline(ls.slice(h.i + 1, end).join(' ')).slice(0, 3000);
    list.push({ kind: 'sec', item, where, cap: '', context: '', num: '', text, done: false, path: file, line: h.i + 1, hay: `${item.name} ${where} ${text} ${body}`.toLowerCase(), art });
  });
}
function specEntries(list: Entry[], item: Spec | Change, file: string, cap: string, where: string, art: string) {
  for (const r of parseRequirements(readText(file))) {
    list.push({ kind: 'req', item, where, cap, context: '', num: '', text: r.name, done: false, path: file, line: r.line, hay: `${item.name} ${where} ${cap} ${r.name}`.toLowerCase(), art });
    for (const s of r.scenarios) {
      list.push({ kind: 'scn', item, where, cap, context: r.name, num: '', text: s.name, done: false, path: file, line: s.line, hay: `${item.name} ${where} ${cap} ${r.name} ${s.name}`.toLowerCase(), art });
    }
  }
}
/** Every task, requirement, scenario and section of the specs and the changes (archived: with them shown). */
export function searchIndex(p: Project, withArchived: boolean): Entry[] {
  const list: Entry[] = [];
  const changes = p.changes.filter(c => !c.archived).sort((a, b) => a.name.localeCompare(b.name))
    .concat(withArchived ? p.changes.filter(c => c.archived).sort((a, b) => a.name.localeCompare(b.name)) : []);
  for (const c of changes) {
    const where = itemTitle(c);
    const tasksArt = c.tasksDoc ? c.tasksDoc.title : 'Tasks';
    for (const g of c.taskGroups) {
      for (const t of g.tasks) {
        list.push({ kind: 'task', item: c, where, cap: '', context: g.title, num: t.num, text: t.text, done: t.done, path: t.path, line: t.line, hay: `${c.name} ${where} ${g.title} ${t.text}`.toLowerCase(), art: tasksArt });
      }
    }
    for (const cap of c.caps) { specEntries(list, c, cap.path, cap.name, where, 'Specs'); }
    for (const d of c.docs) { if (!d.isSpecs) { for (const f of d.files) { sectionEntries(list, c, f, where, d.title); } } }
  }
  for (const s of p.specs) {
    const where = itemTitle(s);
    specEntries(list, s, s.path, '', where, 'Spec');
    sectionEntries(list, s, s.path, where, 'Spec');
  }
  return list;
}
export type FindKind = 'all' | 'tasks' | 'open tasks' | 'requirements' | 'scenarios' | 'sections';
/** As LazySpec's find: a task number (1.3), words (all of them), g1 / group 1 (that group's only). */
export function find(p: Project, index: Entry[], query: string, kind: FindKind = 'all'): Entry[] {
  let toks = query.toLowerCase().split(/\s+/).filter(t => t);
  let grp: string | null = null;
  if (p.grouping && toks.length) {
    const labels = [p.config.groupLabel.toLowerCase(), 'group', 'grupa', 'gruppe', 'groep'];
    const keep: string[] = [];
    for (let i = 0; i < toks.length; i++) {
      let m: RegExpExecArray | null;
      if (grp === null && (m = /^g(\d+)$/.exec(toks[i]))) { grp = m[1]; continue; }
      if (grp === null && labels.includes(toks[i]) && /^\d+$/.test(toks[i + 1] || '')) { grp = toks[i + 1]; i++; continue; }
      keep.push(toks[i]);
    }
    toks = keep;
  }
  if (!toks.length && grp === null) { return []; }
  const isNum = (t: string) => /^\d+(\.\d+)+\.?$/.test(t);
  const out = index.filter(e => {
    if (kind === 'tasks' && e.kind !== 'task') { return false; }
    if (kind === 'open tasks' && (e.kind !== 'task' || e.done)) { return false; }
    if (kind === 'requirements' && e.kind !== 'req') { return false; }
    if (kind === 'scenarios' && e.kind !== 'scn') { return false; }
    if (kind === 'sections' && e.kind !== 'sec') { return false; }
    if (grp !== null && !(e.item.type === 'change' && e.item.group === grp)) { return false; }
    return toks.every(t => {
      if (isNum(t)) { const n = t.replace(/\.$/, ''); return e.kind === 'task' && (e.num === n || e.num.startsWith(n + '.')); }
      return e.hay.includes(t);
    });
  });
  // Found by its own words (name, heading, group, change) first; by a section's text only, after.
  const own = (e: Entry) => `${e.item.name} ${e.where} ${e.cap} ${e.context} ${e.text} ${e.art}`.toLowerCase();
  const first = out.filter(e => toks.every(t => isNum(t) || own(e).includes(t)));
  return first.concat(out.filter(e => !first.includes(e)));
}

/** A task ticked or not: the line's [ ] / [x] changed, the rest as it is. */
export function setTaskDone(lineText: string, done: boolean): string {
  return lineText.replace(/^(\s*[-*]\s+\[)[ xX](\])/, `$1${done ? 'x' : ' '}$2`);
}

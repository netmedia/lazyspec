// The projects this server works on, the commands it runs (git, gh, the OpenSpec CLI, PowerShell), and the
// guards: what may be written (openspec/, the export folder's sources, the team's shared knowledge in .claude/) and
// what may be read (the project, without secrets), and the Netmedia tools run_tool runs.

import * as cp from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { Project } from '../../vscode/src/model';
import { UserError } from './mcp';

const SKIP = new Set(['node_modules', 'out', 'dist', 'bin', 'obj', 'build', 'target', 'vendor', 'kit', 'openspec']);

/** The folders given (Desktop: the projects folders the PM chose, by default Documents/GitHub; Claude Code:
 *  none). None given, or none of them there (the default on a machine without GitHub Desktop, a Cowork session
 *  that keeps the default): the folder the server runs in. */
export function roots(): string[] {
  const given = [...process.argv.slice(2), ...(process.env.LAZYSPEC_PROJECTS || '').split(path.delimiter)]
    .map(s => s.trim()).filter(s => s && !s.startsWith('${'));
  const there = [...new Set(given.map(r => path.resolve(r)))].filter(r => isDir(r));
  return there.length ? there : [process.cwd()];
}
/** The folders given that aren't there (about reports them). */
export function missingRoots(): string[] {
  return [...process.argv.slice(2), ...(process.env.LAZYSPEC_PROJECTS || '').split(path.delimiter)]
    .map(s => s.trim()).filter(s => s && !s.startsWith('${') && !isDir(path.resolve(s)));
}
function isDir(p: string) { try { return fs.statSync(p).isDirectory(); } catch { return false; } }
export function isFile(p: string) { try { return fs.statSync(p).isFile(); } catch { return false; } }

export interface Found { id: string; root: string }
/** Every folder with an openspec/ in it: a root itself, or up to three levels below it. */
export function discover(): Found[] {
  const out: Found[] = [];
  const seen = new Set<string>();
  const add = (root: string, id: string) => { const k = root.toLowerCase(); if (!seen.has(k)) { seen.add(k); out.push({ id, root }); } };
  const multi = roots().length > 1;
  for (const r of roots()) {
    if (Project.isProject(r)) { add(r, path.basename(r)); }
    const walk = (dir: string, depth: number) => {
      if (depth > 3) { return; }
      let entries: fs.Dirent[] = [];
      try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
      for (const e of entries) {
        if (!e.isDirectory() || e.name.startsWith('.') || SKIP.has(e.name)) { continue; }
        const sub = path.join(dir, e.name);
        if (Project.isProject(sub)) {
          const rel = path.relative(r, sub).replace(/\\/g, '/');
          add(sub, multi ? `${path.basename(r)}/${rel}` : rel);
        }
        walk(sub, depth + 1);
      }
    };
    walk(r, 1);
  }
  return out;
}

/** The project a tool names (its id, its folder's name, or its path); the only one when there's one. */
export function project(arg: unknown): Project {
  const all = discover();
  const want = typeof arg === 'string' ? arg.trim() : '';
  const list = () => all.length ? `Projects: ${all.map(f => f.id).join(', ')}.` : `No OpenSpec project (a folder with openspec/) in ${roots().join(', ')}.`;
  let hit: Found | undefined;
  if (!want) {
    if (all.length === 1) { hit = all[0]; }
    else { throw new UserError(`Which project? ${list()}`); }
  } else {
    const low = want.toLowerCase().replace(/\\/g, '/');
    hit = all.find(f => f.id.toLowerCase() === low)
      || all.find(f => f.root.toLowerCase().replace(/\\/g, '/') === path.resolve(want).toLowerCase().replace(/\\/g, '/'))
      || (() => { const b = all.filter(f => path.basename(f.root).toLowerCase() === low); return b.length === 1 ? b[0] : undefined; })();
  }
  if (!hit) { throw new UserError(`No project "${want}". ${list()}`); }
  return new Project(hit.root).load();
}
export function projectId(p: Project): string {
  return discover().find(f => f.root === p.root)?.id || path.basename(p.root);
}

// --- paths ---------------------------------------------------------------------------------------------------

export function rel(p: Project, file: string): string { return path.relative(p.root, file).replace(/\\/g, '/'); }
function inside(dir: string, file: string): boolean {
  const r = path.relative(dir, file);
  return !!r && !r.startsWith('..') && !path.isAbsolute(r);
}
/** A setting of openspec/config.yaml: "<block>:" then "  key: value" (flat, one level). */
export function configValue(p: Project, block: string, key: string): string {
  let text = '';
  try { text = fs.readFileSync(path.join(p.osDir, 'config.yaml'), 'utf8'); } catch { return ''; }
  let inBlock = false;
  for (const line of text.replace(/\r/g, '').split('\n')) {
    if (!line.trim() || line.trimStart().startsWith('#')) { continue; }
    if (!/^\s/.test(line)) { inBlock = new RegExp(`^${block}:\\s*$`).test(line); continue; }
    const m = inBlock ? /^\s+([A-Za-z]+):\s*(.*?)\s*(#.*)?$/.exec(line) : null;
    if (m && m[1] === key) { return m[2].replace(/^(['"])(.*)\1$/, '$2'); }
  }
  return '';
}
/** Where every export goes - spec exports, estimates, offers, documents: netmedia: exportDir: in
 *  openspec/config.yaml (shared by every Netmedia tool), else lazyspec: exportDir: (older projects), else
 *  openspec/exports/. Always inside the project. */
export function exportDir(p: Project): string {
  const d = configValue(p, 'netmedia', 'exportDir') || configValue(p, 'lazyspec', 'exportDir');
  const dir = d ? path.resolve(p.root, d) : '';
  return dir && inside(p.root, dir) ? dir : path.join(p.osDir, 'exports');
}
/** The team's shared knowledge the process writes outside openspec/ (committed by save): the offer memory, the
 *  estimates' calibration, the agents' profiles and lessons. */
export function isKnowledge(relPath: string): boolean {
  const r = relPath.replace(/\\/g, '/');
  return /^\.claude\/offers\.yaml$/i.test(r) || /^\.claude\/estimates\/.+\.(md|ya?ml|json)$/i.test(r)
    || /^\.claude\/rules\/[^/]+-(profile|gotchas)\.md$/i.test(r);
}
export const KNOWLEDGE_PATHS = ['.claude/offers.yaml', '.claude/estimates', '.claude/rules'];
/** A file of the process outside the specs: in the export folder (sources and data of exports: Markdown, JSON,
 *  YAML, CSV) or the team's shared knowledge (isKnowledge). */
export function writableFile(p: Project, given: unknown): string {
  const s = String(given || '').trim();
  if (!s) { throw new UserError('path is required (from the project folder).'); }
  const file = path.resolve(p.root, s);
  if (!inside(p.root, file)) { throw new UserError(`Only files inside the project can be written; not ${s}.`); }
  const r = rel(p, file);
  if (isKnowledge(r)) { return file; }
  if (inside(exportDir(p), file)) {
    if (!/\.(md|json|ya?ml|csv)$/i.test(file)) { throw new UserError('In the export folder only Markdown, JSON, YAML and CSV are written here; documents come from export_document or run_tool.'); }
    return file;
  }
  throw new UserError(`${r} is not one of the process's files: the export folder (${rel(p, exportDir(p))}/), .claude/offers.yaml, .claude/estimates/, .claude/rules/*-profile.md or *-gotchas.md. Specs: write_document / edit_document.`);
}
/** A path the PM's documents may be written at: under openspec/ (not the export folder). */
export function writable(p: Project, given: unknown, area: 'openspec' | 'changes' = 'openspec'): string {
  const s = String(given || '').trim();
  if (!s) { throw new UserError('path is required (from the project folder, e.g. openspec/changes/<change>/proposal.md).'); }
  const file = path.resolve(p.root, s);
  const base = area === 'changes' ? path.join(p.osDir, 'changes') : p.osDir;
  if (!inside(base, file)) { throw new UserError(`Only files under ${rel(p, base)}/ can be written; not ${s}.`); }
  if (inside(path.join(p.osDir, 'exports'), file) || inside(exportDir(p), file)) {
    throw new UserError(`${rel(p, exportDir(p))}/ is the export folder: write_file for sources, export_document or run_tool for documents.`);
  }
  if (area === 'changes' && inside(path.join(p.osDir, 'changes', 'archive'), file)) { throw new UserError('Archived changes are not edited.'); }
  if (!/\.(md|ya?ml)$/i.test(file)) { throw new UserError('Only Markdown and YAML documents can be written.'); }
  return file;
}
/** A document to read: under openspec/. */
export function readableDoc(p: Project, given: unknown): string {
  const file = path.resolve(p.root, String(given || ''));
  if (!inside(p.osDir, file)) { throw new UserError(`read_document reads files under openspec/; for code use read_code. Not ${given}.`); }
  if (!isFile(file)) { throw new UserError(`There's no ${rel(p, file)}.`); }
  return file;
}
const SECRET = [/(^|\/)\.git(\/|$)/i, /(^|\/)\.env(\.|$)/i, /\.(pem|key|pfx|p12|snk|jks|keystore)$/i, /(^|\/)secrets?\.json$/i,
  /\.publishsettings$/i, /\.pubxml(\.user)?$/i, /(^|\/)id_(rsa|ed25519|ecdsa)/i, /(^|\/)\.npmrc$/i, /(^|\/)local\.settings\.json$/i,
  /(^|\/)appsettings\.[^/]*(local|secret|production)[^/]*\.json$/i];
export function isSecret(relPath: string): boolean { return SECRET.some(rx => rx.test(relPath.replace(/\\/g, '/'))); }
/** A file of the project to read (code, docs), not one that holds secrets. */
export function readableCode(p: Project, given: unknown): string {
  const file = path.resolve(p.root, String(given || ''));
  if (!inside(p.root, file)) { throw new UserError(`Only files inside the project can be read; not ${given}.`); }
  if (isSecret(rel(p, file))) { throw new UserError(`${rel(p, file)} may hold secrets; it isn't read.`); }
  if (!isFile(file)) { throw new UserError(`There's no file ${rel(p, file)}.`); }
  return file;
}

// --- commands --------------------------------------------------------------------------------------------------

export interface Run { code: number; out: string; err: string; missing: boolean }
/** A command, without a shell (with one only for a .cmd on Windows, its arguments checked). */
export function run(cmd: string, args: string[], cwd: string, timeoutMs = 120000): Run {
  const viaShell = process.platform === 'win32' && /\.(cmd|bat)$/i.test(cmd);
  if (viaShell && args.some(a => !/^[\w@%+=:,./\\-]*$/.test(a))) { throw new UserError(`Unsafe argument for ${cmd}.`); }
  const r = cp.spawnSync(viaShell ? [`"${cmd}"`, ...args].join(' ') : cmd, viaShell ? [] : args, {
    cwd, encoding: 'utf8', windowsHide: true, shell: viaShell, timeout: timeoutMs, maxBuffer: 64 * 1024 * 1024,
    env: { ...process.env, GIT_TERMINAL_PROMPT: '0', NO_COLOR: '1', FORCE_COLOR: '0' },
  });
  const missing = !!r.error && (r.error as NodeJS.ErrnoException).code === 'ENOENT';
  return { code: r.status ?? -1, out: r.stdout || '', err: (r.stderr || '') + (r.error && !missing ? String(r.error) : ''), missing };
}
export function git(p: Project, args: string[], timeoutMs?: number): Run { return run('git', ['-c', 'core.quotepath=off', ...args], p.root, timeoutMs); }
export function onPath(name: string): string {
  const exts = process.platform === 'win32' ? ['.exe', '.cmd', '.bat', ''] : [''];
  for (const dir of (process.env.PATH || process.env.Path || '').split(path.delimiter)) {
    for (const e of exts) { const f = path.join(dir, name + e); if (dir && isFile(f)) { return f; } }
  }
  return '';
}

/** The OpenSpec CLI: the one shipped with this server, else the one on PATH. */
export function openspec(p: Project, args: string[], timeoutMs?: number): Run {
  const bundled = path.join(__dirname, 'node_modules', '@fission-ai', 'openspec', 'bin', 'openspec.js');
  if (isFile(bundled)) { return run(process.execPath, [bundled, ...args], p.root, timeoutMs); }
  const cli = onPath('openspec');
  // npm's openspec.cmd: the package's own bin next to it, run with this Node (no shell).
  const js = cli && path.join(path.dirname(cli), 'node_modules', '@fission-ai', 'openspec', 'bin', 'openspec.js');
  if (js && isFile(js)) { return run(process.execPath, [js, ...args], p.root, timeoutMs); }
  if (!cli) { return { code: -1, out: '', err: 'The OpenSpec CLI is not available (npm install -g @fission-ai/openspec).', missing: true }; }
  return run(cli, args, p.root, timeoutMs);
}
export function openspecVersion(): string {
  const bundled = path.join(__dirname, 'node_modules', '@fission-ai', 'openspec', 'package.json');
  try { return `${JSON.parse(fs.readFileSync(bundled, 'utf8')).version} (bundled)`; } catch { /* not bundled */ }
  return onPath('openspec') ? 'on PATH' : 'not available';
}

/** lazyspec.ps1 for the exports: the project's own kit, else the one shipped with this server or this repo. */
export function kitScript(p: Project): string {
  for (const f of [path.join(p.root, 'tools', 'lazyspec', 'lazyspec.ps1'), path.join(__dirname, 'kit', 'lazyspec.ps1'),
    path.join(__dirname, '..', '..', 'tools', 'lazyspec', 'lazyspec.ps1')]) {
    if (isFile(f)) { return f; }
  }
  return '';
}
export function powershell(): string {
  if (process.platform === 'win32') { return onPath('pwsh') || 'powershell.exe'; }
  return onPath('pwsh') || '/usr/local/bin/pwsh';
}

// --- the Netmedia tools (run_tool) ------------------------------------------------------------------------------

/** The scripts of the Netmedia plugins (AIToolbelt) that run_tool may run, by name. The scripts exist once, in
 *  AIToolbelt; nothing here is a copy of their logic. */
export const NETMEDIA_TOOLS: Record<string, { plugin: string; script: string; runtime: 'python' | 'node'; what: string }> = {
  'offer-prep': { plugin: 'netmedia', script: 'skills/make-offer-planning/scripts/offer_prep.py', runtime: 'python', what: 'offer and project plan preparation (netmedia:make-offer-planning): workbook sheets, headers, sections, specs, remembered picks, rates, prices, file name, planning rules, holidays, the schedule' },
  offer: { plugin: 'netmedia-document', script: 'offer/offer.py', runtime: 'python', what: 'the offer document: new, check, build (Word, PDF)' },
  estimate: { plugin: 'netmedia', script: 'skills/estimate/scripts/build_estimate.py', runtime: 'python', what: 'the estimate workbook' },
  document: { plugin: 'netmedia-document', script: 'scripts/netmedia_document.py', runtime: 'python', what: 'a Netmedia document (Word, PDF) from Markdown' },
  translate: { plugin: 'netmedia-tools', script: 'skills/translate/scripts/deepl.ts', runtime: 'node', what: 'DeepL translation' },
  hasek: { plugin: 'netmedia-tools', script: 'skills/hasek/scripts/hasek.ts', runtime: 'node', what: 'the Croatian check (Hašek)' },
};
function newest(files: string[]): string {
  return files.map(f => { try { return { f, t: fs.statSync(f).mtimeMs }; } catch { return { f, t: 0 }; } })
    .sort((a, b) => b.t - a.t)[0]?.f || '';
}
/** Copies of a plugin's file under a folder: <root>/**\/<plugin>/**\/<file>, up to six levels. */
function findPluginFile(root: string, plugin: string, file: string): string[] {
  const hits: string[] = [];
  const walk = (dir: string, depth: number) => {
    if (depth > 6) { return; }
    let entries: fs.Dirent[] = [];
    try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      if (!e.isDirectory() || e.name === 'node_modules' || e.name === '.git') { continue; }
      const sub = path.join(dir, e.name);
      if (e.name === plugin) {
        if (isFile(path.join(sub, file))) { hits.push(path.join(sub, file)); }
        for (const v of (() => { try { return fs.readdirSync(sub, { withFileTypes: true }); } catch { return []; } })()) {
          if (v.isDirectory() && isFile(path.join(sub, v.name, file))) { hits.push(path.join(sub, v.name, file)); }
        }
      }
      walk(sub, depth + 1);
    }
  };
  walk(root, 0);
  return hits;
}
/** Where a Netmedia tool's script is: NETMEDIA_PLUGINS (a folder with the plugins, e.g. an AIToolbelt clone's
 *  plugins/), the plugins installed in Claude Code (~/.claude/plugins, the newest copy), else the copy bundled in
 *  this extension (server/netmedia/<plugin>/...). */
export function netmediaScript(name: string): { file: string; from: string } {
  const t = NETMEDIA_TOOLS[name];
  if (!t) { throw new UserError(`No tool "${name}". Tools: ${Object.keys(NETMEDIA_TOOLS).join(', ')}.`); }
  const given = (process.env.NETMEDIA_PLUGINS || '').trim();
  if (given && isFile(path.join(given, t.plugin, t.script))) { return { file: path.join(given, t.plugin, t.script), from: 'NETMEDIA_PLUGINS' }; }
  const installed = newest(findPluginFile(path.join(os.homedir(), '.claude', 'plugins'), t.plugin, t.script));
  if (installed) { return { file: installed, from: 'the installed plugin' }; }
  const bundled = path.join(__dirname, 'netmedia', t.plugin, t.script);
  if (isFile(bundled)) { return { file: bundled, from: 'bundled with LazySpec' }; }
  return { file: '', from: '' };
}
/** The Python the Netmedia tools run with: the Netmedia environment (~/.netmedia/python, the same on Windows and
 *  macOS), else py -3 (Windows) or python3. */
export function python(): { cmd: string; pre: string[]; env: boolean } {
  const venv = path.join(os.homedir(), '.netmedia', 'python', process.platform === 'win32' ? 'Scripts' : 'bin',
    process.platform === 'win32' ? 'python.exe' : 'python');
  if (isFile(venv)) { return { cmd: venv, pre: [], env: true }; }
  if (process.platform === 'win32') { const py = onPath('py'); if (py) { return { cmd: py, pre: ['-3'], env: false }; } }
  return { cmd: onPath('python3') || onPath('python') || 'python3', pre: [], env: false };
}
/** run_tool's guard: every argument that names a path is inside the project, not a secret. */
export function checkToolArgs(p: Project, args: string[]): void {
  for (const a of args) {
    const value = a.includes('=') && a.startsWith('-') ? a.slice(a.indexOf('=') + 1) : a;
    const looksLikePath = /[\\/]/.test(value) || /\.(md|json|ya?ml|csv|xlsx|docx|pdf|txt)$/i.test(value);
    if (!looksLikePath || /^https?:\/\//i.test(value)) { continue; }
    const file = path.resolve(p.root, value);
    if (!inside(p.root, file) && file !== p.root) { throw new UserError(`run_tool works inside the project only; not ${value}.`); }
    if (isSecret(rel(p, file))) { throw new UserError(`${rel(p, file)} may hold secrets; run_tool does not touch it.`); }
  }
}

// --- text ----------------------------------------------------------------------------------------------------

export function today(sep = '-'): string {
  const d = new Date();
  return [d.getFullYear(), String(d.getMonth() + 1).padStart(2, '0'), String(d.getDate()).padStart(2, '0')].join(sep);
}
export function clip(t: string, max: number): string { return t.length > max ? `${t.slice(0, max)}\n… (${t.length - max} more characters)` : t; }
export function json(v: unknown): string { return JSON.stringify(v, null, 2); }
/** A file read as text with its line ends and BOM noted, so a write keeps them. */
export function readRaw(file: string): { text: string; nl: string; bom: boolean } {
  let raw = fs.readFileSync(file, 'utf8');
  const bom = raw.charCodeAt(0) === 0xfeff;
  if (bom) { raw = raw.slice(1); }
  return { text: raw.replace(/\r\n/g, '\n'), nl: raw.includes('\r\n') ? '\r\n' : '\n', bom };
}
export function writeRaw(file: string, text: string, nl = '\n', bom = false) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, (bom ? '﻿' : '') + text.replace(/\r\n/g, '\n').replace(/\n/g, nl), 'utf8');
}

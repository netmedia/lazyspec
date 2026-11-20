// The projects this server works on, the commands it runs (git, gh, the OpenSpec CLI, PowerShell), and the
// guards: what may be written (openspec/ only) and what may be read (the project, without secrets).

import * as cp from 'child_process';
import * as fs from 'fs';
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
/** A path the PM's documents may be written at: under openspec/ (not exports/). */
export function writable(p: Project, given: unknown, area: 'openspec' | 'changes' = 'openspec'): string {
  const s = String(given || '').trim();
  if (!s) { throw new UserError('path is required (from the project folder, e.g. openspec/changes/<change>/proposal.md).'); }
  const file = path.resolve(p.root, s);
  const base = area === 'changes' ? path.join(p.osDir, 'changes') : p.osDir;
  if (!inside(base, file)) { throw new UserError(`Only files under ${rel(p, base)}/ can be written; not ${s}.`); }
  if (inside(path.join(p.osDir, 'exports'), file)) { throw new UserError('openspec/exports/ is written by export_document only.'); }
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

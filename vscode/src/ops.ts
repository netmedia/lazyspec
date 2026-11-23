// What LazySpec does to a project's documents, as lazyspec.ps1 does it, so that the two can be used side by
// side: items edited and deleted (the main specs through a change), the agent's prompts, out-of-date
// documents (.lazyspec/sync.json), undo against git, the project's settings in config.yaml. No VS Code here.

import * as cp from 'child_process';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { Change, Entry, plainInline, Project, readText } from './model';

const KIND_WORD: Record<Entry['kind'], string> = { task: 'task', req: 'requirement', scn: 'scenario', sec: 'section', item: 'item' };
export function kindWord(k: Entry['kind']): string { return KIND_WORD[k]; }
function today(sep = ''): string { const d = new Date(); return [d.getFullYear(), String(d.getMonth() + 1).padStart(2, '0'), String(d.getDate()).padStart(2, '0')].join(sep); }
export function relPath(root: string, file: string): string { return path.relative(root, file).replace(/\\/g, '/'); }

// --- a document's lines ---------------------------------------------------------------------------------

export function readLines(file: string): string[] { return readText(file).replace(/\r/g, '').split('\n'); }
/** Written back in the file's own line ends; no two blank lines in a row where a block was taken out. */
export function writeLines(file: string, lines: string[]) {
  const raw = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  const nl = raw.includes('\r\n') ? '\r\n' : '\n';
  const out: string[] = [];
  for (const l of lines) { if (!l.trim() && out.length && !out[out.length - 1].trim()) { continue; } out.push(l); }
  fs.writeFileSync(file, out.join(nl), 'utf8');
}
/** A block: a task (its line and the lines indented under it), a requirement or a scenario (to the next heading
 *  of its level or above), a section (to the next heading of its level or above, not one in a code block). */
export function blockEnd(lines: string[], at: number, kind: Entry['kind']): number {
  let j = at + 1;
  if (kind === 'task' || kind === 'item') {
    const ind = lines[at].length - lines[at].trimStart().length;
    while (j < lines.length && lines[j].trim() && lines[j].length - lines[j].trimStart().length > ind) { j++; }
    return j;
  }
  if (kind === 'sec') {
    const m = /^(#{1,6})\s/.exec(lines[at]);
    const stop = new RegExp(`^#{1,${m ? m[1].length : 2}}\\s`);
    let fence = false;
    for (; j < lines.length; j++) {
      if (lines[j].trim().startsWith('```')) { fence = !fence; }
      else if (!fence && stop.test(lines[j])) { break; }
    }
    return j;
  }
  const stop = kind === 'scn' ? /^#{1,4}\s/ : /^#{1,3}\s/;
  while (j < lines.length && !stop.test(lines[j])) { j++; }
  return j;
}
/** An item's own lines, as they are now (without the blank lines after it). */
export function itemBlock(e: Entry): { at: number; end: number; lines: string[] } | null {
  const lines = readLines(e.path);
  const at = e.line - 1;
  if (at < 0 || at >= lines.length || !isThere(lines[at], e)) { return null; }
  let end = blockEnd(lines, at, e.kind);
  while (end - 1 > at && !lines[end - 1].trim()) { end--; }
  return { at, end, lines: lines.slice(at, end) };
}
function isThere(line: string, e: Entry): boolean { return plainInline(line).includes(e.text.replace(/\s+$/, '').slice(0, 60)); }

// --- delete -------------------------------------------------------------------------------------------------

/** Removes tasks, requirements, scenarios and sections. In a change's documents: taken out (a delta spec left
 *  without requirements: deleted; a section left empty: its heading too). In the main specs: a new change
 *  with REMOVED (a requirement) or MODIFIED (a requirement without the removed scenarios). What it did. */
export function removeEntries(p: Project, entries: Entry[]): string[] {
  const report: string[] = [];
  const direct = entries.filter(e => e.item.type !== 'spec' || e.kind === 'sec');
  const main = entries.filter(e => e.item.type === 'spec' && e.kind !== 'sec');
  const byPath = new Map<string, Entry[]>();
  for (const e of direct) { byPath.set(e.path, [...(byPath.get(e.path) || []), e]); }
  for (const [file, group] of byPath) {
    if (!fs.existsSync(file)) { continue; }
    const lines = readLines(file);
    const byLine = [...group].sort((a, b) => b.line - a.line);
    for (const e of byLine) {
      const at = e.line - 1;
      if (at >= lines.length || !isThere(lines[at], e)) { report.push(`! not found any more, left as it is: ${e.text}`); continue; }
      // A scenario inside a requirement that goes too: only the requirement.
      if (e.kind === 'scn') {
        const owner = byLine.filter(r => r.kind === 'req' && r.line < e.line).sort((a, b) => b.line - a.line)[0];
        if (owner && blockEnd(lines, owner.line - 1, 'req') > at) { continue; }
      }
      const end = blockEnd(lines, at, e.kind);
      lines.splice(at, end - at);
      report.push(`- ${KIND_WORD[e.kind]} ${e.text} (${e.where})`);
    }
    if (/[\\/]changes[\\/].+[\\/]specs[\\/]/.test(file)) {
      // Sections left empty: their headings out.
      for (let i = lines.length - 1; i >= 0; i--) {
        if (!/^##\s+\w+\s+Requirements\s*$/.test(lines[i])) { continue; }
        let j = i + 1;
        while (j < lines.length && !/^##\s/.test(lines[j])) { if (/^###\s/.test(lines[j])) { break; } j++; }
        if (j >= lines.length || /^##\s/.test(lines[j])) { lines.splice(i, j - i); }
      }
      if (!lines.some(l => /^###\s/.test(l))) {
        fs.rmSync(file, { force: true });
        const dir = path.dirname(file);
        if (!fs.readdirSync(dir).length) { fs.rmdirSync(dir); }
        report.push(`- the delta spec ${path.basename(dir)} of ${path.basename(path.dirname(path.dirname(dir)))}: nothing left, deleted`);
        continue;
      }
    }
    writeLines(file, lines);
  }
  if (main.length) { report.push(`+ the change ${newRemovalChange(p, main)}: their removal from the main specs (REMOVED, MODIFIED); archive it to apply it`); }
  return report;
}
function freeChangeName(p: Project, base: string): string {
  let name = base, n = 1;
  while (fs.existsSync(path.join(p.osDir, 'changes', name))) { n++; name = `${base}-${n}`; }
  return name;
}
function write(file: string, text: string) { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, text, 'utf8'); }
export function newRemovalChange(p: Project, entries: Entry[]): string {
  const name = freeChangeName(p, `remove-from-specs-${today()}`);
  const dir = path.join(p.osDir, 'changes', name);
  const what: string[] = [];
  const bySpec = new Map<string, Entry[]>();
  for (const e of entries) { bySpec.set(e.item.name, [...(bySpec.get(e.item.name) || []), e]); }
  for (const [specName, group] of bySpec) {
    const spec = group[0].item;
    const lines = readLines(spec.type === 'spec' ? spec.path : group[0].path);
    const removed = group.filter(e => e.kind === 'req').map(e => e.text);
    let sb = '';
    if (removed.length) {
      sb += '## REMOVED Requirements\n\n';
      for (const r of removed) {
        sb += `### Requirement: ${r}\n**Reason**: No longer wanted (marked for removal in LazySpec).\n**Migration**: None.\n\n`;
        what.push(`- **REMOVED** \`${specName}\`: ${r}`);
      }
    }
    // A requirement losing scenarios: MODIFIED, the whole requirement without them.
    const mods = new Map<string, Entry[]>();
    for (const e of group.filter(x => x.kind === 'scn' && !removed.includes(x.context))) { mods.set(e.context, [...(mods.get(e.context) || []), e]); }
    if (mods.size) { sb += '## MODIFIED Requirements\n\n'; }
    for (const [req, scns] of mods) {
      const at = lines.findIndex(l => { const m = /^###\s+(?:Requirement|Zahtjev|Anforderung):\s*(.+?)\s*$/.exec(l); return !!m && plainInline(m[1]) === req; });
      if (at < 0) { continue; }
      const block = lines.slice(at, blockEnd(lines, at, 'req'));
      for (const e of [...scns].sort((a, b) => b.line - a.line)) {
        const k = e.line - 1 - at;
        if (k <= 0 || k >= block.length) { continue; }
        block.splice(k, blockEnd(block, k, 'scn') - k);
      }
      sb += block.join('\n').trimEnd() + '\n\n';
      what.push(`- **MODIFIED** \`${specName}\`: ${req} (without the scenarios ${scns.map(s => s.text).join(', ')})`);
    }
    write(path.join(dir, 'specs', specName, 'spec.md'), sb.trimEnd() + '\n');
  }
  const specs = [...new Set(entries.map(e => e.item.name))].sort().join(', ');
  write(path.join(dir, 'proposal.md'), `# Proposal: Remove from the specs\n\n## Why\nThese requirements and scenarios are no longer wanted (marked for removal in LazySpec on ${today('-')}).\n\n## What Changes\n${what.join('\n')}\n\n## Impact\n- Specs: ${specs}.\n`);
  write(path.join(dir, 'tasks.md'), '# Tasks\n\n## 1. Removal\n- [ ] 1.1 Remove from the code what only the removed requirements and scenarios needed, if anything\n');
  return name;
}

// --- edit --------------------------------------------------------------------------------------------------

/** The edited lines in place of the item's (where it was; else where its lines are now). */
export function writeItemEdit(file: string, line: number, orig: string[], edited: string[]) {
  const lines = readLines(file);
  const match = (at: number) => at >= 0 && at + orig.length <= lines.length && orig.every((o, k) => lines[at + k] === o);
  let at = line - 1;
  if (!match(at)) { at = lines.findIndex((_, i) => match(i)); }
  if (at < 0) { throw new Error(`${path.basename(file)} changed meanwhile: the item isn't there as it was`); }
  lines.splice(at, orig.length, ...edited);
  writeLines(file, lines);
}
/** A main spec's requirement (or one of its scenarios) edited through a change: its whole requirement, as
 *  edited ($edited: the item's lines; default as it is), under MODIFIED Requirements in a new change. */
export function newModifyChange(p: Project, e: Entry, edited?: string[]): { name: string; file: string } {
  const lines = readLines(e.path);
  const at = e.line - 1;
  let reqAt = at;
  if (e.kind === 'scn') { for (let i = at; i >= 0; i--) { if (/^###\s/.test(lines[i])) { reqAt = i; break; } } }
  const req = lines.slice(reqAt, blockEnd(lines, reqAt, 'req'));
  if (edited) {
    const orig = itemBlock(e);
    if (orig) { req.splice(at - reqAt, orig.lines.length, ...edited); }
  }
  const title = req[0].replace(/^###\s+(Requirement|Zahtjev|Anforderung):\s*/, '').trim();
  const name = freeChangeName(p, `modify-specs-${today()}`);
  const dir = path.join(p.osDir, 'changes', name);
  const file = path.join(dir, 'specs', e.item.name, 'spec.md');
  write(file, `## MODIFIED Requirements\n\n${req.join('\n').trimEnd()}\n`);
  write(path.join(dir, 'proposal.md'), `# Proposal: Change the specs\n\n## Why\nA requirement of the specs edited in LazySpec on ${today('-')}.\n\n## What Changes\n- **MODIFIED** \`${e.item.name}\`: ${title}\n\n## Impact\n- Specs: ${e.item.name}.\n`);
  write(path.join(dir, 'tasks.md'), `# Tasks\n\n## 1. Change\n- [ ] 1.1 Make the code match the changed requirement ${title}\n`);
  return { name, file };
}
/** A task's text changed (its box and number kept). */
export function setTaskText(file: string, line: number, text: string) {
  const lines = readLines(file);
  const m = /^(\s*[-*]\s+\[[ xX]\]\s+)(.*)$/.exec(lines[line - 1] || '');
  if (!m) { throw new Error('This task is not there any more.'); }
  lines[line - 1] = m[1] + text;
  writeLines(file, lines);
}

// --- the agent's prompts -----------------------------------------------------------------------------------

/** The prompt for change (with your note) and redo: each item, where it is, as it is now. */
export function revisionPrompt(p: Project, entries: Entry[], action: 'change' | 'redo', note: string): string {
  let sb = `# LazySpec: revise ${entries.length} item(s) of the OpenSpec documents\n\nProject root: the current folder. OpenSpec documents: openspec/.\n\n## What to do\n\n`;
  if (action === 'change') { sb += `Change each item below as this note says:\n\n> ${note.replace(/\n/g, '\n> ')}\n\n`; }
  else { sb += 'Write again each item below so that it matches the current specs, proposal and design of its change (keep its number and its place).\n\n'; }
  sb += '## Rules\n\n';
  sb += '- Keep every document in its OpenSpec format; for a change, `openspec instructions <artifact> --change <change>` gives its template and rules.\n';
  sb += '- A requirement or scenario in openspec/specs/ (the main specs) is not edited there: make the edit in a change\'s delta spec (## MODIFIED Requirements with the whole requirement), in a change about it (a new one if none fits).\n';
  sb += '- A task already done ([x]) stays done unless the note says otherwise.\n';
  sb += '- Then run `openspec validate --all --strict --no-interactive` and fix what it reports.\n\n## Items\n';
  entries.forEach((e, i) => {
    const lines = readLines(e.path);
    const at = Math.min(e.line - 1, lines.length - 1);
    const end = blockEnd(lines, at, e.kind);
    sb += `\n### ${i + 1}. ${KIND_WORD[e.kind]} "${e.text}"\n\n- File: ${relPath(p.root, e.path)} (line ${e.line})\n- In: ${e.where}`;
    if (e.cap) { sb += `, capability ${e.cap}`; }
    if (e.context && (e.kind === 'task' || e.kind === 'scn')) { sb += `, ${e.kind === 'task' ? 'group' : 'requirement'} ${e.context}`; }
    sb += `\n\nNow:\n\n\`\`\`markdown\n${lines.slice(at, end).join('\n').trimEnd()}\n\`\`\`\n`;
  });
  return sb;
}
/** Saved in .lazyspec/prompts/<time>-<name>.md; its path from the project's root. */
export function savePrompt(p: Project, name: string, prompt: string): string {
  const d = new Date();
  const stamp = `${today()}-${String(d.getHours()).padStart(2, '0')}${String(d.getMinutes()).padStart(2, '0')}${String(d.getSeconds()).padStart(2, '0')}`;
  const file = path.join(p.root, '.lazyspec', 'prompts', `${stamp}-${name}.md`);
  write(file, prompt);
  return relPath(p.root, file);
}
export function agentInstruction(rel: string): string { return `Read the file ${rel} and do exactly what it says.`; }

// --- out-of-date documents (.lazyspec/sync.json, as LazySpec keeps it) -------------------------------------------

export function textHash(t: string): string {
  return crypto.createHash('sha1').update(Buffer.from(t.replace(/\r/g, ''), 'utf8')).digest('hex').toUpperCase().slice(0, 16);
}
export function requirementBlocks(text: string): Record<string, string> {
  const map: Record<string, string> = {};
  const lines = text.replace(/\r/g, '').split('\n');
  lines.forEach((l, i) => {
    const m = /^###\s+(?:Requirement|Zahtjev|Anforderung):\s*(.+?)\s*$/.exec(l);
    if (m) { map[plainInline(m[1])] = lines.slice(i, blockEnd(lines, i, 'req')).join('\n').trimEnd(); }
  });
  return map;
}
interface Snap { hash: string; reqs: Record<string, string> }
type SyncState = Record<string, Record<string, { self: string; up: Record<string, Snap> }>>;
export interface Diff { file: string; mark: '+' | '~' | '-'; req: string; old: string; now: string }
export interface StaleDoc { doc: Change['docs'][number]; diffs: Diff[] }

function byName(a: string, b: string) { return a.toLowerCase() < b.toLowerCase() ? -1 : a.toLowerCase() > b.toLowerCase() ? 1 : 0; }
export function changeDeps(c: Change) {
  const deps: { doc: Change['docs'][number]; ups: string[] }[] = [];
  for (const d of c.docs) {
    if (!d.files.length || !d.requires.length) { continue; }
    const ups = c.docs.filter(x => d.requires.includes(x.id) && x.files.length).flatMap(x => x.files);
    if (ups.length) { deps.push({ doc: d, ups }); }
  }
  return deps;
}
function snapshot(p: Project, files: string[]): Record<string, Snap> {
  const up: Record<string, Snap> = {};
  for (const f of [...files].sort(byName)) { const t = readText(f); up[relPath(p.root, f)] = { hash: textHash(t), reqs: requirementBlocks(t) }; }
  return up;
}
function selfHash(files: string[]): string { return textHash([...files].sort(byName).map(readText).join('\n')); }
function syncFile(p: Project) { return path.join(p.root, '.lazyspec', 'sync.json'); }
function readState(p: Project): SyncState {
  try { const s = JSON.parse(readText(syncFile(p))); return s && typeof s === 'object' ? s : {}; } catch { return {}; }
}
function writeState(p: Project, s: SyncState) { write(syncFile(p), JSON.stringify(s, null, 2)); }
/** The active changes' out-of-date documents; the baselines of new or rewritten documents noted. Off: none. */
export function syncState(p: Project): Map<string, StaleDoc[]> {
  const stale = new Map<string, StaleDoc[]>();
  if (p.config.values['syncCheck'] === 'off') { return stale; }
  const state = readState(p);
  let changed = false;
  for (const c of p.changes.filter(x => !x.archived)) {
    const rec = state[c.name] || (state[c.name] = {});
    for (const dep of changeDeps(c)) {
      const self = selfHash(dep.doc.files);
      const now = snapshot(p, dep.ups);
      const old = rec[dep.doc.id];
      if (!old || old.self !== self) { rec[dep.doc.id] = { self, up: now }; changed = true; continue; }
      const diffs: Diff[] = [];
      const was = old.up || {};
      for (const rel of [...new Set([...Object.keys(was), ...Object.keys(now)])].sort(byName)) {
        const a = was[rel], b = now[rel];
        if (a && b && a.hash === b.hash) { continue; }
        const ra = (a && a.reqs) || {}, rb = (b && b.reqs) || {};
        let n = 0;
        for (const k of Object.keys(ra)) {
          if (!(k in rb)) { diffs.push({ file: rel, mark: '-', req: k, old: ra[k], now: '' }); n++; }
          else if (rb[k] !== ra[k]) { diffs.push({ file: rel, mark: '~', req: k, old: ra[k], now: rb[k] }); n++; }
        }
        for (const k of Object.keys(rb)) { if (!(k in ra)) { diffs.push({ file: rel, mark: '+', req: k, old: '', now: rb[k] }); n++; } }
        if (!n) { diffs.push({ file: rel, mark: !a ? '+' : !b ? '-' : '~', req: '', old: '', now: '' }); }
      }
      if (diffs.length) { stale.set(c.name, [...(stale.get(c.name) || []), { doc: dep.doc, diffs }]); }
    }
  }
  if (changed) { writeState(p, state); }
  return stale;
}
/** A change's documents marked as in sync: each as it is now (self), against what it's written from - as that is
 *  now, or ($snap: document id -> its snapshot, from a sync prompt) as it was when the agent got the prompt; then
 *  only the snapshot's documents, the others as they were noted. (LazySpec's Set-InSync.) */
export function setInSync(p: Project, c: Change, snap?: Record<string, Record<string, Snap>>) {
  const state = readState(p);
  const rec: SyncState[string] = snap && state[c.name] ? state[c.name] : {};
  for (const dep of changeDeps(c)) {
    if (snap && !(dep.doc.id in snap)) { continue; }
    rec[dep.doc.id] = { self: selfHash(dep.doc.files), up: snap ? snap[dep.doc.id] : snapshot(p, dep.ups) };
  }
  state[c.name] = rec;
  writeState(p, state);
}

// A sync prompt's snapshot (<prompt>.sync.json, as LazySpec writes it): the change; each of its documents written
// from others, with its own hash and what it's written from, both as they are now (stale: the out-of-date ones
// the prompt names); asked: the files of those (what the agent is to update).
interface SyncSnapshot { change: string; prompt: string; asked: string[]; docs: Record<string, { self: string; stale: boolean; up: Record<string, Snap> }> }
export function saveSyncSnapshot(p: Project, c: Change, stale: StaleDoc[], promptRel: string, many = false): string {
  const staleIds = stale.map(s => s.doc.id);
  const docs: SyncSnapshot['docs'] = {};
  const asked: string[] = [];
  for (const dep of changeDeps(c)) {
    const isStale = staleIds.includes(dep.doc.id);
    docs[dep.doc.id] = { self: selfHash(dep.doc.files), stale: isStale, up: snapshot(p, dep.ups) };
    if (isStale) { asked.push(...dep.doc.files.map(f => relPath(p.root, f))); }
  }
  // Several changes in one prompt: a snapshot each (<prompt>.<change>.sync.json).
  const file = path.join(p.root, promptRel.replace(/\.md$/i, many ? `.${c.name}.sync.json` : '.sync.json'));
  write(file, JSON.stringify({ change: c.name, prompt: promptRel, asked, docs }, null, 2));
  return file;
}
export function readSyncSnapshot(file: string): SyncSnapshot | null {
  try { const s = JSON.parse(readText(file)); return s && s.change && s.docs ? s : null; } catch { return null; }
}
/** The agent done: its change marked as in sync against the prompt's snapshot - what each document is written
 *  from as it was then, but the files the agent was to update as they are now (its own work doesn't put the
 *  documents written from them out of date; a spec edited meanwhile does); the snapshot used up. Its name. */
export function setInSyncFromFile(p: Project, file: string): string {
  const s = readSyncSnapshot(file);
  if (!s) { return ''; }
  p.load();
  const c = p.changes.find(x => x.name === s.change && !x.archived);
  if (!c) { return ''; }
  const asked = s.asked || [];
  const snap: Record<string, Record<string, Snap>> = {};
  for (const [id, d] of Object.entries(s.docs)) {
    const up: Record<string, Snap> = {};
    for (const [rel, v] of Object.entries(d.up || {})) {
      if (asked.includes(rel)) { const f = path.join(p.root, rel); if (fs.existsSync(f)) { Object.assign(up, snapshot(p, [f])); } }
      else { up[rel] = v; }
    }
    snap[id] = up;
  }
  setInSync(p, c, snap);
  fs.rmSync(file, { force: true });
  p.load();
  return s.change;
}
/** Sync prompts saved for later (s) and given to the agent outside: a document they name changed since, and
 *  the change still out of date (one it rightly left as it was) - the snapshot files to offer to mark. */
export function doneSyncPrompts(p: Project, stale: Map<string, StaleDoc[]>): string[] {
  const dir = path.join(p.root, '.lazyspec', 'prompts');
  let files: string[] = [];
  try { files = fs.readdirSync(dir).filter(f => f.endsWith('.sync.json')).sort().map(f => path.join(dir, f)); } catch { return []; }
  return files.filter(f => {
    const s = readSyncSnapshot(f);
    const c = s && p.changes.find(x => x.name === s.change && !x.archived);
    if (!s || !c || !stale.has(s.change)) { return false; }
    return Object.entries(s.docs).some(([id, d]) => {
      const doc = c.docs.find(x => x.id === id);
      return d.stale && doc && selfHash(doc.files) !== d.self;
    });
  });
}
/** Several changes brought up to date in one go: each change's prompt, one after the other. */
export function syncPromptMany(p: Project, items: { change: Change; stale: StaleDoc[] }[]): string {
  if (items.length === 1) { return syncPrompt(p, items[0].change, items[0].stale); }
  return `# LazySpec: bring documents of ${items.length} changes up to date\n\nDo each part below, one change after the other: ${items.map(i => i.change.name).join(', ')}.\n\n`
    + items.map(i => syncPrompt(p, i.change, i.stale)).join('\n---\n\n');
}
export function syncPrompt(p: Project, c: Change, stale: StaleDoc[]): string {
  let sb = `# LazySpec: bring documents of the change ${c.name} up to date\n\nProject root: the current folder. The change: openspec/changes/${c.name}/.\n\n`;
  for (const st of stale) {
    sb += `## ${st.doc.files.map(f => relPath(p.root, f)).join(', ')}\n\nIt was written before these changed:\n\n`;
    for (const d of st.diffs) {
      const what = { '+': 'added', '~': 'changed', '-': 'removed' }[d.mark];
      sb += d.req ? `- ${d.file}: requirement "${d.req}" ${what}\n` : `- ${d.file}: ${what}\n`;
    }
    sb += `\nUpdate it so that it matches them: add what's new, change what changed, take out what was removed. A task already done ([x]) whose requirement was removed or changed: don't delete it, keep it and add \` (review: its requirement changed)\` to its text. Keep the numbering, the groups and the document's OpenSpec format (\`openspec instructions ${st.doc.id} --change ${c.name}\`).\n`;
    const shown = st.diffs.filter(d => d.req);
    if (shown.length) {
      sb += '\n### The requirements, before and now\n';
      for (const d of shown) {
        sb += `\n#### ${d.mark} ${d.req} (${d.file})\n`;
        if (d.old) { sb += `\nBefore:\n\n\`\`\`markdown\n${d.old}\n\`\`\`\n`; }
        if (d.now) { sb += `\nNow:\n\n\`\`\`markdown\n${d.now}\n\`\`\`\n`; }
      }
    }
    sb += '\n';
  }
  return sb + `Then run \`openspec validate ${c.name} --strict --no-interactive\` and fix what it reports.\n`;
}

// --- config.yaml: LazySpec's own keys (the rest of the file as it is) ---------------------------------------------

function configLines(p: Project) {
  const file = path.join(p.osDir, 'config.yaml');
  let raw = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  const bom = raw.charCodeAt(0) === 0xfeff;
  if (bom) { raw = raw.slice(1); }
  const nl = raw.includes('\r\n') ? '\r\n' : '\n';
  const lines = raw ? raw.replace(/\r/g, '').split('\n') : [];
  const endsNl = lines.length > 0 && lines[lines.length - 1] === '';
  if (endsNl) { lines.pop(); }
  const save = () => { let t = lines.join(nl); if (endsNl) { t += nl; } fs.writeFileSync(file, (bom ? '\ufeff' : '') + t, 'utf8'); };
  return { lines, save };
}
const indentOf = (l: string) => l.length - l.trimStart().length;
/** The lazyspec: block (made at the end when it isn't there): its start, end, key indent. */
function lazyBlock(lines: string[], make: boolean) {
  let start = lines.findIndex(l => /^lazyspec:\s*(#.*)?$/.test(l));
  if (start < 0) {
    if (!make) { return null; }
    while (lines.length && !lines[lines.length - 1].trim()) { lines.pop(); }
    if (lines.length) { lines.push(''); }
    lines.push('lazyspec:'); start = lines.length - 1;
  }
  let end = lines.length;
  for (let i = start + 1; i < lines.length; i++) { const l = lines[i]; if (l.trim() && !l.trimStart().startsWith('#') && indentOf(l) === 0) { end = i; break; } }
  let ki = 2;
  for (let i = start + 1; i < end; i++) { if (lines[i].trim() && indentOf(lines[i]) > 0) { ki = indentOf(lines[i]); break; } }
  let last = start;
  for (let i = start + 1; i < end; i++) { if (lines[i].trim() && indentOf(lines[i]) > 0) { last = i; } }
  return { start, end, ki, last };
}
/** "key: value" straight under lazyspec: (replaced when it's there): agent:, syncCheck: ... */
export function setConfigValue(p: Project, key: string, value: string) {
  const { lines, save } = configLines(p);
  const b = lazyBlock(lines, true)!;
  const line = ' '.repeat(b.ki) + `${key}: ${value}`;
  const rx = new RegExp('^' + ' '.repeat(b.ki) + key.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ':');
  const at = lines.slice(b.start + 1, b.end).findIndex(l => rx.test(l));
  if (at >= 0) { lines[b.start + 1 + at] = line; } else { lines.splice(b.last + 1, 0, line); }
  save();
}
/** A saved whole under lazyspec: bundles: (replaced when it's there); no changes nor groups: removed. */
export function setConfigBundle(p: Project, id: string, title: string, changes: string[], groups: string[] = []) {
  const { lines, save } = configLines(p);
  const any = changes.length > 0 || groups.length > 0;
  const blk = lazyBlock(lines, any);
  if (!blk) { return; }
  const { start, end, ki, last } = blk;
  const u = ' '.repeat(ki);
  let b = -1;
  for (let i = start + 1; i <= last; i++) { if (new RegExp(`^${u}bundles:\\s*(#.*)?$`).test(lines[i])) { b = i; break; } }
  let bEnd: number;
  if (b < 0) {
    if (!any) { return; }
    lines.splice(last + 1, 0, `${u}bundles:`); b = last + 1; bEnd = b + 1;
  } else {
    bEnd = b + 1;
    for (let i = b + 1; i < end; i++) { const l = lines[i]; if (!l.trim()) { continue; } if (indentOf(l) <= ki) { break; } bEnd = i + 1; }
    for (let i = b + 1; i < bEnd; i++) {
      const m = /^(\s+)("[^"]*"|'[^']*'|[^:#]+?):\s*(#.*)?$/.exec(lines[i]);
      if (!m || m[2].replace(/^["']|["']$/g, '').trim() !== id) { continue; }
      let j = i + 1;
      while (j < bEnd && (!lines[j].trim() || indentOf(lines[j]) > m[1].length)) { j++; }
      lines.splice(i, j - i); bEnd -= j - i;
      break;
    }
  }
  if (any) {
    const entry = [`${u}${u}${id}:`, `${u}${u}${u}title: "${title.replace(/"/g, "'")}"`];
    entry.push(groups.length ? `${u}${u}${u}groups: ${groups.join(', ')}` : `${u}${u}${u}changes: ${changes.join(', ')}`);
    lines.splice(bEnd, 0, ...entry);
  } else if (!lines.slice(b + 1, bEnd).some(l => l.trim())) { lines.splice(b, 1); }
  save();
}
/** A name for a key or a file: lowercase, without accents, words joined by hyphens. */
export function slug(text: string): string {
  return text.toLowerCase().normalize('NFD').replace(/\p{Mn}/gu, '').replace(/đ/g, 'd').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

// --- undo: what changed in openspec/ since the last commit ---------------------------------------------------------

export function git(root: string, args: string[]): { code: number; out: string } {
  try {
    const out = cp.execFileSync('git', ['-c', 'core.quotepath=off', ...args], { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], maxBuffer: 64 * 1024 * 1024, windowsHide: true });
    return { code: 0, out };
  } catch (e) {
    const err = e as { status?: number; stdout?: string };
    return { code: typeof err.status === 'number' ? err.status : -1, out: err.stdout || '' };
  }
}
export interface Hunk { rel: string; oldStart: number; newStart: number; lines: string[] }
export interface UndoFile { rel: string; kind: 'changed' | 'new' | 'deleted'; hunks: Hunk[] }
/** Every file changed in openspec/ (not the exports) and its pieces (hunks of the diff against HEAD); null: no git. */
export function undoRows(root: string): UndoFile[] | null {
  const st = git(root, ['status', '--porcelain=v1', '--untracked-files=all', '--', 'openspec', ':(exclude)openspec/exports']);
  if (st.code !== 0) { return null; }
  const files: UndoFile[] = [];
  for (const line of st.out.replace(/\r/g, '').split('\n').filter(l => l.length > 3)) {
    const code = line.slice(0, 2);
    let rel = line.slice(3).replace(/^"|"$/g, '');
    const mv = / -> (.+)$/.exec(rel);
    if (mv) { rel = mv[1]; }
    const kind: UndoFile['kind'] = code === '??' || code.includes('A') ? 'new' : code.includes('D') ? 'deleted' : 'changed';
    const f: UndoFile = { rel, kind, hunks: [] };
    files.push(f);
    if (kind !== 'changed') { continue; }
    let cur: Hunk | null = null;
    for (const l of git(root, ['diff', '--no-color', '--no-ext-diff', '-U2', 'HEAD', '--', rel]).out.replace(/\r/g, '').split('\n')) {
      const m = /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/.exec(l);
      if (m) { cur = { rel, oldStart: +m[1], newStart: +m[3], lines: [] }; f.hunks.push(cur); continue; }
      if (cur && l.length && ' -+'.includes(l[0]) && !l.startsWith('--- ') && !l.startsWith('+++ ')) { cur.lines.push(l); }
    }
  }
  return files;
}
/** A piece in one line: what it removed or added (its first such line), and how much. */
export function hunkSummary(h: Hunk): { minus: number; plus: number; text: string } {
  const minus = h.lines.filter(l => l.startsWith('-')).length;
  const plus = h.lines.filter(l => l.startsWith('+')).length;
  const first = h.lines.find(l => (l.startsWith('-') || l.startsWith('+')) && l.slice(1).trim());
  const text = first ? plainInline(first.slice(1).trim().replace(/^[-*]\s+\[[ xX]\]\s+/, '').replace(/^#+\s+/, '')) : '';
  return { minus, plus, text };
}
/** Undoes a piece: where its new side is in the file now (at its place, else found nearby), its old side again. */
export function undoHunk(root: string, h: Hunk) {
  const file = path.join(root, h.rel);
  const raw = fs.readFileSync(file, 'utf8');
  const nl = raw.includes('\r\n') ? '\r\n' : '\n';
  const endsNl = raw.endsWith('\n');
  const lines = raw.replace(/\r/g, '').split('\n');
  if (endsNl) { lines.pop(); }
  const now = h.lines.filter(l => !l.startsWith('-')).map(l => l.slice(1));
  const was = h.lines.filter(l => !l.startsWith('+')).map(l => l.slice(1));
  const match = (at: number) => at >= 0 && at + now.length <= lines.length && now.every((x, k) => lines[at + k] === x);
  let at = now.length ? h.newStart - 1 : h.newStart;
  if (!match(at)) {
    at = -1;
    for (let d = 1; d < lines.length && at < 0; d++) { for (const c of [h.newStart - 1 - d, h.newStart - 1 + d]) { if (match(c)) { at = c; break; } } }
  }
  if (at < 0) { throw new Error(`${h.rel} changed since: this piece isn't there as it was`); }
  lines.splice(at, now.length, ...was);
  fs.writeFileSync(file, lines.join(nl) + (endsNl ? nl : ''), 'utf8');
}
/** A whole file as it was committed; a new one deleted (and its folders left empty, up to openspec/). */
export function undoFile(root: string, f: UndoFile) {
  const file = path.join(root, f.rel);
  if (f.kind === 'new') {
    fs.rmSync(file, { force: true });
    const os = path.join(root, 'openspec');
    let dir = path.dirname(file);
    while (dir.length > os.length && fs.existsSync(dir) && !fs.readdirSync(dir).length) { fs.rmdirSync(dir); dir = path.dirname(dir); }
    return;
  }
  if (git(root, ['checkout', 'HEAD', '--', f.rel]).code !== 0) { throw new Error(`git couldn't put ${f.rel} back`); }
}

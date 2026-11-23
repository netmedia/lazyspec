// LazySpec for VS Code (and Cursor, Windsurf ...): a project's OpenSpec in the editor, everything LazySpec's
// terminal UI does. The Plan and the Scope as trees, the selected one's details, Read (formatted, its items
// to edit, tick, delete, hand to the agent), find, out-of-date documents, undo, changes and groups as one;
// validate, new change and archive through the OpenSpec CLI; exports through LazySpec's lazyspec.ps1.

import * as cp from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { answer, agentTask, offerDoneSync, onSynced, runningSyncs, showAgentOutput, stopAgent, syncingChanges } from './agent';
import { DetailsView, Selected } from './details';
import { editItemFormatted, FormattedEditorProvider } from './formatted';
import { showHelp } from './help';
import { agentItems, deleteItems, editItem, ItemContext, openBlock, toggleTask } from './items';
import { Change, Entry, find, FindKind, idLabel, itemTitle, Project, searchIndex, Spec } from './model';
import { doneSyncPrompts, saveSyncSnapshot, setConfigBundle, setConfigValue, setInSync, slug, StaleDoc, syncPromptMany, syncState } from './ops';
import { ReadPanel, ReadTarget } from './read';
import { entryOf, Node, PlanTree, ScopeTree, Settings } from './tree';
import { HeadContent, showUndo, undo, UndoNode, UndoTree } from './undo';

/** A target from a menu (a tree node), the details' buttons ({ type, root, name }), or nothing. */
interface Ref { type: 'change' | 'spec' | 'group'; root: string; name: string; path?: string }

let projects: Project[] = [];
let output: vscode.OutputChannel;
let ctx: vscode.ExtensionContext;
const stale = new Map<string, Map<string, StaleDoc[]>>();
const syncAsked = new Set<string>();
const syncOffered = new Set<string>();

function settings(): Settings {
  const c = vscode.workspace.getConfiguration('lazyspec');
  return { grouped: c.get('grouped', true), showArchived: c.get('showArchived', false), sort: c.get('sort', 'name'), documents: c.get('documents', 'formatted') };
}

// --- the workspace's projects -----------------------------------------------------------------------------------

const SKIP = new Set(['node_modules', 'out', 'dist', 'bin', 'obj', 'build', 'target', 'vendor', 'kit']);
/** Folders below $dir (up to $depth levels) with an openspec folder that has config.yaml, specs or changes. */
function findDeeper(dir: string, depth: number, out: string[]) {
  if (depth <= 0) { return; }
  let entries: fs.Dirent[] = [];
  try { entries = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of entries) {
    if (!e.isDirectory() || e.name.startsWith('.') || SKIP.has(e.name) || e.name === 'openspec') { continue; }
    const sub = path.join(dir, e.name);
    const os = path.join(sub, 'openspec');
    if (['config.yaml', 'specs', 'changes'].some(x => fs.existsSync(path.join(os, x)))) { out.push(sub); continue; }
    findDeeper(sub, depth - 1, out);
  }
}
/** The workspace's projects: its folders with an openspec folder, lazyspec.roots below them; a folder
 *  without one at its top: the ones up to three levels below it (a monorepo, apps/portal, examples/...). */
function findProjects(): Project[] {
  const roots: string[] = [];
  const extra = vscode.workspace.getConfiguration('lazyspec').get<string[]>('roots', []);
  for (const f of vscode.workspace.workspaceFolders || []) {
    const base = f.uri.fsPath;
    for (const r of [base, ...extra.map(e => path.resolve(base, e))]) {
      if (Project.isProject(r) && !roots.includes(r)) { roots.push(r); }
    }
    if (!roots.some(r => r === base || r.startsWith(base + path.sep))) {
      const deeper: string[] = [];
      findDeeper(base, 3, deeper);
      for (const r of deeper.sort()) { if (!roots.includes(r)) { roots.push(r); } }
    }
  }
  return roots.map(r => {
    try { return new Project(r).load(); }
    catch (e) { output.appendLine(`${r}: ${(e as Error).message}`); return new Project(r); }
  });
}
function projectOf(root: string | undefined): Project | undefined {
  if (!root) { return projects.length === 1 ? projects[0] : undefined; }
  return projects.find(p => p.root === root);
}
function projectOfFile(file: string): Project | undefined {
  return projects.filter(p => file.toLowerCase().startsWith(p.root.toLowerCase() + path.sep)).sort((a, b) => b.root.length - a.root.length)[0];
}
async function pickProject(arg?: { root?: string }): Promise<Project | undefined> {
  if (arg?.root) { return projectOf(arg.root); }
  if (projects.length <= 1) { return projects[0]; }
  const p = await vscode.window.showQuickPick(projects.map(x => ({ label: x.name, description: x.root, project: x })), { placeHolder: 'Which project?' });
  return p?.project;
}
function staleOf(p: Project, c: Change): StaleDoc[] | undefined {
  if (p.config.values['syncCheck'] !== 'on') { return undefined; }
  return stale.get(p.root)?.get(c.name);
}

// --- LazySpec's script, PowerShell, the OpenSpec CLI ------------------------------------------------------------

/** lazyspec.ps1: the setting's, else the project's own (tools/lazyspec), else the one in this extension. */
function kitScript(p?: Project): string {
  const set = vscode.workspace.getConfiguration('lazyspec').get<string>('script', '');
  if (set) { return set; }
  if (p) {
    const own = path.join(p.root, 'tools', 'lazyspec', 'lazyspec.ps1');
    if (fs.existsSync(own)) { return own; }
  }
  return ctx.asAbsolutePath(path.join('kit', 'lazyspec.ps1'));
}
function powershell(): string {
  return vscode.workspace.getConfiguration('lazyspec').get<string>('powershell', '') || (process.platform === 'win32' ? 'powershell.exe' : 'pwsh');
}
function psArgs(script: string, args: string[]): string[] {
  return ['-NoProfile', ...(process.platform === 'win32' ? ['-ExecutionPolicy', 'Bypass'] : []), '-File', script, ...args];
}
/** The OpenSpec CLI in a terminal of the project (its output there, as you'd run it). */
function runCli(p: Project, args: string[], title: string) {
  const cli = vscode.workspace.getConfiguration('lazyspec').get<string>('openspec', 'openspec');
  const name = projects.length > 1 ? `OpenSpec: ${p.name}` : 'OpenSpec';
  const t = vscode.window.terminals.find(x => x.name === name) || vscode.window.createTerminal({ name, cwd: p.root });
  t.show();
  const q = (a: string) => (/^[\w./:=-]+$/.test(a) ? a : `"${a.replace(/"/g, '\\"')}"`);
  output.appendLine(`${title}: ${cli} ${args.join(' ')}`);
  t.sendText([cli, ...args].map(q).join(' '));
}

// --- export -----------------------------------------------------------------------------------------------

/** lazyspec.ps1 -Export, its output in the LazySpec channel; then open the document. */
async function runExport(p: Project | undefined, args: string[], what: string, cwd?: string) {
  const script = kitScript(p);
  const ps = powershell();
  const all = psArgs(script, [...(p ? ['-Root', p.root] : []), ...args]);
  output.appendLine('');
  output.appendLine(`> ${ps} ${all.join(' ')}`);
  let written = '';
  const code = await vscode.window.withProgress({ location: vscode.ProgressLocation.Notification, title: `LazySpec: exporting ${what}`, cancellable: true }, (progress, token) =>
    new Promise<number>(resolve => {
      let child: cp.ChildProcess;
      // No stdin: PowerShell would wait on it.
      try { child = cp.spawn(ps, all, { cwd: cwd || p?.root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] }); }
      catch (e) { output.appendLine(String(e)); resolve(-1); return; }
      token.onCancellationRequested(() => { child.kill(); });
      const onData = (b: Buffer) => {
        const t = b.toString('utf8');
        output.append(t);
        for (const l of t.split(/\r?\n/)) {
          const m = /Written:\s*(.+?)\s*$/.exec(l);
          if (m) { written = m[1]; }
          else if (/^\s*\S/.test(l)) { progress.report({ message: l.replace(/^[\s›>]+/, '').slice(0, 80) }); }
        }
      };
      child.stdout?.on('data', onData);
      child.stderr?.on('data', onData);
      child.on('error', e => { output.appendLine(`${ps}: ${e.message}`); resolve(-1); });
      child.on('close', c => resolve(c ?? -1));
    }));
  if (code === 0 && written) {
    const open = await vscode.window.showInformationMessage(`Written: ${path.basename(written)}`, 'Open', 'Show in Folder');
    if (open === 'Open') { await vscode.env.openExternal(vscode.Uri.file(written)); }
    if (open === 'Show in Folder') { await vscode.commands.executeCommand('revealFileInOS', vscode.Uri.file(written)); }
    return;
  }
  const more = code === -1 ? ` (${ps} isn't there? Set lazyspec.powershell; PowerShell 7: https://aka.ms/powershell)` : '';
  const pick = await vscode.window.showErrorMessage(`LazySpec: the export failed${more}.`, 'Show Output');
  if (pick) { output.show(); }
}
let exportLanguage = '';
/** The format and the audience (and the language, when asked for), then the export. */
async function exportAs(p: Project | undefined, args: string[], what: string, cwd?: string) {
  const f = await vscode.window.showQuickPick([
    { label: 'PDF', value: 'Pdf' }, { label: 'Word', value: 'Word' }, { label: 'HTML', value: 'Html' },
  ], { placeHolder: `Export ${what} as` });
  if (!f) { return; }
  const a = await vscode.window.showQuickPick([
    { label: 'The client', description: 'scenarios as sentences', value: true },
    { label: 'Technical', description: 'as written', value: false },
  ], { placeHolder: `${f.label} for` });
  if (!a) { return; }
  const lang = exportLanguage; exportLanguage = '';
  await runExport(p, ['-Export', f.value, ...(a.value ? ['-ClientFriendly'] : []), ...(lang ? ['-Language', lang] : []), ...args], what, cwd);
}
async function exportMenu(arg?: { root?: string }) {
  const p = await pickProject(arg);
  if (!p) { return; }
  type Item = vscode.QuickPickItem & { run: () => Promise<void> };
  const items: Item[] = [];
  const active = p.changes.filter(c => !c.archived);
  if (p.specs.length) {
    items.push({ label: '$(book) The specification', description: `${p.specs.length} specs`, run: () => exportAs(p, [], 'the specification') });
    if (active.length) { items.push({ label: '$(book) The specification and the plan', description: `${active.length} active changes after the specs`, run: () => exportAs(p, ['-IncludeChanges'], 'the specification and the plan') }); }
  }
  if (active.length) { items.push({ label: '$(git-pull-request) A change...', run: async () => { const c = await pickChange(p); if (c) { await exportAs(p, ['-Item', c.name], itemTitle(c)); } } }); }
  if (active.length > 1) { items.push({ label: '$(files) Chosen changes, as one...', description: 'a chapter per kind of document', run: async () => { const t = await chooseAsOne(p, 'export'); if (t) { await exportTarget(t); } } }); }
  if (p.grouping && p.config.groups.length) { items.push({ label: `$(layers) ${p.config.groupPlural}...`, description: 'with the ones they require', run: () => exportGroups({ root: p.root }) }); }
  for (const b of p.config.bundles) {
    items.push({ label: `$(package) ${b.title || b.id}`, description: `saved: ${b.groups.length ? `${p.config.groupPlural.toLowerCase()} ${b.groups.join(', ')}` : b.changes.join(', ')}`, run: () => exportAs(p, ['-Item', b.id], b.title || b.id) });
  }
  if (p.specs.length) { items.push({ label: '$(symbol-class) A spec...', run: async () => { const s = await vscode.window.showQuickPick(p.specs.map(x => ({ label: itemTitle(x), description: x.name, spec: x }))); if (s) { await exportAs(p, ['-Item', s.spec.name], s.label); } } }); }
  if (!items.length) { void vscode.window.showInformationMessage('Nothing to export yet: no specs and no active changes.'); return; }
  const pick = await vscode.window.showQuickPick(items, { placeHolder: `Export for the client${exportLanguage ? ` (in ${exportLanguage})` : ''}` });
  if (pick) { await pick.run(); } else { exportLanguage = ''; }
}
async function pickChange(p: Project, archived = false): Promise<Change | undefined> {
  const list = p.changes.filter(c => archived || !c.archived).sort((a, b) => a.name.localeCompare(b.name));
  const c = await vscode.window.showQuickPick(list.map(x => ({ label: itemTitle(x), description: x.name, detail: p.grouping && x.group ? p.groupTitle(x.group) : undefined, change: x })), { placeHolder: 'Which change?', matchOnDescription: true });
  return c?.change;
}
/** Groups chosen (the ones they require with them): their ids, or undefined. */
async function chooseGroups(p: Project, verb: string, preselect: string[] = []): Promise<string[] | undefined> {
  if (!p.config.groups.length && !p.grouping) { void vscode.window.showInformationMessage('This project has no groups (groups: in openspec/config.yaml, x-group: <id> in a change\'s .openspec.yaml).'); return undefined; }
  const counts = new Map(p.groups().map(g => [g.id, g]));
  const ids = [...new Set([...p.config.groups.map(g => g.id), ...[...counts.keys()].filter(k => k)])];
  const qp = vscode.window.createQuickPick<vscode.QuickPickItem & { id: string }>();
  qp.canSelectMany = true;
  qp.title = `${verb} ${p.config.groupPlural.toLowerCase()} (the ones they require come too)`;
  qp.items = ids.map(id => {
    const g = counts.get(id);
    const d = p.groupDef(id);
    return { id, label: p.groupTitle(id), description: g ? `${g.changes.length} changes, ${g.done}/${g.total}` : 'no active changes', detail: d?.requires.length ? `requires ${d.requires.map(r => p.groupTitle(r)).join(', ')}` : d?.description };
  });
  qp.selectedItems = qp.items.filter(i => preselect.includes(i.id));
  const note = () => {
    const sel = p.groupSelection(qp.selectedItems.map(i => i.id));
    qp.placeholder = sel.added.size ? `+ required: ${[...sel.added].map(r => p.groupTitle(r)).join(', ')}` : 'Choose the groups for the client';
  };
  qp.onDidChangeSelection(note);
  note();
  const chosen = await new Promise<string[] | undefined>(resolve => {
    qp.onDidAccept(() => { resolve(qp.selectedItems.map(i => i.id)); qp.hide(); });
    qp.onDidHide(() => resolve(undefined));
    qp.show();
  });
  qp.dispose();
  return chosen?.length ? chosen : undefined;
}
async function exportGroups(arg?: { root?: string; preselect?: string[] }) {
  const p = await pickProject(arg);
  if (!p) { return; }
  const chosen = await chooseGroups(p, 'Export', arg?.preselect);
  if (!chosen) { return; }
  const sel = p.groupSelection(chosen);
  await exportAs(p, ['-Groups', chosen.join(',')], sel.ids.map(i => p.groupTitle(i)).join(', '));
}
/** What Read shows, exported: the spec, the change, the saved whole by its key, groups, changes as one. */
async function exportTarget(t: ReadTarget) {
  if (t.kind === 'spec') { return exportAs(t.project, ['-Item', t.spec.name], itemTitle(t.spec)); }
  if (t.kind === 'change') { return exportAs(t.project, ['-Item', t.change.name], itemTitle(t.change)); }
  if (t.groups?.length && !t.id) { return exportAs(t.project, ['-Groups', t.groups.join(',')], t.title); }
  if (t.id) { return exportAs(t.project, ['-Item', t.id], t.title); }
  return exportAs(t.project, ['-Item', t.changes.map(c => c.name).join(','), ...(t.title ? ['-Title', t.title] : [])], t.title || `${t.changes.length} changes`);
}

// --- changes and groups as one (m in LazySpec) ------------------------------------------------------------------

/** A saved whole, or changes marked (a title; saved for next time?), as one. */
async function chooseAsOne(p: Project, verb: 'read' | 'export'): Promise<ReadTarget | undefined> {
  type Item = vscode.QuickPickItem & { v: string };
  const items: Item[] = p.config.bundles.map(b => ({ label: `$(package) ${b.title || b.id}`, description: b.groups.length ? `${p.config.groupPlural.toLowerCase()} ${b.groups.join(', ')}` : b.changes.join(', '), v: b.id }));
  items.push({ label: '$(checklist) Choose changes...', v: '' });
  const pick = items.length === 1 ? items[0] : await vscode.window.showQuickPick(items, { placeHolder: `Changes as one: a saved whole (openspec/config.yaml), or choose them (to ${verb})` });
  if (!pick) { return undefined; }
  const active = p.changes.filter(c => !c.archived);
  if (pick.v) {
    const b = p.config.bundles.find(x => x.id === pick.v)!;
    if (b.groups.length) {
      const ids = p.groupSelection(b.groups).ids;
      return { kind: 'bundle', project: p, title: b.title || b.id, changes: active.filter(c => ids.includes(c.group)).sort((a, x) => a.name.localeCompare(x.name)), id: b.id, groups: b.groups };
    }
    const changes = b.changes.map(n => p.changes.find(c => c.name === n || c.name.endsWith(`-${n}`))).filter((c): c is Change => !!c);
    if (!changes.length) { void vscode.window.showWarningMessage(`None of ${b.id}'s changes is in openspec/changes.`); return undefined; }
    return { kind: 'bundle', project: p, title: b.title || b.id, changes, id: b.id };
  }
  const picks = await vscode.window.showQuickPick(active.sort((a, b) => a.name.localeCompare(b.name)).map(x => ({ label: itemTitle(x), description: x.name, change: x })), { canPickMany: true, placeHolder: 'The changes that go to the client as one whole' });
  if (!picks?.length) { return undefined; }
  const changes = picks.map(x => x.change);
  if (changes.length === 1) { return { kind: 'change', project: p, change: changes[0] }; }
  const key = changes.map(c => c.name).sort().join(',');
  const same = p.config.bundles.find(b => [...b.changes].sort().join(',') === key);
  const title = await vscode.window.showInputBox({ prompt: 'Title of the whole (on the cover; empty: the changes\' titles)', value: same?.title || '' });
  if (title === undefined) { return undefined; }
  let id = same && same.title === title ? same.id : undefined;
  if (!id && title && slug(title)) {
    const save = await vscode.window.showQuickPick([{ label: 'Save it', description: `as '${slug(title)}' in openspec/config.yaml (lazyspec: bundles:)`, v: true }, { label: 'Not now', v: false }], { placeHolder: 'Save it as a whole for next time?' });
    if (save?.v) { setConfigBundle(p, slug(title), title, changes.map(c => c.name)); id = slug(title); reload(); }
  }
  return { kind: 'bundle', project: p, title: title || changes.map(c => c.title || c.name).join(', '), changes, id };
}
async function removeBundle(arg?: { root?: string }) {
  const p = await pickProject(arg);
  if (!p || !p.config.bundles.length) { void vscode.window.showInformationMessage('No saved wholes (lazyspec: bundles: in openspec/config.yaml).'); return; }
  const b = await vscode.window.showQuickPick(p.config.bundles.map(x => ({ label: x.title || x.id, description: x.id, id: x.id })), { placeHolder: 'Remove a saved whole from openspec/config.yaml' });
  if (!b) { return; }
  const ok = await vscode.window.showWarningMessage(`Remove the saved whole '${b.label}' from openspec/config.yaml?`, { modal: true }, 'Remove');
  if (ok) { setConfigBundle(p, b.id, '', []); reload(); }
}
function groupTarget(p: Project, ids: string[], withRequired: boolean): ReadTarget | undefined {
  const all = withRequired ? p.groupSelection(ids).ids : ids;
  const changes = p.changes.filter(c => !c.archived && all.includes(c.group)).sort((a, b) => a.name.localeCompare(b.name));
  if (!changes.length) { void vscode.window.showInformationMessage('No active changes in it.'); return undefined; }
  if (changes.length === 1) { return { kind: 'change', project: p, change: changes[0] }; }
  return { kind: 'bundle', project: p, title: all.map(i => p.groupTitle(i)).join(', '), changes, groups: ids, id: withRequired ? undefined : `group:${ids[0]}` };
}

// --- the target of a command ----------------------------------------------------------------------------------

function targetOf(arg: unknown): { project: Project; change?: Change; spec?: Spec; group?: string } | undefined {
  if (!arg) {
    const n = planView.selection[0] || scopeView.selection[0];
    if (n) { return targetOf(n); }
    const s = details.current();
    if (!s) { return undefined; }
    if (s.kind === 'change') { return { project: s.project, change: s.change }; }
    if (s.kind === 'spec') { return { project: s.project, spec: s.spec }; }
    return { project: s.project, group: s.id };
  }
  const n = arg as Node;
  if ('kind' in n) {
    if (n.kind === 'change' || n.kind === 'doc' || n.kind === 'cap' || n.kind === 'taskGroup' || n.kind === 'task' || n.kind === 'file') { return { project: n.project, change: n.change }; }
    if (n.kind === 'spec') { return { project: n.project, spec: n.spec }; }
    if (n.kind === 'group') { return { project: n.project, group: n.id }; }
    if (n.kind === 'req' || n.kind === 'scn' || n.kind === 'sec') { return n.owner.type === 'spec' ? { project: n.project, spec: n.owner } : { project: n.project, change: n.owner }; }
    return undefined;
  }
  const r = arg as Ref;
  const p = r.path ? projectOfFile(r.path) : projectOf(r.root);
  if (!p) { return undefined; }
  if (r.type === 'change') { const c = p.changes.find(x => x.name === r.name); return c ? { project: p, change: c } : undefined; }
  if (r.type === 'spec') { const s = p.specs.find(x => x.name === r.name); return s ? { project: p, spec: s } : undefined; }
  return { project: p, group: r.name };
}
/** The items a command is for: the clicked one with the others selected (a tree), else the tree's selection. */
function entriesOf(node?: Node, nodes?: Node[]): Entry[] {
  let list: readonly Node[] = nodes?.length ? nodes : node && 'kind' in node ? [node] : [];
  if (!list.length) { list = planView.selection.length ? planView.selection : scopeView.selection; }
  return list.map(entryOf).filter((e): e is Entry => !!e);
}

// --- find --------------------------------------------------------------------------------------------------

const KINDS: FindKind[] = ['all', 'tasks', 'open tasks', 'requirements', 'scenarios', 'sections'];
const KIND_ICON: Record<Entry['kind'], string> = { task: 'circle-outline', req: 'symbol-field', scn: 'symbol-event', sec: 'symbol-key', item: 'note' };
async function findCommand() {
  if (!projects.length) { return; }
  const withArchived = settings().showArchived;
  const indexes = projects.map(p => ({ p, index: searchIndex(p, withArchived) }));
  let kind = 0, art = 0;
  const arts = ['all', ...new Set(indexes.flatMap(x => x.index.map(e => e.art)))];
  type Item = vscode.QuickPickItem & { e?: Entry };
  const qp = vscode.window.createQuickPick<Item>();
  const grouping = projects.some(p => p.grouping);
  const artNames = arts.slice(1).map(a => a.toLowerCase().replace(/\s+/g, '-'));
  qp.placeholder = `A task number (1.3), words${grouping ? ', g1 (a group)' : ''}; in:${artNames.slice(0, 3).join(' in:')} ... (a document); is:task is:req is:scenario is:section is:open`;
  const kindButton: vscode.QuickInputButton = { iconPath: new vscode.ThemeIcon('filter'), tooltip: 'Kind: all, tasks, open tasks, requirements, scenarios, sections' };
  const artButton: vscode.QuickInputButton = { iconPath: new vscode.ThemeIcon('file'), tooltip: 'In which document: all, proposal, specs, design, tasks ...' };
  const manyButton: vscode.QuickInputButton = { iconPath: new vscode.ThemeIcon('checklist'), tooltip: 'Select several (then delete them, tick them, or hand them to the agent)' };
  qp.buttons = [kindButton, artButton, manyButton];
  const itemButtons = (e: Entry): vscode.QuickInputButton[] => [
    { iconPath: new vscode.ThemeIcon('book'), tooltip: 'Read (formatted), at it' },
    { iconPath: new vscode.ThemeIcon('edit'), tooltip: 'Edit' },
    ...(e.kind === 'task' ? [{ iconPath: new vscode.ThemeIcon(e.done ? 'circle-outline' : 'check'), tooltip: e.done ? 'Not done' : 'Done' }] : []),
    { iconPath: new vscode.ThemeIcon('sparkle'), tooltip: 'The agent: change it, write it again' },
    { iconPath: new vscode.ThemeIcon('trash'), tooltip: 'Delete' },
  ];
  const KIND_NAME: Record<Entry['kind'], string> = { task: 'task', req: 'requirement', scn: 'scenario', sec: 'section', item: 'item' };
  const IS: Record<string, FindKind> = { task: 'tasks', tasks: 'tasks', open: 'open tasks', req: 'requirements', requirement: 'requirements', requirements: 'requirements', scn: 'scenarios', scenario: 'scenarios', scenarios: 'scenarios', sec: 'sections', section: 'sections', sections: 'sections' };
  const update = () => {
    // Typed filters: in:<document> (design, tasks, open-questions ... a beginning is enough), is:<kind>.
    let typedArt = '', typedKind: FindKind | '' = '';
    const words = qp.value.split(/\s+/).filter(w => {
      let m = /^in:(\S*)$/i.exec(w);
      if (m) { const want = m[1].toLowerCase(); const i = artNames.findIndex(a => a.startsWith(want)); if (want && i >= 0) { typedArt = arts[i + 1]; } return false; }
      m = /^is:(\S*)$/i.exec(w);
      if (m) { const k = IS[m[1].toLowerCase()]; if (k) { typedKind = k; } return false; }
      return true;
    });
    const wantArt = typedArt || (art > 0 ? arts[art] : '');
    const wantKind = typedKind || KINDS[kind];
    qp.title = `LazySpec: find - ${wantKind}, in ${wantArt || 'all documents'}${qp.canSelectMany ? ' - several: Enter goes on' : ''}`;
    const found: Item[] = [];
    const query = words.join(' ');
    for (const { p, index } of indexes) {
      // Only a filter typed (in:design): everything of that document / kind.
      const kindOk = (e: Entry) => wantKind === 'all' || (wantKind === 'tasks' && e.kind === 'task') || (wantKind === 'open tasks' && e.kind === 'task' && !e.done) || (wantKind === 'requirements' && e.kind === 'req') || (wantKind === 'scenarios' && e.kind === 'scn') || (wantKind === 'sections' && e.kind === 'sec');
      const hits = query.trim() ? find(p, index, query, wantKind) : (typedArt || typedKind) ? index.filter(kindOk) : [];
      for (const e of hits.filter(x => !wantArt || x.art === wantArt).slice(0, 300)) {
        const icon = e.kind === 'task' ? (e.done ? 'pass' : 'circle-outline') : KIND_ICON[e.kind];
        // On a small line of its own: the document it is in, what it is, and its requirement or task group.
        const detail = [e.art.toUpperCase(), KIND_NAME[e.kind] + (e.kind === 'task' && e.done ? ' (done)' : ''), e.context ? `${e.kind === 'scn' ? 'of' : 'in'} ${e.context}` : ''].filter(x => x).join('  ·  ');
        found.push({ label: `$(${icon}) ${idLabel(e.id, e.text)}`, description: [e.where, e.cap].filter(x => x).join(' · '), detail, alwaysShow: true, e, buttons: qp.canSelectMany ? [] : itemButtons(e) });
      }
    }
    qp.items = found;
  };
  qp.onDidChangeValue(update);
  qp.onDidTriggerButton(b => {
    if (b === kindButton) { kind = (kind + 1) % KINDS.length; }
    if (b === artButton) { art = (art + 1) % arts.length; }
    if (b === manyButton) { qp.canSelectMany = !qp.canSelectMany; }
    update();
  });
  qp.onDidTriggerItemButton(async ev => {
    const e = ev.item.e;
    if (!e) { return; }
    const tip = ev.button.tooltip || '';
    qp.hide();
    if (tip.startsWith('Read')) { await readAt(e); }
    else if (tip === 'Edit') { await editItem(itemCtx, e); }
    else if (tip === 'Done' || tip === 'Not done') { await toggleTask(itemCtx, e); }
    else if (tip.startsWith('The agent')) { await agentItems(itemCtx, [e]); }
    else if (tip === 'Delete') { await deleteItems(itemCtx, [e]); }
  });
  qp.onDidAccept(async () => {
    const many = qp.canSelectMany;
    const sel = (many ? qp.selectedItems : qp.activeItems).map(i => i.e).filter((e): e is Entry => !!e);
    if (!sel.length) { return; }
    qp.hide();
    if (!many) { await openAt(sel[0].path, sel[0].line, sel[0].text); return; }
    const act = await vscode.window.showQuickPick([
      { label: '$(trash) Delete them', v: 'delete' }, { label: '$(sparkle) The agent: change them, or write them again', v: 'agent' },
      ...(sel.some(e => e.kind === 'task') ? [{ label: '$(check) Tasks: done', v: 'done' }, { label: '$(circle-outline) Tasks: not done', v: 'undone' }] : []),
    ], { placeHolder: `${sel.length} selected` });
    if (act?.v === 'delete') { await deleteItems(itemCtx, sel); }
    if (act?.v === 'agent') { await agentItems(itemCtx, sel); }
    if (act?.v === 'done' || act?.v === 'undone') { for (const e of sel.filter(x => x.kind === 'task')) { await toggleTask(itemCtx, e, act.v === 'done'); } }
  });
  qp.onDidHide(() => qp.dispose());
  update();
  qp.show();
}

// --- read -------------------------------------------------------------------------------------------------

const readActions = {
  edit: (e: Entry) => editItem(itemCtx, e),
  remove: (es: Entry[]) => deleteItems(itemCtx, es),
  toggle: (e: Entry) => toggleTask(itemCtx, e),
  agent: (es: Entry[]) => agentItems(itemCtx, es),
  exportTarget,
};
function readTargetOf(arg: unknown): ReadTarget | undefined {
  const t = targetOf(arg);
  if (!t) { return undefined; }
  if (t.change) { return { kind: 'change', project: t.project, change: t.change }; }
  if (t.spec) { return { kind: 'spec', project: t.project, spec: t.spec }; }
  if (t.group !== undefined) { return groupTarget(t.project, [t.group], false); }
  return undefined;
}
async function readAt(e: Entry) {
  const p = projectOfFile(e.path);
  if (!p) { return; }
  const t: ReadTarget = e.item.type === 'spec' ? { kind: 'spec', project: p, spec: e.item } : { kind: 'change', project: p, change: e.item };
  ReadPanel.show(t, readActions, { file: e.path, line: e.line });
}

// --- out of date --------------------------------------------------------------------------------------------

/** Out-of-date changes brought up to date: the clicked one with the others selected; none - every one of the
 *  project (all: chosen, all preselected). Then the agent (one run for all of them) or marked as in sync. */
async function syncCommand(node?: unknown, nodes?: unknown[], all = false) {
  let p: Project | undefined;
  let list: Change[] = [];
  const picked = (nodes?.length ? nodes : node ? [node] : []).map(n => targetOf(n)).filter(t => t?.change);
  if (picked.length && !all) {
    p = picked[0]!.project;
    list = picked.filter(t => t!.project === p).map(t => t!.change!);
  } else {
    p = await pickProject(node && !('kind' in (node as object)) ? node as { root?: string } : undefined);
    if (!p) { return; }
    const stale = p.changes.filter(c => !c.archived && staleOf(p!, c)?.length).sort((a, b) => a.name.localeCompare(b.name));
    if (!stale.length) { void vscode.window.showInformationMessage('No out-of-date changes: their documents are up to date.'); return; }
    const pr = p;
    const chosen = stale.length === 1 ? stale : (await vscode.window.showQuickPick(stale.map(c => ({ label: itemTitle(c), description: (staleOf(pr, c) || []).map(d => d.doc.title).join(', ') + ' out of date', picked: true, c })), { canPickMany: true, placeHolder: 'The out-of-date changes to bring up to date (all of them chosen)' }))?.map(x => x.c);
    if (!chosen?.length) { return; }
    list = chosen;
  }
  const proj = p!;
  const items = list.map(c => ({ change: c, stale: staleOf(proj, c) || [] })).filter(i => i.stale.length);
  if (!items.length) { void vscode.window.showInformationMessage(`${list.map(c => c.name).join(', ')}: up to date.`); return; }
  const what = items.length === 1 ? items[0].change.name : `${items.length} changes`;
  const pick = await vscode.window.showQuickPick([
    { label: '$(sparkle) Update them', description: items.length > 1 ? 'one agent run for all of them; each validated and marked after' : 'the agent gets what changed, before and now', v: 'update' },
    { label: '$(check) Mark them as in sync', description: 'as they are now (nothing needs to change)', v: 'mark' },
  ], { placeHolder: items.length === 1 ? `${what}: ${items[0].stale.map(d => d.doc.title).join(', ')} older than what they are written from` : `${what} out of date: ${items.map(i => i.change.name).join(', ')}` });
  if (pick?.v === 'mark') { for (const i of items) { setInSync(proj, i.change); } reload(); void vscode.window.showInformationMessage(`${what}: marked as in sync.`); }
  // The agent done: each change marked as in sync against what it was given (the prompt's snapshot each).
  if (pick?.v === 'update') {
    const many = items.length > 1;
    await agentTask(proj, `Update ${what}`, many ? `sync-${items.length}-changes` : `sync-${items[0].change.name}`, syncPromptMany(proj, items), rel => items.map(i => saveSyncSnapshot(proj, i.change, i.stale, rel, many)));
  }
}

// --- the views ---------------------------------------------------------------------------------------------------

let plan: PlanTree;
let scope: ScopeTree;
let details: DetailsView;
let undoTree: UndoTree;
let planView: vscode.TreeView<Node>;
let scopeView: vscode.TreeView<Node>;
let undoView: vscode.TreeView<UndoNode>;
let status: vscode.StatusBarItem;
let reloadTimer: NodeJS.Timeout | undefined;
const itemCtx: ItemContext = { projectOfFile: f => projectOfFile(f), reload: () => reload(), openFile: (f, l) => openFile(f, l), formatted: (e, viaChange) => editItemFormatted(ctx.extensionUri, itemCtx, e, viaChange) };

async function openFile(file: string, line = 0) {
  const doc = await vscode.workspace.openTextDocument(file);
  const pos = new vscode.Position(Math.max(0, line - 1), 0);
  await vscode.window.showTextDocument(doc, { selection: new vscode.Range(pos, pos), preview: line > 0 });
}
/** An item's document opened at it: in the formatted editor (scrolled to it - the nth line with its text up to
 *  its line), else the source at its line (lazyspec.documents). */
async function openAt(file: string, line = 0, text = '') {
  if (settings().documents !== 'formatted' || !file.toLowerCase().endsWith('.md')) { await openFile(file, line); return; }
  // No item to go to (a document's link): the document, formatted.
  if (!text) { await openDocument(file); return; }
  const lines = fs.existsSync(file) ? fs.readFileSync(file, 'utf8').replace(/\r/g, '').split('\n') : [];
  const plain = (t: string) => t.replace(/[*_`]/g, '').toLowerCase();
  const want = plain(text).trim();
  const nth = Math.max(0, lines.slice(0, Math.max(0, line - 1)).filter(l => plain(l).includes(want)).length);
  await FormattedEditorProvider.openAt(vscode.Uri.file(file), text, nth);
}
/** A document: in the formatted editor, the Markdown preview or its source, as lazyspec.documents says. */
async function openDocument(file: string, as?: 'formatted' | 'preview' | 'source') {
  const how = as || settings().documents;
  const md = file.toLowerCase().endsWith('.md');
  if (how === 'formatted' && md) { await FormattedEditorProvider.openAt(vscode.Uri.file(file), ''); return; }
  if (how === 'preview' && md) { await vscode.commands.executeCommand('markdown.showPreview', vscode.Uri.file(file)); return; }
  await openFile(file);
}
function reload() {
  for (const p of projects) {
    try { p.load(); } catch (e) { output.appendLine(`${p.root}: ${(e as Error).message}`); }
    try { stale.set(p.root, syncState(p)); } catch (e) { output.appendLine(`out of date, ${p.root}: ${(e as Error).message}`); }
    void askSyncCheck(p);
    // A sync prompt saved for later and done by the agent outside: marked? (once a session)
    if (p.config.values['syncCheck'] === 'on') {
      for (const f of doneSyncPrompts(p, stale.get(p.root) || new Map())) {
        if (syncOffered.has(f) || runningSyncs.has(f)) { continue; }
        syncOffered.add(f);
        void offerDoneSync(p, f);
        break;
      }
    }
  }
  void vscode.commands.executeCommand('setContext', 'lazyspec.hasGroups', projects.some(p => p.grouping));
  void vscode.commands.executeCommand('setContext', 'lazyspec.hasProject', projects.length > 0);
  void vscode.commands.executeCommand('setContext', 'lazyspec.hasStale', projects.some(p => p.changes.some(c => !c.archived && staleOf(p, c)?.length)));
  plan.refresh();
  scope.refresh();
  undoTree.refresh();
  const n = undoTree.count();
  undoView.badge = n ? { value: n, tooltip: `${n} file(s) changed in openspec/ since the last commit` } : undefined;
  details.refresh(s => {
    if (s.kind === 'change') { const c = s.project.changes.find(x => x.dir === s.change.dir); return c ? { ...s, change: c } : null; }
    if (s.kind === 'spec') { const x = s.project.specs.find(y => y.path === s.spec.path); return x ? { ...s, spec: x } : null; }
    return s;
  });
  ReadPanel.refreshAll(t => {
    const p = t.project;
    if (t.kind === 'spec') { const s = p.specs.find(x => x.path === t.spec.path); return s ? { ...t, spec: s } : null; }
    if (t.kind === 'change') { const c = p.changes.find(x => x.dir === t.change.dir); return c ? { ...t, change: c } : null; }
    const cs = t.changes.map(c => p.changes.find(x => x.dir === c.dir)).filter((c): c is Change => !!c);
    return cs.length ? { ...t, changes: cs } : null;
  });
  const active = projects.flatMap(p => p.changes.filter(c => !c.archived));
  const done = active.reduce((k, c) => k + c.done, 0), total = active.reduce((k, c) => k + c.total, 0);
  const outOfDate = projects.reduce((k, p) => k + p.changes.filter(c => !c.archived && staleOf(p, c)?.length).length, 0);
  if (projects.length) {
    status.text = `$(checklist) ${done}/${total}${outOfDate ? `  $(warning) ${outOfDate}` : ''}`;
    // Out-of-date changes: a click brings them up to date (all of them chosen); else the sidebar.
    status.command = outOfDate ? 'lazyspec.syncAll' : 'workbench.view.extension.lazyspec';
    status.tooltip = `OpenSpec: ${projects.reduce((k, p) => k + p.specs.length, 0)} specs, ${active.length} active changes, ${done} of ${total} tasks done${outOfDate ? `; ${outOfDate} with out-of-date documents` : ''}`;
    status.show();
  } else { status.hide(); }
}
/** Out of date the first time, and not asked yet: watch for it in this project? (remembered in config.yaml) */
async function askSyncCheck(p: Project) {
  if (p.config.values['syncCheck'] || syncAsked.has(p.root) || !stale.get(p.root)?.size) { return; }
  syncAsked.add(p.root);
  const first = [...stale.get(p.root)!.keys()][0];
  const pick = await vscode.window.showInformationMessage(`Out of date: documents of ${first} are older than the specs they're written from. Watch for this in this project?`, 'Yes, Watch', 'No');
  if (!pick) { return; }
  try { setConfigValue(p, 'syncCheck', pick === 'No' ? 'off' : 'on'); } catch { /* read-only */ }
  reload();
}
function reloadSoon() {
  if (reloadTimer) { clearTimeout(reloadTimer); }
  reloadTimer = setTimeout(reload, 300);
}
function select(n: Node | undefined) {
  if (!n) { return; }
  let s: Selected = null;
  if (n.kind === 'change' || n.kind === 'doc' || n.kind === 'cap' || n.kind === 'taskGroup' || n.kind === 'task' || n.kind === 'file') { s = { kind: 'change', project: n.project, change: n.change }; }
  else if (n.kind === 'req' || n.kind === 'scn' || n.kind === 'sec') { s = n.owner.type === 'spec' ? { kind: 'spec', project: n.project, spec: n.owner } : { kind: 'change', project: n.project, change: n.owner }; }
  else if (n.kind === 'spec') { s = { kind: 'spec', project: n.project, spec: n.spec }; }
  else if (n.kind === 'group') { s = { kind: 'group', project: n.project, id: n.id }; }
  if (s) { details.show(s); }
}
function docFile(n: Node): string {
  if (n.kind === 'doc') { return n.doc.files[0] || ''; }
  if (n.kind === 'file') { return n.file; }
  if (n.kind === 'cap') { return n.cap.path; }
  if (n.kind === 'spec') { return n.spec.path; }
  if (n.kind === 'change') { return n.change.path; }
  return '';
}

/** lazyspec.openMarkdownFormatted: the formatted editor the default for openspec's Markdown, wherever it is
 *  opened from (the Explorer, Ctrl+P): workbench.editorAssociations (the user's settings), added or taken out. */
const ASSOC = '**/openspec/**/*.md';
async function syncEditorAssociation() {
  const on = vscode.workspace.getConfiguration('lazyspec').get<boolean>('openMarkdownFormatted', true);
  const wb = vscode.workspace.getConfiguration('workbench');
  const now = { ...(wb.inspect<Record<string, string>>('editorAssociations')?.globalValue || {}) };
  if (on && now[ASSOC] !== FormattedEditorProvider.viewType) { now[ASSOC] = FormattedEditorProvider.viewType; }
  else if (!on && now[ASSOC] === FormattedEditorProvider.viewType) { delete now[ASSOC]; }
  else { return; }
  try { await wb.update('editorAssociations', now, vscode.ConfigurationTarget.Global); } catch (e) { output.appendLine(`editorAssociations: ${(e as Error).message}`); }
}

export interface Api { projects(): Project[]; plan: PlanTree; scope: ScopeTree; details: DetailsView; undo: UndoTree; reload(): void }

export function activate(context: vscode.ExtensionContext): Api {
  ctx = context;
  output = vscode.window.createOutputChannel('LazySpec');
  projects = findProjects();
  const hooks = { stale: (p: Project, c: Change) => !!staleOf(p, c)?.length, syncing: (_p: Project, c: Change) => syncingChanges().has(c.name) };
  onSynced(() => reload());
  plan = new PlanTree(() => projects, settings, hooks);
  scope = new ScopeTree(() => projects, settings, hooks);
  details = new DetailsView(staleOf);
  undoTree = new UndoTree(() => projects);
  status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 50);
  status.command = 'workbench.view.extension.lazyspec';
  planView = vscode.window.createTreeView('lazyspec.plan', { treeDataProvider: plan, showCollapseAll: true, canSelectMany: true });
  scopeView = vscode.window.createTreeView('lazyspec.scope', { treeDataProvider: scope, showCollapseAll: true, canSelectMany: true });
  undoView = vscode.window.createTreeView('lazyspec.undo', { treeDataProvider: undoTree });
  const watchers: vscode.FileSystemWatcher[] = [];
  const watch = () => {
    watchers.splice(0).forEach(w => w.dispose());
    for (const p of projects) {
      const w = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(vscode.Uri.file(p.root), '{openspec/**,lazyspec.json,tools/lazyspec/lazyspec.json,.git/HEAD,.git/index}'));
      w.onDidChange(reloadSoon); w.onDidCreate(reloadSoon); w.onDidDelete(reloadSoon);
      watchers.push(w);
    }
  };
  watch();

  const reg = (id: string, fn: (...a: any[]) => unknown) => context.subscriptions.push(vscode.commands.registerCommand(id, fn));
  const fileOf = (n?: Node | vscode.Uri) => (n instanceof vscode.Uri ? n.fsPath : n && 'kind' in n ? docFile(n) : vscode.window.activeTextEditor?.document.uri.fsPath || '');
  reg('lazyspec.refresh', () => { projects = findProjects(); watch(); reload(); });
  reg('lazyspec.openFile', (file: string, line = 0) => openFile(file, line));
  reg('lazyspec.openAt', (file: string, line = 0, text = '') => openAt(file, line, text));
  // The panes: Ctrl+; then P (Plan), S (Scope), D (Details), U (Undo), E (the document) - focused, the arrows work.
  reg('lazyspec.focusPlan', async () => { await vscode.commands.executeCommand('lazyspec.plan.focus'); });
  reg('lazyspec.focusScope', async () => { await vscode.commands.executeCommand('lazyspec.scope.focus'); });
  reg('lazyspec.focusDetails', async () => { await vscode.commands.executeCommand('lazyspec.details.focus'); });
  reg('lazyspec.focusUndo', async () => { await vscode.commands.executeCommand('lazyspec.undo.focus'); });
  reg('lazyspec.focusEditor', async () => { await vscode.commands.executeCommand('workbench.action.focusActiveEditorGroup'); FormattedEditorProvider.focusActive(); });
  reg('lazyspec.openDocument', (file: string) => openDocument(file));
  reg('lazyspec.showPreview', (n?: Node | vscode.Uri) => { const f = fileOf(n); if (f) { return openDocument(f, 'preview'); } });
  reg('lazyspec.showSource', (n?: Node | vscode.Uri) => { const f = fileOf(n); if (f) { return openDocument(f, 'source'); } });
  reg('lazyspec.openFormatted', (n?: Node | vscode.Uri) => { const f = fileOf(n); if (f) { return openDocument(f, 'formatted'); } });
  reg('lazyspec.openBlock', (e: Entry) => openBlock(e));
  reg('lazyspec.readFile', (n?: vscode.Uri) => {
    const f = fileOf(n);
    const e = f ? searchIndex(projectOfFile(f) || projects[0], true).find(x => x.path.toLowerCase() === f.toLowerCase()) : undefined;
    if (e) { return readAt(e); }
    const p = f ? projectOfFile(f) : undefined;
    const c = p?.changes.find(x => f!.toLowerCase().startsWith(x.dir.toLowerCase()));
    const s = p?.specs.find(x => x.path.toLowerCase() === f!.toLowerCase());
    if (p && c) { ReadPanel.show({ kind: 'change', project: p, change: c }, readActions); }
    else if (p && s) { ReadPanel.show({ kind: 'spec', project: p, spec: s }, readActions); }
    else { void vscode.window.showInformationMessage('Read shows the documents of a change or a spec (openspec/).'); }
  });
  reg('lazyspec.openItem', (arg?: unknown) => {
    const t = targetOf(arg);
    if (t?.change) { return openDocument(t.change.path); }
    if (t?.spec) { return openDocument(t.spec.path); }
  });
  reg('lazyspec.showDetails', (n?: Node) => { select(n); void vscode.commands.executeCommand('lazyspec.details.focus'); });
  reg('lazyspec.read', (arg?: unknown) => {
    const t = readTargetOf(arg);
    if (t) { ReadPanel.show(t, readActions); } else { void vscode.window.showInformationMessage('Select a change, a spec or a group to read.'); }
  });
  reg('lazyspec.readAsOne', async (arg?: { root?: string }) => { const p = await pickProject(arg); const t = p && await chooseAsOne(p, 'read'); if (t) { ReadPanel.show(t, readActions); } });
  reg('lazyspec.readGroups', async (arg?: { root?: string; preselect?: string[] }) => {
    const p = await pickProject(arg);
    const ids = p && await chooseGroups(p, 'Read', arg?.preselect);
    const t = p && ids && groupTarget(p, ids, true);
    if (t) { ReadPanel.show(t, readActions); }
  });
  reg('lazyspec.removeBundle', removeBundle);
  reg('lazyspec.find', findCommand);
  reg('lazyspec.editItem', (n?: Node, ns?: Node[]) => { const e = entriesOf(n, ns)[0]; if (e) { return editItem(itemCtx, e); } });
  reg('lazyspec.editItemInFile', (n?: Node, ns?: Node[]) => { const e = entriesOf(n, ns)[0]; if (e) { return openBlock(e); } });
  reg('lazyspec.deleteItems', (n?: Node, ns?: Node[]) => deleteItems(itemCtx, entriesOf(n, ns)));
  reg('lazyspec.agentItems', (n?: Node, ns?: Node[]) => agentItems(itemCtx, entriesOf(n, ns)));
  reg('lazyspec.toggleTask', async (n?: Node, ns?: Node[]) => { for (const e of entriesOf(n, ns).filter(x => x.kind === 'task')) { await toggleTask(itemCtx, e); } });
  reg('lazyspec.readItem', (n?: Node, ns?: Node[]) => { const e = entriesOf(n, ns)[0]; if (e) { return readAt(e); } });
  reg('lazyspec.sync', (n?: unknown, ns?: unknown[]) => syncCommand(n, ns));
  reg('lazyspec.syncAll', (arg?: { root?: string }) => syncCommand(arg, undefined, true));
  reg('lazyspec.markInSync', (arg?: unknown) => { const t = targetOf(arg); if (t?.change) { setInSync(t.project, t.change); reload(); } });
  reg('lazyspec.agentAnswer', () => answer());
  reg('lazyspec.agentOutput', () => showAgentOutput());
  reg('lazyspec.agentStop', () => stopAgent());
  reg('lazyspec.undoRefresh', () => reload());
  reg('lazyspec.undoShow', (n: UndoNode) => showUndo(n));
  reg('lazyspec.undoItem', async (n?: UndoNode) => { const x = n || undoView.selection[0]; if (x && await undo(x)) { reload(); } });
  reg('lazyspec.newChange', async (arg?: { root?: string }) => {
    const p = await pickProject(arg);
    if (!p) { return; }
    const name = await vscode.window.showInputBox({
      prompt: 'New change: its name (kebab-case)', placeHolder: 'add-user-login',
      validateInput: v => (/^[a-z0-9]+(-[a-z0-9]+)*$/.test(v.trim()) ? undefined : 'kebab-case: lowercase words with hyphens'),
    });
    if (name) { runCli(p, ['new', 'change', name.trim()], 'New change'); }
  });
  reg('lazyspec.validate', async (arg?: { root?: string }) => { const p = await pickProject(arg); if (p) { runCli(p, ['validate', '--all', '--strict', '--no-interactive'], 'Validate'); } });
  reg('lazyspec.archive', async (arg?: unknown) => {
    let t = targetOf(arg);
    if (!t?.change) { const p = await pickProject(); const c = p && await pickChange(p); if (p && c) { t = { project: p, change: c }; } }
    if (!t?.change || t.change.archived) { return; }
    const c = t.change;
    const open = c.total - c.done;
    const ok = await vscode.window.showWarningMessage(`Archive ${c.name}?${open > 0 ? ` ${open} of ${c.total} tasks are still open.` : ''}`, { modal: true, detail: 'openspec archive merges its delta specs into openspec/specs.' }, 'Archive');
    if (ok) { runCli(t.project, ['archive', c.name, '--yes'], 'Archive'); }
  });
  reg('lazyspec.export', exportMenu);
  reg('lazyspec.exportLanguage', async () => {
    const l = await vscode.window.showQuickPick(['en', 'hr', 'de', 'nl', 'Other...'], { placeHolder: 'The export in which language (the documents translated by DeepL: translation: in openspec/config.yaml)' });
    if (!l) { return; }
    exportLanguage = l === 'Other...' ? ((await vscode.window.showInputBox({ prompt: 'Language code (fr, it, es ...)' })) || '').trim() : l;
    if (exportLanguage) { await exportMenu(); }
  });
  reg('lazyspec.exportItem', async (arg?: unknown) => {
    const t = targetOf(arg);
    if (!t) { return exportMenu(); }
    if (t.change) { return exportAs(t.project, ['-Item', t.change.name], itemTitle(t.change)); }
    if (t.spec) { return exportAs(t.project, ['-Item', t.spec.name], itemTitle(t.spec)); }
    if (t.group) { return exportAs(t.project, ['-Item', `group:${t.group}`], t.project.groupTitle(t.group)); }
  });
  reg('lazyspec.exportGroups', (arg?: { root?: string; preselect?: string[] } | Node) => {
    if (arg && 'kind' in arg) { return arg.kind === 'group' ? exportGroups({ root: arg.project.root, preselect: [arg.id] }) : exportGroups({ root: arg.project.root }); }
    return exportGroups(arg);
  });
  reg('lazyspec.exportMarkdown', async (uri?: vscode.Uri) => {
    const file = uri?.fsPath || vscode.window.activeTextEditor?.document.uri.fsPath;
    if (!file || !file.toLowerCase().endsWith('.md')) { void vscode.window.showInformationMessage('Open or pick a Markdown file (.md) to export.'); return; }
    await exportAs(projectOfFile(file), ['-Markdown', file], path.basename(file), path.dirname(file));
  });
  const toggle = async (key: 'grouped' | 'showArchived') => {
    const c = vscode.workspace.getConfiguration('lazyspec');
    await c.update(key, !c.get<boolean>(key), vscode.ConfigurationTarget.Workspace);
  };
  reg('lazyspec.toggleGrouped', () => toggle('grouped'));
  reg('lazyspec.toggleArchived', () => toggle('showArchived'));
  reg('lazyspec.sort', async () => {
    const pick = await vscode.window.showQuickPick([{ label: 'Name A-Z', v: 'name' }, { label: 'Name Z-A', v: 'name-desc' }, { label: 'Recently modified', v: 'recent' }], { placeHolder: 'Sort the changes' });
    if (pick) { await vscode.workspace.getConfiguration('lazyspec').update('sort', pick.v, vscode.ConfigurationTarget.Workspace); }
  });
  reg('lazyspec.openConfig', async (arg?: { root?: string }) => { const p = await pickProject(arg); if (p) { await openFile(path.join(p.osDir, 'config.yaml')); } });
  reg('lazyspec.openTui', async () => {
    const p = await pickProject();
    if (!p) { return; }
    const t = vscode.window.createTerminal({ name: `LazySpec${projects.length > 1 ? `: ${p.name}` : ''}`, shellPath: powershell(), shellArgs: psArgs(kitScript(p), ['-Root', p.root]), cwd: p.root, location: vscode.TerminalLocation.Editor });
    t.show();
  });
  reg('lazyspec.help', () => showHelp(vscode.Uri.file(ctx.asAbsolutePath('README.md'))));

  context.subscriptions.push(
    output, status, planView, scopeView, undoView, { dispose: () => watchers.forEach(w => w.dispose()) },
    vscode.workspace.registerTextDocumentContentProvider(HeadContent.scheme, new HeadContent()),
    vscode.window.registerWebviewViewProvider('lazyspec.details', details),
    vscode.window.registerCustomEditorProvider(FormattedEditorProvider.viewType, new FormattedEditorProvider(context.extensionUri), { webviewOptions: { retainContextWhenHidden: true } }),
    planView.onDidChangeSelection(e => select(e.selection[0])),
    scopeView.onDidChangeSelection(e => select(e.selection[0])),
    planView.onDidChangeCheckboxState(async e => {
      for (const [n, state] of e.items) {
        const en = entryOf(n);
        if (en?.kind === 'task') { await toggleTask(itemCtx, en, state === vscode.TreeItemCheckboxState.Checked); }
      }
    }),
    vscode.workspace.onDidChangeConfiguration(e => {
      if (e.affectsConfiguration('lazyspec.roots')) { projects = findProjects(); watch(); }
      if (e.affectsConfiguration('lazyspec.openMarkdownFormatted')) { void syncEditorAssociation(); }
      if (e.affectsConfiguration('lazyspec')) { reload(); }
    }),
    vscode.workspace.onDidChangeWorkspaceFolders(() => { projects = findProjects(); watch(); reload(); }),
  );
  reload();
  if (projects.length) { void syncEditorAssociation(); }
  // A folder with openspec/ opened (code . there): LazySpec's sidebar shown, the Plan's first group or change selected.
  if (projects.length && vscode.workspace.getConfiguration('lazyspec').get<boolean>('openOnStartup', true)) {
    void vscode.commands.executeCommand('workbench.view.extension.lazyspec').then(() => {
      const first = plan.getChildren()[0];
      if (first) { void planView.reveal(first, { select: true, focus: false }).then(undefined, () => undefined); select(first); }
    }, () => undefined);
  }
  return { projects: () => projects, plan, scope, details, undo: undoTree, reload };
}

export function deactivate() { /* the subscriptions go with the context */ }

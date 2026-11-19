// LazySpec for VS Code (and Cursor, Windsurf ...): a project's OpenSpec in the editor. The Plan and the Scope
// as trees, the selected one's details, find, ticking tasks; validate, new change and archive through the
// OpenSpec CLI; exports for the client and the terminal UI through LazySpec's lazyspec.ps1.

import * as cp from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { DetailsView, Selected } from './details';
import { Change, Entry, find, FindKind, itemTitle, Project, searchIndex, setTaskDone, Spec, Task } from './model';
import { Node, PlanTree, ScopeTree, Settings } from './tree';

/** A target from a menu (a tree node), the details' buttons ({ type, root, name }), or nothing. */
interface Ref { type: 'change' | 'spec' | 'group'; root: string; name: string; path?: string }

let projects: Project[] = [];
let output: vscode.OutputChannel;
let ctx: vscode.ExtensionContext;

function settings(): Settings {
  const c = vscode.workspace.getConfiguration('lazyspec');
  return { grouped: c.get<boolean>('grouped', true), showArchived: c.get<boolean>('showArchived', false) };
}

/** The workspace's projects: its folders with an openspec folder, and lazyspec.roots below them. */
function findProjects(): Project[] {
  const roots: string[] = [];
  const extra = vscode.workspace.getConfiguration('lazyspec').get<string[]>('roots', []);
  for (const f of vscode.workspace.workspaceFolders || []) {
    const base = f.uri.fsPath;
    for (const r of [base, ...extra.map(e => path.resolve(base, e))]) {
      if (Project.isProject(r) && !roots.includes(r)) { roots.push(r); }
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
async function pickProject(): Promise<Project | undefined> {
  if (projects.length <= 1) { return projects[0]; }
  const p = await vscode.window.showQuickPick(projects.map(x => ({ label: x.name, description: x.root, project: x })), { placeHolder: 'Which project?' });
  return p?.project;
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
/** The format and the audience, then the export. */
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
  await runExport(p, ['-Export', f.value, ...(a.value ? ['-ClientFriendly'] : []), ...args], what, cwd);
}
async function exportMenu() {
  const p = await pickProject();
  if (!p) { return; }
  type Item = vscode.QuickPickItem & { run: () => Promise<void> };
  const items: Item[] = [];
  const active = p.changes.filter(c => !c.archived);
  if (p.specs.length) {
    items.push({ label: '$(book) The specification', description: `${p.specs.length} specs`, run: () => exportAs(p, [], 'the specification') });
    if (active.length) { items.push({ label: '$(book) The specification and the plan', description: `${active.length} active changes after the specs`, run: () => exportAs(p, ['-IncludeChanges'], 'the specification and the plan') }); }
  }
  if (active.length) { items.push({ label: '$(git-pull-request) A change...', run: async () => { const c = await pickChange(p); if (c) { await exportAs(p, ['-Item', c.name], itemTitle(c)); } } }); }
  if (active.length > 1) { items.push({ label: '$(files) Chosen changes, as one...', description: 'a chapter per kind of document', run: () => exportChosen(p) }); }
  if (p.grouping && p.config.groups.length) { items.push({ label: `$(layers) ${p.config.groupPlural}...`, description: 'with the ones they require', run: () => exportGroups({ root: p.root }) }); }
  for (const b of p.config.bundles) {
    items.push({ label: `$(package) ${b.title || b.id}`, description: `saved: ${b.groups.length ? `${p.config.groupPlural.toLowerCase()} ${b.groups.join(', ')}` : b.changes.join(', ')}`, run: () => exportAs(p, ['-Item', b.id], b.title || b.id) });
  }
  if (p.specs.length) { items.push({ label: '$(symbol-class) A spec...', run: async () => { const s = await vscode.window.showQuickPick(p.specs.map(x => ({ label: itemTitle(x), description: x.name, spec: x }))); if (s) { await exportAs(p, ['-Item', s.spec.name], s.label); } } }); }
  if (!items.length) { void vscode.window.showInformationMessage('Nothing to export yet: no specs and no active changes.'); return; }
  const pick = await vscode.window.showQuickPick(items, { placeHolder: 'Export for the client' });
  if (pick) { await pick.run(); }
}
async function pickChange(p: Project, archived = false): Promise<Change | undefined> {
  const list = p.changes.filter(c => archived || !c.archived).sort((a, b) => a.name.localeCompare(b.name));
  const c = await vscode.window.showQuickPick(list.map(x => ({ label: itemTitle(x), description: x.name, detail: p.grouping && x.group ? p.groupTitle(x.group) : undefined, change: x })), { placeHolder: 'Which change?', matchOnDescription: true });
  return c?.change;
}
async function exportChosen(p: Project) {
  const active = p.changes.filter(c => !c.archived).sort((a, b) => a.name.localeCompare(b.name));
  const picks = await vscode.window.showQuickPick(active.map(x => ({ label: itemTitle(x), description: x.name, change: x })), { canPickMany: true, placeHolder: 'The changes that go to the client as one whole' });
  if (!picks?.length) { return; }
  const title = await vscode.window.showInputBox({ prompt: 'Title of the whole (on the cover; empty: the changes\' titles)' });
  if (title === undefined) { return; }
  await exportAs(p, ['-Item', picks.map(x => x.change.name).join(','), ...(title ? ['-Title', title] : [])], title || `${picks.length} changes`);
}
async function exportGroups(arg?: { root?: string; preselect?: string[] }) {
  const p = arg?.root ? projectOf(arg.root) : await pickProject();
  if (!p) { return; }
  if (!p.config.groups.length && !p.grouping) { void vscode.window.showInformationMessage('This project has no groups (groups: in openspec/config.yaml, x-group: <id> in a change\'s .openspec.yaml).'); return; }
  const counts = new Map(p.groups().map(g => [g.id, g]));
  const ids = [...new Set([...p.config.groups.map(g => g.id), ...[...counts.keys()].filter(k => k)])];
  const qp = vscode.window.createQuickPick<vscode.QuickPickItem & { id: string }>();
  qp.canSelectMany = true;
  qp.title = `Export ${p.config.groupPlural.toLowerCase()} (the ones they require come too)`;
  qp.items = ids.map(id => {
    const g = counts.get(id);
    const d = p.groupDef(id);
    return { id, label: p.groupTitle(id), description: g ? `${g.changes.length} changes, ${g.done}/${g.total}` : 'no active changes', detail: d?.requires.length ? `requires ${d.requires.map(r => p.groupTitle(r)).join(', ')}` : d?.description };
  });
  qp.selectedItems = qp.items.filter(i => arg?.preselect?.includes(i.id));
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
  if (!chosen?.length) { return; }
  const sel = p.groupSelection(chosen);
  await exportAs(p, ['-Groups', chosen.join(',')], sel.ids.map(i => p.groupTitle(i)).join(', '));
}

// --- the target of a command ----------------------------------------------------------------------------------

function targetOf(arg: unknown): { project: Project; change?: Change; spec?: Spec; group?: string } | undefined {
  if (!arg) {
    const s = details.current();
    if (!s) { return undefined; }
    if (s.kind === 'change') { return { project: s.project, change: s.change }; }
    if (s.kind === 'spec') { return { project: s.project, spec: s.spec }; }
    return { project: s.project, group: s.id };
  }
  const n = arg as Node;
  if ('kind' in n) {
    if (n.kind === 'change' || n.kind === 'doc' || n.kind === 'cap' || n.kind === 'taskGroup' || n.kind === 'task') { return { project: n.project, change: n.change }; }
    if (n.kind === 'spec') { return { project: n.project, spec: n.spec }; }
    if (n.kind === 'group') { return { project: n.project, group: n.id }; }
    return undefined;
  }
  const r = arg as Ref;
  const p = r.path ? projectOfFile(r.path) : projectOf(r.root);
  if (!p) { return undefined; }
  if (r.type === 'change') { const c = p.changes.find(x => x.name === r.name); return c ? { project: p, change: c } : undefined; }
  if (r.type === 'spec') { const s = p.specs.find(x => x.name === r.name); return s ? { project: p, spec: s } : undefined; }
  return { project: p, group: r.name };
}

// --- tasks: ticked in the tree ---------------------------------------------------------------------------------

async function setTask(task: Task, done: boolean) {
  const doc = await vscode.workspace.openTextDocument(task.path);
  const wasDirty = doc.isDirty;
  // The line it was on, else the line with its text (the file changed since).
  let line = task.line - 1;
  const isIt = (i: number) => i >= 0 && i < doc.lineCount && /^\s*[-*]\s+\[[ xX]\]/.test(doc.lineAt(i).text) && doc.lineAt(i).text.includes(task.text.slice(0, 20).replace(/\*\*/g, ''));
  if (!isIt(line)) { line = -1; for (let i = 0; i < doc.lineCount; i++) { if (isIt(i)) { line = i; break; } } }
  if (line < 0) { void vscode.window.showWarningMessage(`The task isn't in ${path.basename(task.path)} any more: refreshed.`); reload(); return; }
  const text = doc.lineAt(line).text;
  const edit = new vscode.WorkspaceEdit();
  edit.replace(doc.uri, doc.lineAt(line).range, setTaskDone(text, done));
  await vscode.workspace.applyEdit(edit);
  if (!wasDirty) { await doc.save(); }
  reload();
}

// --- find --------------------------------------------------------------------------------------------------

const KINDS: FindKind[] = ['all', 'tasks', 'open tasks', 'requirements', 'scenarios', 'sections'];
const KIND_ICON: Record<Entry['kind'], string> = { task: 'circle-outline', req: 'symbol-field', scn: 'symbol-event', sec: 'symbol-key' };
async function findCommand() {
  if (!projects.length) { return; }
  const withArchived = settings().showArchived;
  const indexes = projects.map(p => ({ p, index: searchIndex(p, withArchived) }));
  let kind = 0;
  const qp = vscode.window.createQuickPick<vscode.QuickPickItem & { e?: Entry }>();
  const grouping = projects.some(p => p.grouping);
  qp.placeholder = `A task number (1.3), a change and a number (01 1.3), or words${grouping ? '; g1 or group 1: one group' : ''}`;
  qp.matchOnDescription = false;
  const kindButton: vscode.QuickInputButton = { iconPath: new vscode.ThemeIcon('filter'), tooltip: 'Kind: all, tasks, open tasks, requirements, scenarios, sections' };
  qp.buttons = [kindButton];
  const update = () => {
    qp.title = `LazySpec: find - ${KINDS[kind]}`;
    const found: (vscode.QuickPickItem & { e?: Entry })[] = [];
    for (const { p, index } of indexes) {
      for (const e of find(p, index, qp.value, KINDS[kind]).slice(0, 300)) {
        const icon = e.kind === 'task' ? (e.done ? 'pass' : 'circle-outline') : KIND_ICON[e.kind];
        const where = [e.art, e.where, e.cap].filter(x => x).join(' · ');
        found.push({ label: `$(${icon}) ${e.text}`, description: where, detail: e.context ? `${e.kind === 'scn' ? 'requirement' : 'in'}: ${e.context}` : undefined, alwaysShow: true, e });
      }
    }
    qp.items = found;
  };
  qp.onDidChangeValue(update);
  qp.onDidTriggerButton(() => { kind = (kind + 1) % KINDS.length; update(); });
  qp.onDidAccept(() => {
    const e = qp.selectedItems[0]?.e;
    if (e) { void openFile(e.path, e.line); qp.hide(); }
  });
  qp.onDidHide(() => qp.dispose());
  update();
  qp.show();
}

// --- the views ---------------------------------------------------------------------------------------------------

let plan: PlanTree;
let scope: ScopeTree;
let details: DetailsView;
let status: vscode.StatusBarItem;
let reloadTimer: NodeJS.Timeout | undefined;

async function openFile(file: string, line = 0) {
  const doc = await vscode.workspace.openTextDocument(file);
  const pos = new vscode.Position(Math.max(0, line - 1), 0);
  await vscode.window.showTextDocument(doc, { selection: new vscode.Range(pos, pos), preview: line > 0 });
}
function reload() {
  for (const p of projects) {
    try { p.load(); } catch (e) { output.appendLine(`${p.root}: ${(e as Error).message}`); }
  }
  void vscode.commands.executeCommand('setContext', 'lazyspec.hasGroups', projects.some(p => p.grouping));
  void vscode.commands.executeCommand('setContext', 'lazyspec.hasProject', projects.length > 0);
  plan.refresh();
  scope.refresh();
  details.refresh(s => {
    if (s.kind === 'change') { const c = s.project.changes.find(x => x.dir === s.change.dir); return c ? { ...s, change: c } : null; }
    if (s.kind === 'spec') { const x = s.project.specs.find(y => y.path === s.spec.path); return x ? { ...s, spec: x } : null; }
    return s;
  });
  const active = projects.flatMap(p => p.changes.filter(c => !c.archived));
  const done = active.reduce((n, c) => n + c.done, 0), total = active.reduce((n, c) => n + c.total, 0);
  if (projects.length) {
    status.text = `$(checklist) ${done}/${total}`;
    status.tooltip = `OpenSpec: ${projects.reduce((n, p) => n + p.specs.length, 0)} specs, ${active.length} active changes, ${done} of ${total} tasks done`;
    status.show();
  } else { status.hide(); }
}
function reloadSoon() {
  if (reloadTimer) { clearTimeout(reloadTimer); }
  reloadTimer = setTimeout(reload, 300);
}
function select(n: Node | undefined) {
  if (!n) { return; }
  let s: Selected = null;
  if (n.kind === 'change' || n.kind === 'doc' || n.kind === 'cap' || n.kind === 'taskGroup' || n.kind === 'task') { s = { kind: 'change', project: n.project, change: n.change }; }
  else if (n.kind === 'spec') { s = { kind: 'spec', project: n.project, spec: n.spec }; }
  else if (n.kind === 'group') { s = { kind: 'group', project: n.project, id: n.id }; }
  if (s) { details.show(s); }
}

export interface Api { projects(): Project[]; plan: PlanTree; scope: ScopeTree; details: DetailsView; reload(): void }

export function activate(context: vscode.ExtensionContext): Api {
  ctx = context;
  output = vscode.window.createOutputChannel('LazySpec');
  projects = findProjects();
  plan = new PlanTree(() => projects, settings);
  scope = new ScopeTree(() => projects, settings);
  details = new DetailsView();
  status = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Left, 50);
  status.command = 'workbench.view.extension.lazyspec';
  const planView = vscode.window.createTreeView('lazyspec.plan', { treeDataProvider: plan, showCollapseAll: true });
  const scopeView = vscode.window.createTreeView('lazyspec.scope', { treeDataProvider: scope, showCollapseAll: true });
  const watchers: vscode.FileSystemWatcher[] = [];
  const watch = () => {
    watchers.splice(0).forEach(w => w.dispose());
    for (const p of projects) {
      const w = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(vscode.Uri.file(p.root), '{openspec/**,lazyspec.json,tools/lazyspec/lazyspec.json}'));
      w.onDidChange(reloadSoon); w.onDidCreate(reloadSoon); w.onDidDelete(reloadSoon);
      watchers.push(w);
    }
  };
  watch();

  const reg = (id: string, fn: (...a: any[]) => unknown) => context.subscriptions.push(vscode.commands.registerCommand(id, fn));
  reg('lazyspec.refresh', () => { projects = findProjects(); watch(); reload(); });
  reg('lazyspec.openFile', (file: string, line = 0) => openFile(file, line));
  reg('lazyspec.openItem', (arg?: unknown) => {
    const t = targetOf(arg);
    if (t?.change) { return openFile(t.change.path); }
    if (t?.spec) { return openFile(t.spec.path); }
  });
  reg('lazyspec.showDetails', (n?: Node) => { select(n); void vscode.commands.executeCommand('lazyspec.details.focus'); });
  reg('lazyspec.find', findCommand);
  reg('lazyspec.newChange', async () => {
    const p = await pickProject();
    if (!p) { return; }
    const name = await vscode.window.showInputBox({
      prompt: 'New change: its name (kebab-case)', placeHolder: 'add-user-login',
      validateInput: v => (/^[a-z0-9]+(-[a-z0-9]+)*$/.test(v.trim()) ? undefined : 'kebab-case: lowercase words with hyphens'),
    });
    if (name) { runCli(p, ['new', 'change', name.trim()], 'New change'); }
  });
  reg('lazyspec.validate', async () => { const p = await pickProject(); if (p) { runCli(p, ['validate', '--all', '--strict', '--no-interactive'], 'Validate'); } });
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
    const p = projectOfFile(file);
    await exportAs(p, ['-Markdown', file], path.basename(file), path.dirname(file));
  });
  const toggle = async (key: 'grouped' | 'showArchived') => {
    const c = vscode.workspace.getConfiguration('lazyspec');
    await c.update(key, !c.get<boolean>(key), vscode.ConfigurationTarget.Workspace);
  };
  reg('lazyspec.toggleGrouped', () => toggle('grouped'));
  reg('lazyspec.toggleArchived', () => toggle('showArchived'));
  reg('lazyspec.openConfig', async (arg?: { root?: string }) => {
    const p = arg?.root ? projectOf(arg.root) : await pickProject();
    if (p) { await openFile(path.join(p.osDir, 'config.yaml')); }
  });
  reg('lazyspec.openTui', async () => {
    const p = await pickProject();
    if (!p) { return; }
    const t = vscode.window.createTerminal({ name: `LazySpec${projects.length > 1 ? `: ${p.name}` : ''}`, shellPath: powershell(), shellArgs: psArgs(kitScript(p), ['-Root', p.root]), cwd: p.root, location: vscode.TerminalLocation.Editor });
    t.show();
  });

  context.subscriptions.push(
    output, status, planView, scopeView, { dispose: () => watchers.forEach(w => w.dispose()) },
    vscode.window.registerWebviewViewProvider('lazyspec.details', details),
    planView.onDidChangeSelection(e => select(e.selection[0])),
    scopeView.onDidChangeSelection(e => select(e.selection[0])),
    planView.onDidChangeCheckboxState(async e => {
      for (const [n, state] of e.items) {
        if (n.kind === 'task') { await setTask(n.task, state === vscode.TreeItemCheckboxState.Checked); }
      }
    }),
    scopeView.onDidChangeCheckboxState(() => undefined),
    vscode.workspace.onDidChangeConfiguration(e => {
      if (e.affectsConfiguration('lazyspec.roots')) { projects = findProjects(); watch(); }
      if (e.affectsConfiguration('lazyspec')) { reload(); }
    }),
    vscode.workspace.onDidChangeWorkspaceFolders(() => { projects = findProjects(); watch(); reload(); }),
  );
  reload();
  return { projects: () => projects, plan, scope, details, reload };
}

export function deactivate() { /* the subscriptions go with the context */ }

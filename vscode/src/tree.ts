// The Plan (changes, by group) and the Scope (specifications) as VS Code trees: a change's documents with their
// sections, its tasks to tick, its delta specs' requirements and scenarios; a spec's sections, requirements
// and scenarios. Several can be selected (delete, the agent).

import * as path from 'path';
import * as vscode from 'vscode';
import { Capability, Change, Doc, Entry, itemTitle, plainInline, Project, readText, Requirement, Spec, Task, TaskGroup } from './model';

export interface Section { title: string; line: number; level: number; children: Section[] }
type Owner = Spec | Change;

export type Node =
  | { kind: 'project'; project: Project }
  | { kind: 'group'; project: Project; id: string; changes: Change[]; done: number; total: number }
  | { kind: 'archived'; project: Project; changes: Change[] }
  | { kind: 'change'; project: Project; change: Change }
  | { kind: 'doc'; project: Project; change: Change; doc: Doc }
  | { kind: 'file'; project: Project; change: Change; file: string; label: string }
  | { kind: 'cap'; project: Project; change: Change; cap: Capability }
  | { kind: 'taskGroup'; project: Project; change: Change; group: TaskGroup }
  | { kind: 'task'; project: Project; change: Change; task: Task }
  | { kind: 'spec'; project: Project; spec: Spec }
  | { kind: 'req'; project: Project; owner: Owner; cap: string; file: string; req: Requirement }
  | { kind: 'scn'; project: Project; owner: Owner; cap: string; file: string; req: string; name: string; line: number }
  | { kind: 'sec'; project: Project; owner: Owner; file: string; section: Section };

export interface Settings { grouped: boolean; showArchived: boolean; sort: 'name' | 'name-desc' | 'recent'; documents: 'formatted' | 'preview' | 'source' }
export interface Hooks { stale(p: Project, c: Change): boolean }

/** An item clicked: its document opened at it - in the formatted editor (scrolled to it, marked) or the source. */
export function openCommand(file: string, line = 0, text = ''): vscode.Command {
  return { command: 'lazyspec.openAt', title: 'Open', arguments: [file, line, text] };
}
function docCommand(file: string): vscode.Command {
  return { command: 'lazyspec.openDocument', title: 'Open', arguments: [file] };
}

/** A document's sections (## and deeper; not the requirements' and scenarios' own, nor "## ADDED Requirements"). */
export function parseSections(file: string): Section[] {
  const lines = readText(file).replace(/\r/g, '').split('\n');
  const root: Section[] = [];
  const stack: Section[] = [];
  let fence = false;
  lines.forEach((l, i) => {
    if (l.trim().startsWith('```')) { fence = !fence; return; }
    const m = !fence && /^(#{2,6})\s+(.+?)\s*#*$/.exec(l);
    if (!m) { return; }
    const h = m[2];
    if (/^(Requirement|Zahtjev|Anforderung|Scenario|Scenarij|Szenario):/.test(h) || /^(\w+\s+)?Requirements$/i.test(h)) { return; }
    const s: Section = { title: plainInline(h), line: i + 1, level: m[1].length, children: [] };
    while (stack.length && stack[stack.length - 1].level >= s.level) { stack.pop(); }
    (stack.length ? stack[stack.length - 1].children : root).push(s);
    stack.push(s);
  });
  return root;
}

/** A tree item's own item as LazySpec's find has it (edit, delete, the agent); null: not an item. */
export function entryOf(n: Node): Entry | null {
  const base = { num: '', done: false, hay: '', art: '', cap: '', context: '' };
  switch (n.kind) {
    case 'task': return { ...base, kind: 'task', item: n.change, where: itemTitle(n.change), context: n.task.group, num: n.task.num, text: n.task.text, done: n.task.done, path: n.task.path, line: n.task.line };
    case 'req': return { ...base, kind: 'req', item: n.owner, where: itemTitle(n.owner), cap: n.cap, text: n.req.name, path: n.file, line: n.req.line };
    case 'scn': return { ...base, kind: 'scn', item: n.owner, where: itemTitle(n.owner), cap: n.cap, context: n.req, text: n.name, path: n.file, line: n.line };
    case 'sec': return { ...base, kind: 'sec', item: n.owner, where: itemTitle(n.owner), text: n.section.title, path: n.file, line: n.section.line };
    default: return null;
  }
}

function stageIcon(c: Change, stale: boolean): vscode.ThemeIcon {
  if (stale) { return new vscode.ThemeIcon('warning', new vscode.ThemeColor('charts.yellow')); }
  switch (c.stage) {
    case 'Draft': return new vscode.ThemeIcon('circle-outline', new vscode.ThemeColor('descriptionForeground'));
    case 'In Progress': return new vscode.ThemeIcon('circle-large-filled', new vscode.ThemeColor('charts.blue'));
    case 'Completed': return new vscode.ThemeIcon('pass-filled', new vscode.ThemeColor('charts.green'));
    default: return new vscode.ThemeIcon('archive', new vscode.ThemeColor('disabledForeground'));
  }
}
function capNote(c: Capability): string {
  return [c.added ? `+${c.added}` : '', c.modified ? `~${c.modified}` : '', c.removed ? `-${c.removed}` : '', c.renamed ? `${c.renamed} renamed` : ''].filter(x => x).join(' ');
}
function sortChanges(list: Change[], sort: Settings['sort']): Change[] {
  const l = [...list];
  if (sort === 'recent') { return l.sort((a, b) => b.modified - a.modified); }
  l.sort((a, b) => a.name.localeCompare(b.name));
  return sort === 'name-desc' ? l.reverse() : l;
}

abstract class BaseTree implements vscode.TreeDataProvider<Node> {
  protected readonly emitter = new vscode.EventEmitter<Node | undefined | void>();
  readonly onDidChangeTreeData = this.emitter.event;
  constructor(protected projects: () => Project[], protected settings: () => Settings, protected hooks: Hooks) { }
  refresh(): void { this.emitter.fire(); }
  abstract getChildren(node?: Node): Node[];
  getParent(): undefined { return undefined; }

  getTreeItem(n: Node): vscode.TreeItem {
    const C = vscode.TreeItemCollapsibleState;
    switch (n.kind) {
      case 'project': {
        const t = new vscode.TreeItem(n.project.name, C.Expanded);
        t.iconPath = new vscode.ThemeIcon('folder-library');
        t.description = path.basename(n.project.root);
        t.id = `project:${n.project.root}`;
        return t;
      }
      case 'group': {
        const t = new vscode.TreeItem(n.project.groupTitle(n.id), C.Expanded);
        t.description = `${n.changes.length} ${n.changes.length === 1 ? 'change' : 'changes'}  ${n.done}/${n.total}`;
        const d = n.project.groupDef(n.id);
        const md = new vscode.MarkdownString(`**${n.project.groupTitle(n.id)}**`);
        if (d?.description) { md.appendMarkdown(`\n\n${d.description}`); }
        if (d?.requires.length) { md.appendMarkdown(`\n\nRequires: ${d.requires.map(r => n.project.groupTitle(r)).join(', ')}`); }
        t.tooltip = md;
        t.iconPath = new vscode.ThemeIcon(n.id ? 'layers' : 'question');
        t.contextValue = n.id ? 'group' : 'ungrouped';
        t.id = `group:${n.project.root}:${n.id}`;
        return t;
      }
      case 'archived': {
        const t = new vscode.TreeItem('Archived', C.Collapsed);
        t.description = `${n.changes.length}`;
        t.iconPath = new vscode.ThemeIcon('archive');
        t.id = `archived:${n.project.root}`;
        return t;
      }
      case 'change': {
        const c = n.change;
        const stale = !c.archived && this.hooks.stale(n.project, c);
        const t = new vscode.TreeItem(itemTitle(c), C.Collapsed);
        t.description = (stale ? '! ' : '') + (c.total ? `${c.done}/${c.total}` : c.stage.toLowerCase());
        t.iconPath = stageIcon(c, stale);
        const md = new vscode.MarkdownString(`**${itemTitle(c)}**  \n${c.stage}, ${c.done} of ${c.total} tasks  \n\`openspec/changes/${c.archived ? 'archive/' : ''}${c.name}/\``);
        if (c.group && n.project.grouping) { md.appendMarkdown(`  \n${n.project.groupTitle(c.group)}`); }
        if (stale) { md.appendMarkdown('  \n**Out of date**: documents older than what they are written from (Sync Out-of-Date Documents)'); }
        if (c.workflow.missing) { md.appendMarkdown(`  \nworkflow '${c.workflow.missing}' not found: shown as spec-driven`); }
        t.tooltip = md;
        t.contextValue = c.archived ? 'archivedChange' : stale ? 'staleChange' : 'change';
        t.id = `change:${c.dir}`;
        return t;
      }
      case 'doc': {
        const d = n.doc;
        const has = d.isSpecs ? n.change.caps.length > 0 : d.files.length > 0;
        const isTasks = d.id === n.change.tasksDoc?.id;
        let children = false;
        if (d.isSpecs) { children = n.change.caps.length > 0; }
        else if (isTasks) { children = n.change.taskGroups.length > 0; }
        else if (d.files.length > 1) { children = true; }
        else if (d.files.length === 1) { children = parseSections(d.files[0]).length > 0; }
        const t = new vscode.TreeItem(d.isSpecs ? 'Specs' : d.title, children ? C.Collapsed : C.None);
        t.id = `doc:${n.change.dir}:${d.id}`;
        if (!has) {
          t.description = 'not yet';
          t.iconPath = new vscode.ThemeIcon('circle-outline', new vscode.ThemeColor('disabledForeground'));
          return t;
        }
        t.iconPath = new vscode.ThemeIcon(d.isSpecs ? 'symbol-class' : isTasks ? 'checklist' : 'markdown');
        if (d.isSpecs) { t.description = `${n.change.caps.length}`; }
        else if (isTasks) { t.description = `${n.change.done}/${n.change.total}`; }
        else if (d.extra) { t.description = 'not in the workflow'; }
        if (!d.isSpecs && d.files.length) { t.command = docCommand(d.files[0]); t.resourceUri = vscode.Uri.file(d.files[0]); t.contextValue = 'document'; }
        return t;
      }
      case 'file': {
        const t = new vscode.TreeItem(n.label, parseSections(n.file).length ? C.Collapsed : C.None);
        t.iconPath = new vscode.ThemeIcon('markdown');
        t.command = docCommand(n.file);
        t.resourceUri = vscode.Uri.file(n.file);
        t.contextValue = 'document';
        t.id = `file:${n.file}`;
        return t;
      }
      case 'cap': {
        const t = new vscode.TreeItem(n.cap.name, n.cap.requirements.length ? C.Collapsed : C.None);
        t.description = capNote(n.cap);
        t.iconPath = new vscode.ThemeIcon('symbol-module');
        t.command = docCommand(n.cap.path);
        t.resourceUri = vscode.Uri.file(n.cap.path);
        t.contextValue = 'document';
        t.id = `cap:${n.cap.path}`;
        return t;
      }
      case 'taskGroup': {
        const g = n.group;
        const done = g.tasks.filter(x => x.done).length;
        const t = new vscode.TreeItem(g.title || 'Tasks', C.Collapsed);
        t.description = `${done}/${g.tasks.length}`;
        t.iconPath = new vscode.ThemeIcon(done === g.tasks.length ? 'pass' : done ? 'circle-large-filled' : 'circle-outline');
        t.command = openCommand(g.path, g.line, g.title);
        t.id = `tg:${g.path}:${g.line}`;
        return t;
      }
      case 'task': {
        const k = n.task;
        const t = new vscode.TreeItem(k.text, C.None);
        t.checkboxState = k.done ? vscode.TreeItemCheckboxState.Checked : vscode.TreeItemCheckboxState.Unchecked;
        t.command = openCommand(k.path, k.line, k.text);
        t.tooltip = `${k.text}\n${path.basename(k.path)}:${k.line}`;
        t.contextValue = 'item.task';
        t.id = `task:${k.path}:${k.line}`;
        return t;
      }
      case 'spec': {
        const s = n.spec;
        const t = new vscode.TreeItem(itemTitle(s), C.Collapsed);
        t.description = `${s.reqs} req`;
        t.iconPath = new vscode.ThemeIcon(s.platform ? 'book' : 'symbol-class', new vscode.ThemeColor(s.platform ? 'charts.blue' : 'charts.green'));
        t.tooltip = new vscode.MarkdownString(`**${itemTitle(s)}**  \n${s.reqs} requirements, ${s.scenarioCount} scenarios  \n\`openspec/specs/${s.name}/spec.md\``);
        t.contextValue = 'spec';
        t.id = `spec:${s.path}`;
        return t;
      }
      case 'req': {
        const r = n.req;
        const t = new vscode.TreeItem(r.name, r.scenarios.length ? C.Collapsed : C.None);
        t.iconPath = new vscode.ThemeIcon('symbol-field', r.op === 'REMOVED' ? new vscode.ThemeColor('charts.red') : r.op === 'MODIFIED' ? new vscode.ThemeColor('charts.yellow') : undefined);
        if (r.op) { t.description = r.op.toLowerCase(); }
        t.command = openCommand(n.file, r.line, r.name);
        t.contextValue = 'item.req';
        t.id = `req:${n.file}:${r.line}`;
        return t;
      }
      case 'scn': {
        const t = new vscode.TreeItem(n.name, C.None);
        t.iconPath = new vscode.ThemeIcon('symbol-event');
        t.command = openCommand(n.file, n.line, n.name);
        t.contextValue = 'item.scn';
        t.id = `scn:${n.file}:${n.line}`;
        return t;
      }
      case 'sec': {
        const t = new vscode.TreeItem(n.section.title, n.section.children.length ? C.Collapsed : C.None);
        t.iconPath = new vscode.ThemeIcon('symbol-key');
        t.command = openCommand(n.file, n.section.line, n.section.title);
        t.contextValue = 'item.sec';
        t.id = `sec:${n.file}:${n.section.line}`;
        return t;
      }
    }
  }

  private sections(project: Project, owner: Owner, file: string, list: Section[]): Node[] {
    return list.map(section => ({ kind: 'sec', project, owner, file, section }) as Node);
  }
  private reqs(project: Project, owner: Owner, cap: string, file: string, reqs: Requirement[]): Node[] {
    return reqs.map(req => ({ kind: 'req', project, owner, cap, file, req }) as Node);
  }
  /** The children every kind of node shares (below a change, a spec). */
  protected detailChildren(n: Node): Node[] {
    switch (n.kind) {
      case 'change': return n.change.docs.map(doc => ({ kind: 'doc', project: n.project, change: n.change, doc }) as Node);
      case 'doc': {
        const { change, doc, project } = n;
        if (doc.isSpecs) { return change.caps.map(cap => ({ kind: 'cap', project, change, cap }) as Node); }
        if (doc.id === change.tasksDoc?.id) { return change.taskGroups.map(group => ({ kind: 'taskGroup', project, change, group }) as Node); }
        if (doc.files.length === 1) { return this.sections(project, change, doc.files[0], parseSections(doc.files[0])); }
        return doc.files.map(file => ({ kind: 'file', project, change, file, label: path.relative(change.dir, file).replace(/\\/g, '/') }) as Node);
      }
      case 'file': return this.sections(n.project, n.change, n.file, parseSections(n.file));
      case 'cap': return this.reqs(n.project, n.change, n.cap.name, n.cap.path, n.cap.requirements);
      case 'taskGroup': return n.group.tasks.map(task => ({ kind: 'task', project: n.project, change: n.change, task }) as Node);
      case 'spec': return [...this.sections(n.project, n.spec, n.spec.path, parseSections(n.spec.path)), ...this.reqs(n.project, n.spec, '', n.spec.path, n.spec.requirements)];
      case 'req': return n.req.scenarios.map(s => ({ kind: 'scn', project: n.project, owner: n.owner, cap: n.cap, file: n.file, req: n.req.name, name: s.name, line: s.line }) as Node);
      case 'sec': return this.sections(n.project, n.owner, n.file, n.section.children);
      default: return [];
    }
  }
}

export class PlanTree extends BaseTree {
  getChildren(node?: Node): Node[] {
    const ps = this.projects();
    if (!node) {
      if (ps.length === 1) { return this.planOf(ps[0]); }
      return ps.map(project => ({ kind: 'project', project }) as Node);
    }
    if (node.kind === 'project') { return this.planOf(node.project); }
    if (node.kind === 'group' || node.kind === 'archived') { return node.changes.map(change => ({ kind: 'change', project: node.project, change }) as Node); }
    return this.detailChildren(node);
  }
  /** A project's plan: by group (by id, ungrouped last) or flat; archived changes after, when shown. */
  private planOf(project: Project): Node[] {
    const s = this.settings();
    const active = sortChanges(project.changes.filter(c => !c.archived), s.sort);
    const out: Node[] = s.grouped && project.grouping
      ? project.groups(active).map(g => ({ kind: 'group', project, ...g }) as Node)
      : active.map(change => ({ kind: 'change', project, change }) as Node);
    const arch = project.changes.filter(c => c.archived).sort((a, b) => a.name.localeCompare(b.name));
    if (s.showArchived && arch.length) { out.push({ kind: 'archived', project, changes: arch }); }
    return out;
  }
}

export class ScopeTree extends BaseTree {
  getChildren(node?: Node): Node[] {
    const ps = this.projects();
    if (!node) {
      if (ps.length === 1) { return ps[0].specs.map(spec => ({ kind: 'spec', project: ps[0], spec }) as Node); }
      return ps.map(project => ({ kind: 'project', project }) as Node);
    }
    if (node.kind === 'project') { return node.project.specs.map(spec => ({ kind: 'spec', project: node.project, spec }) as Node); }
    return this.detailChildren(node);
  }
}

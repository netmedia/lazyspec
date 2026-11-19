// The Plan (changes, by group) and the Scope (specifications) as VS Code trees: a change's documents, its
// tasks to tick, its delta specs' requirements and scenarios; a spec's requirements and scenarios.

import * as path from 'path';
import * as vscode from 'vscode';
import { Capability, Change, Doc, itemTitle, Project, Requirement, Spec, Task, TaskGroup } from './model';

export type Node =
  | { kind: 'project'; project: Project }
  | { kind: 'group'; project: Project; id: string; changes: Change[]; done: number; total: number }
  | { kind: 'archived'; project: Project; changes: Change[] }
  | { kind: 'change'; project: Project; change: Change }
  | { kind: 'doc'; project: Project; change: Change; doc: Doc }
  | { kind: 'file'; project: Project; file: string; label: string }
  | { kind: 'cap'; project: Project; change: Change; cap: Capability }
  | { kind: 'taskGroup'; project: Project; change: Change; group: TaskGroup }
  | { kind: 'task'; project: Project; change: Change; task: Task }
  | { kind: 'spec'; project: Project; spec: Spec }
  | { kind: 'req'; project: Project; file: string; req: Requirement }
  | { kind: 'scn'; project: Project; file: string; name: string; line: number };

export interface Settings { grouped: boolean; showArchived: boolean }

export function openCommand(file: string, line = 0): vscode.Command {
  return { command: 'lazyspec.openFile', title: 'Open', arguments: [file, line] };
}
function stageIcon(c: Change): vscode.ThemeIcon {
  switch (c.stage) {
    case 'Draft': return new vscode.ThemeIcon('circle-outline', new vscode.ThemeColor('descriptionForeground'));
    case 'In Progress': return new vscode.ThemeIcon('circle-large-filled', new vscode.ThemeColor('charts.blue'));
    case 'Completed': return new vscode.ThemeIcon('pass-filled', new vscode.ThemeColor('charts.green'));
    default: return new vscode.ThemeIcon('archive', new vscode.ThemeColor('disabledForeground'));
  }
}
function capNote(c: Capability): string {
  const parts: string[] = [];
  if (c.added) { parts.push(`+${c.added}`); }
  if (c.modified) { parts.push(`~${c.modified}`); }
  if (c.removed) { parts.push(`-${c.removed}`); }
  if (c.renamed) { parts.push(`${c.renamed} renamed`); }
  return parts.join(' ');
}
function reqChildren(project: Project, file: string, reqs: Requirement[]): Node[] {
  return reqs.map(req => ({ kind: 'req', project, file, req }) as Node);
}

abstract class BaseTree implements vscode.TreeDataProvider<Node> {
  protected readonly emitter = new vscode.EventEmitter<Node | undefined | void>();
  readonly onDidChangeTreeData = this.emitter.event;
  constructor(protected projects: () => Project[], protected settings: () => Settings) { }
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
        const t = new vscode.TreeItem(itemTitle(c), C.Collapsed);
        t.description = c.total ? `${c.done}/${c.total}` : c.stage.toLowerCase();
        t.iconPath = stageIcon(c);
        const md = new vscode.MarkdownString(`**${itemTitle(c)}**  \n${c.stage}, ${c.done} of ${c.total} tasks  \n\`openspec/changes/${c.archived ? 'archive/' : ''}${c.name}/\``);
        if (c.group && n.project.grouping) { md.appendMarkdown(`  \n${n.project.groupTitle(c.group)}`); }
        if (c.workflow.missing) { md.appendMarkdown(`  \n$(warning) workflow '${c.workflow.missing}' not found: shown as spec-driven`); md.supportThemeIcons = true; }
        t.tooltip = md;
        t.contextValue = c.archived ? 'archivedChange' : 'change';
        t.resourceUri = vscode.Uri.file(c.dir);
        t.id = `change:${c.dir}`;
        return t;
      }
      case 'doc': {
        const d = n.doc;
        const has = d.isSpecs ? n.change.caps.length > 0 : d.files.length > 0;
        const many = d.isSpecs ? n.change.caps.length > 0 : d.id === n.change.tasksDoc?.id ? n.change.taskGroups.length > 0 : d.files.length > 1;
        const t = new vscode.TreeItem(d.isSpecs ? 'Specs' : d.title, many ? C.Collapsed : C.None);
        t.id = `doc:${n.change.dir}:${d.id}`;
        if (!has) {
          t.description = 'not yet';
          t.iconPath = new vscode.ThemeIcon('circle-outline', new vscode.ThemeColor('disabledForeground'));
          return t;
        }
        t.iconPath = new vscode.ThemeIcon(d.isSpecs ? 'symbol-class' : d.id === n.change.tasksDoc?.id ? 'checklist' : 'markdown');
        if (d.isSpecs) { t.description = `${n.change.caps.length}`; }
        else if (d.id === n.change.tasksDoc?.id) { t.description = `${n.change.done}/${n.change.total}`; }
        else if (d.extra) { t.description = 'not in the workflow'; }
        if (!d.isSpecs && d.files.length) { t.command = openCommand(d.files[0]); t.resourceUri = vscode.Uri.file(d.files[0]); t.contextValue = 'document'; }
        return t;
      }
      case 'file': {
        const t = new vscode.TreeItem(n.label, C.None);
        t.iconPath = new vscode.ThemeIcon('markdown');
        t.command = openCommand(n.file);
        t.resourceUri = vscode.Uri.file(n.file);
        t.contextValue = 'document';
        return t;
      }
      case 'cap': {
        const t = new vscode.TreeItem(n.cap.name, n.cap.requirements.length ? C.Collapsed : C.None);
        t.description = capNote(n.cap);
        t.iconPath = new vscode.ThemeIcon('symbol-module');
        t.command = openCommand(n.cap.path);
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
        t.command = openCommand(g.path, g.line);
        t.id = `tg:${g.path}:${g.line}`;
        return t;
      }
      case 'task': {
        const k = n.task;
        const t = new vscode.TreeItem(k.text, C.None);
        t.checkboxState = k.done ? vscode.TreeItemCheckboxState.Checked : vscode.TreeItemCheckboxState.Unchecked;
        t.command = openCommand(k.path, k.line);
        t.tooltip = `${k.text}\n${path.basename(k.path)}:${k.line}`;
        t.contextValue = 'task';
        t.id = `task:${k.path}:${k.line}`;
        return t;
      }
      case 'spec': {
        const s = n.spec;
        const t = new vscode.TreeItem(itemTitle(s), s.requirements.length ? C.Collapsed : C.None);
        t.description = `${s.reqs} req`;
        t.iconPath = new vscode.ThemeIcon(s.platform ? 'book' : 'symbol-class', new vscode.ThemeColor(s.platform ? 'charts.blue' : 'charts.green'));
        t.tooltip = new vscode.MarkdownString(`**${itemTitle(s)}**  \n${s.reqs} requirements, ${s.scenarioCount} scenarios  \n\`openspec/specs/${s.name}/spec.md\``);
        t.contextValue = 'spec';
        t.resourceUri = vscode.Uri.file(s.path);
        t.id = `spec:${s.path}`;
        return t;
      }
      case 'req': {
        const r = n.req;
        const t = new vscode.TreeItem(r.name, r.scenarios.length ? C.Collapsed : C.None);
        t.iconPath = new vscode.ThemeIcon('symbol-field', r.op === 'REMOVED' ? new vscode.ThemeColor('charts.red') : r.op === 'MODIFIED' ? new vscode.ThemeColor('charts.yellow') : undefined);
        if (r.op) { t.description = r.op.toLowerCase(); }
        t.command = openCommand(n.file, r.line);
        t.id = `req:${n.file}:${r.line}`;
        return t;
      }
      case 'scn': {
        const t = new vscode.TreeItem(n.name, C.None);
        t.iconPath = new vscode.ThemeIcon('symbol-event');
        t.command = openCommand(n.file, n.line);
        t.id = `scn:${n.file}:${n.line}`;
        return t;
      }
    }
  }

  /** The children every kind of node shares (below a change, a spec). */
  protected detailChildren(n: Node): Node[] {
    switch (n.kind) {
      case 'change': return n.change.docs.map(doc => ({ kind: 'doc', project: n.project, change: n.change, doc }) as Node);
      case 'doc': {
        const { change, doc, project } = n;
        if (doc.isSpecs) { return change.caps.map(cap => ({ kind: 'cap', project, change, cap }) as Node); }
        if (doc.id === change.tasksDoc?.id) { return change.taskGroups.map(group => ({ kind: 'taskGroup', project, change, group }) as Node); }
        return doc.files.map(file => ({ kind: 'file', project, file, label: path.relative(change.dir, file).replace(/\\/g, '/') }) as Node);
      }
      case 'cap': return reqChildren(n.project, n.cap.path, n.cap.requirements);
      case 'taskGroup': return n.group.tasks.map(task => ({ kind: 'task', project: n.project, change: n.change, task }) as Node);
      case 'spec': return reqChildren(n.project, n.spec.path, n.spec.requirements);
      case 'req': return n.req.scenarios.map(s => ({ kind: 'scn', project: n.project, file: n.file, name: s.name, line: s.line }) as Node);
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
    if (node.kind === 'group') { return node.changes.map(change => ({ kind: 'change', project: node.project, change }) as Node); }
    if (node.kind === 'archived') { return node.changes.map(change => ({ kind: 'change', project: node.project, change }) as Node); }
    return this.detailChildren(node);
  }
  /** A project's plan: by group (by id, ungrouped last) or flat; archived changes after, when shown. */
  private planOf(project: Project): Node[] {
    const active = project.changes.filter(c => !c.archived).sort((a, b) => a.name.localeCompare(b.name));
    const s = this.settings();
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

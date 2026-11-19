// Undo: every change to openspec/ since the last git commit (yours, LazySpec's or the agent's), by file and by
// piece; a piece's diff on a click; a piece undone, or a whole file put back as committed. A commit empties it.

import * as path from 'path';
import * as vscode from 'vscode';
import { Project } from './model';
import { git, Hunk, hunkSummary, undoFile, UndoFile, undoHunk, undoRows } from './ops';

export type UndoNode =
  | { kind: 'project'; project: Project; files: UndoFile[] }
  | { kind: 'file'; project: Project; file: UndoFile }
  | { kind: 'hunk'; project: Project; file: UndoFile; hunk: Hunk }
  | { kind: 'none'; text: string };

/** HEAD's version of a file: lazyspec-head:/<rel>?<root>. */
export class HeadContent implements vscode.TextDocumentContentProvider {
  static scheme = 'lazyspec-head';
  static uri(root: string, rel: string): vscode.Uri { return vscode.Uri.from({ scheme: HeadContent.scheme, path: '/' + rel, query: root }); }
  provideTextDocumentContent(uri: vscode.Uri): string {
    return git(uri.query, ['show', `HEAD:${uri.path.replace(/^\//, '')}`]).out;
  }
}

export class UndoTree implements vscode.TreeDataProvider<UndoNode> {
  private readonly emitter = new vscode.EventEmitter<void>();
  readonly onDidChangeTreeData = this.emitter.event;
  private rows = new Map<string, UndoFile[] | null>();
  constructor(private projects: () => Project[]) { }

  refresh() { this.rows.clear(); this.emitter.fire(); }
  private rowsOf(p: Project): UndoFile[] | null {
    if (!this.rows.has(p.root)) { this.rows.set(p.root, undoRows(p.root)); }
    return this.rows.get(p.root)!;
  }
  count(): number { return this.projects().reduce((n, p) => n + (this.rowsOf(p)?.length || 0), 0); }

  getChildren(n?: UndoNode): UndoNode[] {
    const ps = this.projects();
    if (!n) {
      if (ps.length === 1) { return this.filesOf(ps[0]); }
      return ps.map(project => ({ kind: 'project', project, files: this.rowsOf(project) || [] }) as UndoNode);
    }
    if (n.kind === 'project') { return this.filesOf(n.project); }
    if (n.kind === 'file') { return n.file.hunks.map(hunk => ({ kind: 'hunk', project: n.project, file: n.file, hunk }) as UndoNode); }
    return [];
  }
  private filesOf(project: Project): UndoNode[] {
    const rows = this.rowsOf(project);
    if (rows === null) { return [{ kind: 'none', text: 'Undo needs git: this project is not a git repository.' }]; }
    if (!rows.length) { return [{ kind: 'none', text: 'Nothing changed in openspec/ since the last commit.' }]; }
    return rows.map(file => ({ kind: 'file', project, file }) as UndoNode);
  }
  getTreeItem(n: UndoNode): vscode.TreeItem {
    const C = vscode.TreeItemCollapsibleState;
    if (n.kind === 'none') { const t = new vscode.TreeItem(n.text, C.None); t.iconPath = new vscode.ThemeIcon('info'); return t; }
    if (n.kind === 'project') { const t = new vscode.TreeItem(n.project.name, C.Expanded); t.description = `${n.files.length}`; return t; }
    if (n.kind === 'file') {
      const f = n.file;
      const t = new vscode.TreeItem(f.rel.replace(/^openspec\//, ''), f.hunks.length ? C.Expanded : C.None);
      t.description = f.kind === 'changed' ? `${f.hunks.length} piece${f.hunks.length === 1 ? '' : 's'}` : f.kind;
      t.iconPath = new vscode.ThemeIcon(f.kind === 'new' ? 'diff-added' : f.kind === 'deleted' ? 'diff-removed' : 'diff-modified');
      t.contextValue = 'undoFile';
      t.command = { command: 'lazyspec.undoShow', title: 'Show', arguments: [n] };
      t.tooltip = f.kind === 'new' ? 'New since the last commit (undo: deleted)' : f.kind === 'deleted' ? 'Deleted since the last commit (undo: back as committed)' : 'Changed since the last commit (undo: back as committed)';
      return t;
    }
    const s = hunkSummary(n.hunk);
    const t = new vscode.TreeItem(s.text || '(blank lines)', C.None);
    t.description = [s.minus ? `-${s.minus}` : '', s.plus ? `+${s.plus}` : ''].filter(x => x).join(' ');
    t.iconPath = new vscode.ThemeIcon(s.plus && s.minus ? 'diff-modified' : s.plus ? 'diff-added' : 'diff-removed');
    t.tooltip = new vscode.MarkdownString('```diff\n' + n.hunk.lines.slice(0, 30).join('\n') + '\n```');
    t.contextValue = 'undoHunk';
    t.command = { command: 'lazyspec.undoShow', title: 'Show', arguments: [n] };
    return t;
  }
}

/** A file's or a piece's diff against the last commit. */
export async function showUndo(n: UndoNode) {
  if (n.kind !== 'file' && n.kind !== 'hunk') { return; }
  const f = n.file;
  const file = path.join(n.project.root, f.rel);
  if (f.kind === 'new') { await vscode.window.showTextDocument(vscode.Uri.file(file)); return; }
  if (f.kind === 'deleted') { await vscode.window.showTextDocument(HeadContent.uri(n.project.root, f.rel)); return; }
  const line = n.kind === 'hunk' ? Math.max(0, n.hunk.newStart - 1) : 0;
  await vscode.commands.executeCommand('vscode.diff', HeadContent.uri(n.project.root, f.rel), vscode.Uri.file(file), `${path.basename(f.rel)} (last commit ↔ now)`, { selection: new vscode.Range(line, 0, line, 0), preview: true });
}
/** Undone, asked first. */
export async function undo(n: UndoNode): Promise<boolean> {
  if (n.kind !== 'file' && n.kind !== 'hunk') { return false; }
  const text = n.kind === 'hunk' ? `Undo this piece of ${path.basename(n.file.rel)}?` : n.file.kind === 'new' ? `Delete the new file ${n.file.rel}?` : `Put ${n.file.rel} back as it was committed (all its changes undone)?`;
  const ok = await vscode.window.showWarningMessage(text, { modal: true }, n.kind === 'hunk' ? 'Undo' : n.file.kind === 'new' ? 'Delete' : 'Put Back');
  if (!ok) { return false; }
  try {
    if (n.kind === 'hunk') { undoHunk(n.project.root, n.hunk); } else { undoFile(n.project.root, n.file); }
    return true;
  } catch (e) { void vscode.window.showErrorMessage(`Not undone: ${(e as Error).message}`); return false; }
}

// What can be done to an item (a task, requirement, scenario or section) - from the trees, Read and find: edit,
// tick, delete, hand to the agent. As LazySpec does it: a main spec is changed through a change.

import * as path from 'path';
import * as vscode from 'vscode';
import { agentTask } from './agent';
import { Entry, Project, setTaskDone } from './model';
import { itemBlock, kindWord, newModifyChange, removeEntries, revisionPrompt, setTaskText } from './ops';

export interface ItemContext { projectOfFile(file: string): Project | undefined; reload(): void; openFile(file: string, line?: number): Promise<void>; formatted?(e: Entry, viaChange: boolean): void }

/** The item's lines selected in its file (the editor: the item's block, as LazySpec's edit window). */
export async function openBlock(e: Entry) {
  const b = itemBlock(e);
  const doc = await vscode.workspace.openTextDocument(e.path);
  const editor = await vscode.window.showTextDocument(doc, { preview: false });
  if (!b) { return; }
  const last = Math.min(doc.lineCount - 1, b.at + b.lines.length - 1);
  editor.selection = new vscode.Selection(b.at, 0, last, doc.lineAt(last).text.length);
  editor.revealRange(editor.selection, vscode.TextEditorRevealType.InCenterIfOutsideViewport);
}

/** Edit: in the formatted editor (lazyspec.editor: formatted, the default), else the Markdown itself. */
function formattedOn(): boolean { return vscode.workspace.getConfiguration('lazyspec').get<string>('editor', 'formatted') !== 'source'; }
export async function editItem(ctx: ItemContext, e: Entry) {
  const p = ctx.projectOfFile(e.path);
  if (!p) { return; }
  if (!itemBlock(e)) { void vscode.window.showWarningMessage(`This ${kindWord(e.kind)} is not there any more: refreshed.`); ctx.reload(); return; }
  // A main spec's requirement or scenario: through a change (as OpenSpec wants it), or directly.
  if (e.item.type === 'spec' && e.kind !== 'sec') {
    const how = await vscode.window.showQuickPick([
      { label: '$(git-pull-request) Through a change', description: 'a new change with it under MODIFIED Requirements (archive it to apply it)', v: 'change' },
      { label: '$(edit) Edit it directly', description: 'in openspec/specs', v: 'direct' },
    ], { placeHolder: `A main spec's ${kindWord(e.kind)}: "${e.text}"` });
    if (!how) { return; }
    // The formatted editor: the item alone; saved through the change or directly.
    if (ctx.formatted && formattedOn()) { ctx.formatted(e, how.v === 'change'); return; }
    if (how.v === 'change') {
      const { name, file } = newModifyChange(p, e);
      ctx.reload();
      const doc = await vscode.workspace.openTextDocument(file);
      const ed = await vscode.window.showTextDocument(doc, { preview: false });
      ed.selection = new vscode.Selection(2, 0, doc.lineCount - 1, 0);
      void vscode.window.showInformationMessage(`Edit it in the change ${name} (MODIFIED); archive the change to apply it to the specs.`);
      return;
    }
  }
  if (ctx.formatted && formattedOn()) { ctx.formatted(e, false); return; }
  // A task's text: in place (its box and number kept); the whole task (with what's under it) in the file.
  if (e.kind === 'task') {
    const lineText = (await vscode.workspace.openTextDocument(e.path)).lineAt(e.line - 1).text;
    const m = /^\s*[-*]\s+\[[ xX]\]\s+(.*)$/.exec(lineText);
    if (m) {
      const v = await vscode.window.showInputBox({ prompt: 'The task (Enter saves; Escape, then "Edit in the File" for the lines under it)', value: m[1], valueSelection: [m[1].length, m[1].length] });
      if (v === undefined || v === m[1]) { return; }
      try { setTaskText(e.path, e.line, v); } catch (x) { void vscode.window.showErrorMessage((x as Error).message); }
      ctx.reload();
      return;
    }
  }
  await openBlock(e);
}

export async function toggleTask(ctx: ItemContext, e: Entry, done?: boolean) {
  if (e.kind !== 'task') { return; }
  const doc = await vscode.workspace.openTextDocument(e.path);
  const wasDirty = doc.isDirty;
  // The line it was on, else the line with its text (the file changed since).
  const isIt = (i: number) => i >= 0 && i < doc.lineCount && /^\s*[-*]\s+\[[ xX]\]/.test(doc.lineAt(i).text) && doc.lineAt(i).text.includes(e.text.slice(0, 20));
  let line = e.line - 1;
  if (!isIt(line)) { line = -1; for (let i = 0; i < doc.lineCount; i++) { if (isIt(i)) { line = i; break; } } }
  if (line < 0) { void vscode.window.showWarningMessage(`The task isn't in ${path.basename(e.path)} any more: refreshed.`); ctx.reload(); return; }
  const text = doc.lineAt(line).text;
  const now = done ?? !/^\s*[-*]\s+\[[xX]\]/.test(text);
  const edit = new vscode.WorkspaceEdit();
  edit.replace(doc.uri, doc.lineAt(line).range, setTaskDone(text, now));
  await vscode.workspace.applyEdit(edit);
  if (!wasDirty) { await doc.save(); }
  ctx.reload();
}

/** Delete, asked first; then what it did (and Undo). */
export async function deleteItems(ctx: ItemContext, entries: Entry[]) {
  if (!entries.length) { return; }
  const p = ctx.projectOfFile(entries[0].path);
  if (!p) { return; }
  const n: Record<string, number> = {};
  for (const e of entries) { n[e.kind] = (n[e.kind] || 0) + 1; }
  let what = Object.entries(n).map(([k, c]) => `${c} ${kindWord(k as Entry['kind'])}${c === 1 ? '' : 's'}`).join(', ');
  if (entries.length === 1) { what = `the ${kindWord(entries[0].kind)} "${entries[0].text.slice(0, 60)}"`; }
  const main = entries.some(e => e.item.type === 'spec' && e.kind !== 'sec');
  const ok = await vscode.window.showWarningMessage(`Delete ${what}?`, { modal: true, detail: main ? 'From the main specs: through a new change (REMOVED / MODIFIED requirements); archive it to apply it.' : 'Undo (the LazySpec Undo view) puts it back until the next commit.' }, 'Delete');
  if (!ok) { return; }
  let report: string[];
  try { report = removeEntries(p, entries); } catch (x) { void vscode.window.showErrorMessage(`Not deleted: ${(x as Error).message}`); return; }
  ctx.reload();
  const pick = await vscode.window.showInformationMessage(`Deleted: ${report.map(r => r.replace(/^[-+!] /, '')).join('; ')}`, 'Undo...', 'Validate');
  if (pick === 'Undo...') { void vscode.commands.executeCommand('lazyspec.undo.focus'); }
  if (pick === 'Validate') { void vscode.commands.executeCommand('lazyspec.validate', { root: p.root }); }
}

/** The agent: change them (your note) or write them again (from the specs). */
export async function agentItems(ctx: ItemContext, entries: Entry[]) {
  if (!entries.length) { return; }
  const p = ctx.projectOfFile(entries[0].path);
  if (!p) { return; }
  const n = entries.length === 1 ? `"${entries[0].text.slice(0, 50)}"` : `${entries.length} items`;
  const how = await vscode.window.showQuickPick([
    { label: '$(edit) Change it', description: 'your note says how', v: 'change' as const },
    { label: '$(refresh) Write it again', description: 'so that it matches the current specs, proposal and design', v: 'redo' as const },
  ], { placeHolder: `The agent (Claude Code): ${n}` });
  if (!how) { return; }
  let note = '';
  if (how.v === 'change') {
    note = (await vscode.window.showInputBox({ prompt: `Change ${n}: what to change (the agent does it)` })) || '';
    if (!note) { return; }
  }
  await agentTask(p, `${how.v === 'change' ? 'Change' : 'Redo'} ${entries.length} item(s)`, how.v, revisionPrompt(p, entries, how.v, note));
}

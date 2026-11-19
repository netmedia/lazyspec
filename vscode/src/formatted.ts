// The formatted editor: a document, or one item of it, edited as formatted text (Milkdown in a webview: headings,
// bold, lists, task lists, tables ... from a bar on top), its Markdown written back - only the lines the edit
// changed (mdmerge), the rest as it was.

import * as vscode from 'vscode';
import { Entry } from './model';
import { mergeEdit } from './mdmerge';
import { itemBlock, kindWord, newModifyChange, writeItemEdit } from './ops';
import { ItemContext } from './items';

interface Button { id: string; label: string; title?: string; primary?: boolean }
type Msg = { type: string; markdown?: string; id?: string };

/** The page: the editor's script and styles (out/webview), its bar of buttons; the Markdown comes by message. */
function page(webview: vscode.Webview, ext: vscode.Uri, title: string): string {
  const js = webview.asWebviewUri(vscode.Uri.joinPath(ext, 'out', 'webview', 'editor.js'));
  const css = webview.asWebviewUri(vscode.Uri.joinPath(ext, 'out', 'webview', 'editor.css'));
  return `<!DOCTYPE html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${webview.cspSource} https: data:; font-src ${webview.cspSource} data:; style-src ${webview.cspSource} 'unsafe-inline'; script-src ${webview.cspSource};">
<link rel="stylesheet" href="${css}"><title>${title.replace(/</g, '&lt;')}</title></head>
<body><div id="lazyspec-bar"></div><div id="editor"></div><script src="${js}"></script></body></html>`;
}

/** Markdown files opened formatted (Open With..., or LazySpec's "Formatted"): saved as the file itself. */
export class FormattedEditorProvider implements vscode.CustomTextEditorProvider {
  static readonly viewType = 'lazyspec.formatted';
  constructor(private readonly ext: vscode.Uri) { }

  resolveCustomTextEditor(doc: vscode.TextDocument, panel: vscode.WebviewPanel): void {
    panel.webview.options = { enableScripts: true, localResourceRoots: [vscode.Uri.joinPath(this.ext, 'out', 'webview'), vscode.Uri.joinPath(doc.uri, '..')] };
    panel.webview.html = page(panel.webview, this.ext, doc.fileName);
    let original = '', before = '', applying = false, lastSent = '';
    const load = () => {
      original = doc.getText().replace(/\r/g, '');
      before = '';
      void panel.webview.postMessage({ type: 'load', markdown: original, buttons: [
        { id: 'source', label: 'Source', title: 'The Markdown itself' },
        { id: 'preview', label: 'Preview', title: 'Read-only, as VS Code shows Markdown' },
      ] });
    };
    const sub = vscode.workspace.onDidChangeTextDocument(e => {
      // Changed elsewhere (the source, git, the agent): the editor again, from the file.
      if (e.document.uri.toString() !== doc.uri.toString() || applying || !e.contentChanges.length) { return; }
      if (doc.getText().replace(/\r/g, '') === lastSent) { return; }
      load();
    });
    panel.onDidDispose(() => sub.dispose());
    panel.webview.onDidReceiveMessage(async (m: Msg) => {
      if (m.type === 'init') { load(); }
      else if (m.type === 'ready') { before = m.markdown || ''; }
      else if (m.type === 'change' && before) {
        // Only what was edited: the rest of the file as it was.
        let text = mergeEdit(original, before, m.markdown || '');
        lastSent = text;
        if (doc.eol === vscode.EndOfLine.CRLF) { text = text.replace(/\n/g, '\r\n'); }
        if (text === doc.getText()) { return; }
        const edit = new vscode.WorkspaceEdit();
        edit.replace(doc.uri, new vscode.Range(0, 0, doc.lineCount, 0), text);
        applying = true;
        try { await vscode.workspace.applyEdit(edit); } finally { applying = false; }
      }
      else if (m.type === 'button' && m.id === 'source') { await vscode.commands.executeCommand('vscode.openWith', doc.uri, 'default'); }
      else if (m.type === 'button' && m.id === 'preview') { await vscode.commands.executeCommand('markdown.showPreview', doc.uri); }
      else if (m.type === 'button' && m.id === 'save') { await doc.save(); }
    });
  }
}

/** One item (a task, requirement, scenario, section) in the formatted editor, alone: Save writes its lines back
 *  where they are (a main spec's: through a change, MODIFIED, when $viaChange); Cancel leaves the file as it is. */
export function editItemFormatted(ext: vscode.Uri, ctx: ItemContext, e: Entry, viaChange: boolean) {
  const block = itemBlock(e);
  if (!block) { void vscode.window.showWarningMessage(`This ${kindWord(e.kind)} is not there any more: refreshed.`); ctx.reload(); return; }
  const original = block.lines.join('\n');
  const panel = vscode.window.createWebviewPanel('lazyspec.itemEditor', `Edit: ${e.text.slice(0, 40)}`, vscode.ViewColumn.Active, { enableScripts: true, retainContextWhenHidden: true, localResourceRoots: [vscode.Uri.joinPath(ext, 'out', 'webview')] });
  panel.webview.html = page(panel.webview, ext, e.text);
  let before = '', now = '', saved = false;
  const where = viaChange ? 'through a new change (MODIFIED)' : `in ${vscode.workspace.asRelativePath(e.path)}`;
  panel.webview.onDidReceiveMessage(async (m: Msg) => {
    if (m.type === 'init') {
      void panel.webview.postMessage({ type: 'load', markdown: original, note: `The ${kindWord(e.kind)} "${e.text}", saved ${where}`, buttons: [
        { id: 'save', label: 'Save', title: 'Ctrl+S', primary: true },
        { id: 'cancel', label: 'Cancel' },
        { id: 'file', label: 'Edit in the File', title: 'The Markdown itself, its lines selected' },
      ] });
    }
    else if (m.type === 'ready') { before = now = m.markdown || ''; }
    else if (m.type === 'change') { now = m.markdown || ''; }
    else if (m.type === 'button' && m.id === 'cancel') { saved = true; panel.dispose(); }
    else if (m.type === 'button' && m.id === 'file') { saved = true; panel.dispose(); await vscode.commands.executeCommand('lazyspec.openBlock', e); }
    else if (m.type === 'button' && m.id === 'save') {
      const lines = mergeEdit(original, before, now).replace(/\s+$/, '').split('\n');
      if (lines.join('\n') === original) { saved = true; panel.dispose(); return; }
      try {
        const p = ctx.projectOfFile(e.path);
        if (viaChange && p) {
          const { name } = newModifyChange(p, e, lines);
          void vscode.window.showInformationMessage(`Saved in the change ${name} (MODIFIED); archive it to apply it to the specs.`);
        } else {
          writeItemEdit(e.path, e.line, block.lines, lines);
          void vscode.window.showInformationMessage(`Saved: the ${kindWord(e.kind)} in ${vscode.workspace.asRelativePath(e.path)}.`);
        }
        saved = true;
        panel.dispose();
        ctx.reload();
      } catch (x) { void vscode.window.showErrorMessage(`Not saved: ${(x as Error).message}`); }
    }
  });
  panel.onDidDispose(() => {
    if (!saved && now !== before) { void vscode.window.showWarningMessage(`Not saved: the edit of "${e.text.slice(0, 40)}" (closed without Save).`); }
  });
}

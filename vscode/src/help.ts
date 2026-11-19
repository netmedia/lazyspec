// LazySpec: Help - the keys (Windows / Linux and Mac side by side, this computer's marked), what Find takes,
// what the views and the editors do; the full guide (README) one click away.

import * as vscode from 'vscode';

/** [what it does, Windows / Linux, Mac] - by section. */
const KEYS: { title: string; note?: string; rows: [string, string, string][] }[] = [
  {
    title: 'Go to a pane', note: 'Ctrl+; (Mac ⌘;), then a letter: the pane gets the keyboard, the arrows work right away. On a Croatian keyboard ; is the key right of L (č).',
    rows: [
      ['The Plan', 'Ctrl+;  P', '⌘;  P'],
      ['The Scope', 'Ctrl+;  S', '⌘;  S'],
      ['The Details', 'Ctrl+;  D', '⌘;  D'],
      ['Undo', 'Ctrl+;  U', '⌘;  U'],
      ['The open document (its text)', 'Ctrl+;  E', '⌘;  E'],
    ],
  },
  {
    title: 'Anywhere',
    rows: [
      ['Find a task, requirement, scenario or section', 'Ctrl+Alt+T', '⌘⌥T'],
      ['All commands (type "LazySpec")', 'Ctrl+Shift+P', '⌘⇧P'],
      ['Show or hide the side bar', 'Ctrl+B', '⌘B'],
      ['To the side bar / to the editor', 'Ctrl+0 / Ctrl+1', '⌘0 / ⌘1'],
      ['Around the window\'s parts', 'F6 / Shift+F6', 'F6 / ⇧F6 (fn+F6)'],
    ],
  },
  {
    title: 'In the Plan and the Scope',
    rows: [
      ['Select', '↑ ↓', '↑ ↓'],
      ['Open, close a node', '→ ←', '→ ←'],
      ['Open (a document; an item: its document, formatted, at it)', 'Enter', 'Enter'],
      ['Select several', 'Ctrl+click, Shift+click, Shift+↑↓', '⌘click, ⇧click, ⇧↑↓'],
      ['Edit the item (the formatted editor)', 'F2', 'F2 (fn+F2 on a laptop)'],
      ['A task done / not done', 'Space', 'Space'],
      ['Delete (asked first)', 'Delete', '⌘⌫'],
      ['The agent: change it, write it again', 'Ctrl+Alt+A', '⌘⌥A'],
      ['Read (formatted, a tab per document)', 'Ctrl+Alt+R', '⌘⌥R'],
      ['Find in the view (VS Code\'s)', 'type, or Ctrl+Alt+F', 'type, or ⌘⌥F'],
    ],
  },
  {
    title: 'In Undo',
    rows: [
      ['The change (its diff)', 'Enter', 'Enter'],
      ['Undo it (asked first)', 'Delete', '⌘⌫'],
    ],
  },
  {
    title: 'In Find',
    note: 'Type with your words: in:design, in:tasks, in:open (open questions) - one document, its name\'s beginning is enough; is:task, is:open (open tasks), is:req, is:scenario, is:section - one kind; g1 or group 1 - one group; 1.3 or 01 1.3 - a task by its number. Each result says on a small line which document it is in and what it is.',
    rows: [
      ['Open it (focused at it)', 'Enter', 'Enter'],
      ['Move', '↑ ↓', '↑ ↓'],
      ['Its buttons: read, edit, done, the agent, delete', 'the mouse', 'the mouse'],
    ],
  },
  {
    title: 'In Read',
    rows: [
      ['Pick an item / several', 'click / Ctrl+click', 'click / ⌘click'],
      ['The next, the previous item', '↓ ↑', '↓ ↑'],
      ['Edit it', 'Enter, or double-click', 'Enter, or double-click'],
      ['A task done / not done', 'Space', 'Space'],
      ['Delete', 'Delete', 'Delete (fn+⌫)'],
      ['The agent', 'A', 'A'],
      ['None picked', 'Esc', 'Esc'],
    ],
  },
  {
    title: 'In the formatted editor',
    note: 'The bar on top: the heading level, bold, italic, strikethrough, code, lists, task lists, link, table, code block, quote, a rule. Markdown shortcuts work as you type: **bold**, # a heading, - [ ] a task. Only the lines you edit change in the file.',
    rows: [
      ['Save', 'Ctrl+S', '⌘S'],
      ['Bold / italic', 'Ctrl+B / Ctrl+I', '⌘B / ⌘I'],
      ['Undo / redo', 'Ctrl+Z / Ctrl+Y', '⌘Z / ⌘⇧Z'],
      ['Back to the Plan', 'Ctrl+;  P', '⌘;  P'],
      ['The Markdown itself', 'the title bar: LazySpec menu, Source', 'the title bar: LazySpec menu, Source'],
    ],
  },
];

function esc(s: string): string { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

let panel: vscode.WebviewPanel | undefined;
export function showHelp(readme: vscode.Uri) {
  if (panel) { panel.reveal(); return; }
  panel = vscode.window.createWebviewPanel('lazyspec.help', 'LazySpec: Help', vscode.ViewColumn.Active, { enableScripts: true });
  panel.onDidDispose(() => { panel = undefined; });
  panel.webview.onDidReceiveMessage(m => { if (m === 'readme') { void vscode.commands.executeCommand('markdown.showPreview', readme); } else if (m === 'keys') { void vscode.commands.executeCommand('workbench.action.openGlobalKeybindings', 'lazyspec'); } });
  const mac = process.platform === 'darwin';
  const sections = KEYS.map(s => `<h2>${esc(s.title)}</h2>${s.note ? `<p class="note">${esc(s.note)}</p>` : ''}
<table><tr><th></th><th class="${mac ? '' : 'me'}">Windows, Linux</th><th class="${mac ? 'me' : ''}">Mac</th></tr>
${s.rows.map(r => `<tr><td>${esc(r[0])}</td><td class="${mac ? '' : 'me'}"><kbd>${esc(r[1])}</kbd></td><td class="${mac ? 'me' : ''}"><kbd>${esc(r[2])}</kbd></td></tr>`).join('\n')}</table>`).join('\n');
  panel.webview.html = `<!DOCTYPE html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
<style>
body { font-family: var(--vscode-font-family); color: var(--vscode-foreground); padding: 8px 28px 40px; max-width: 960px; }
h1 { font-size: 1.5em; margin: 10px 0 2px; } h2 { font-size: 1.1em; margin: 26px 0 6px; }
p { line-height: 1.45; } .note { color: var(--vscode-descriptionForeground); margin: 0 0 8px; }
table { border-collapse: collapse; width: 100%; } td, th { text-align: left; padding: 4px 10px 4px 0; border-bottom: 1px solid var(--vscode-panel-border); vertical-align: top; }
th { font-weight: 600; color: var(--vscode-descriptionForeground); font-size: .9em; } table { table-layout: fixed; } td:first-child, th:first-child { width: 44%; } td:nth-child(2), th:nth-child(2), td:nth-child(3), th:nth-child(3) { width: 28%; }
th.me { color: var(--vscode-textLink-foreground); } td:not(.me):not(:first-child) { opacity: .6; }
kbd { font-family: var(--vscode-editor-font-family); font-size: .92em; background: var(--vscode-textCodeBlock-background); border: 1px solid var(--vscode-panel-border); border-radius: 3px; padding: 1px 6px; white-space: nowrap; }
a { color: var(--vscode-textLink-foreground); cursor: pointer; }
</style></head><body>
<h1>LazySpec: Help</h1>
<p class="note">The keys of LazySpec in VS Code, Cursor and Windsurf - ${mac ? 'this computer is a Mac' : 'this computer: Windows / Linux'} (its column marked). <a onclick="vscode.postMessage('keys')">Change them</a> in VS Code's keyboard shortcuts; <a onclick="vscode.postMessage('readme')">the full guide</a> (README) has everything else.</p>
${sections}
<script>const vscode = acquireVsCodeApi();</script>
</body></html>`;
}

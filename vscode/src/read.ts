// Read: a spec, a change, several changes or groups as one, formatted - a tab per document, as LazySpec's Read.
// Its tasks, requirements, scenarios and sections are items: click one (Ctrl/Cmd: several), then edit, delete,
// tick, or hand them to the agent; Source opens the Markdown itself.

import * as path from 'path';
import * as vscode from 'vscode';
import { Change, Entry, itemTitle, Project, readText, searchIndex, Spec } from './model';

export type ReadTarget =
  | { kind: 'spec'; project: Project; spec: Spec }
  | { kind: 'change'; project: Project; change: Change }
  | { kind: 'bundle'; project: Project; title: string; changes: Change[]; id?: string; groups?: string[] };

interface Part { file: string; heading: string }
interface Tab { title: string; parts: Part[] }

export interface ReadActions {
  edit(e: Entry): unknown;
  remove(es: Entry[]): unknown;
  toggle(e: Entry): unknown;
  agent(es: Entry[]): unknown;
  exportTarget(t: ReadTarget): unknown;
}

function esc(s: string): string { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }

/** The tabs: a spec's file; a change's documents in its workflow's order; several changes: a tab per kind of
 *  document, each change's part under its title (the documents no workflow names last). */
export function readTabs(t: ReadTarget): Tab[] {
  if (t.kind === 'spec') { return [{ title: 'Spec', parts: [{ file: t.spec.path, heading: '' }] }]; }
  const changes = t.kind === 'change' ? [t.change] : t.changes;
  const many = changes.length > 1;
  const order: string[] = [];
  for (const extra of [false, true]) { for (const c of changes) { for (const d of c.docs) { if (d.extra === extra && !order.includes(d.id)) { order.push(d.id); } } } }
  const tabs: Tab[] = [];
  for (const id of order) {
    const parts: Part[] = [];
    let title = '';
    for (const c of changes) {
      const d = c.docs.find(x => x.id === id);
      if (!d) { continue; }
      title = d.isSpecs ? 'Specs' : d.title;
      if (d.isSpecs) { for (const cap of c.caps) { parts.push({ file: cap.path, heading: many ? `${itemTitle(c)} · ${cap.name}` : cap.name }); } }
      else { for (const f of d.files) { parts.push({ file: f, heading: many ? itemTitle(c) + (d.files.length > 1 ? ` · ${path.basename(f)}` : '') : d.files.length > 1 ? path.relative(c.dir, f).replace(/\\/g, '/') : '' }); } }
    }
    if (parts.length) { tabs.push({ title: many || title === 'Specs' ? `${title} (${parts.length})` : title, parts }); }
  }
  return tabs;
}
export function readTitle(t: ReadTarget): string {
  return t.kind === 'spec' ? itemTitle(t.spec) : t.kind === 'change' ? itemTitle(t.change) : t.title;
}

export class ReadPanel {
  private static panels = new Map<string, ReadPanel>();
  /** The last page drawn (the tests run its script in a browser). */
  static lastHtml = '';
  private tab = 0;
  private entries: Entry[] = [];

  static show(target: ReadTarget, actions: ReadActions, at?: { file: string; line: number }) {
    const key = ReadPanel.keyOf(target);
    let p = ReadPanel.panels.get(key);
    if (!p) {
      const panel = vscode.window.createWebviewPanel('lazyspec.read', readTitle(target), vscode.ViewColumn.Active, { enableScripts: true, retainContextWhenHidden: true, localResourceRoots: [vscode.Uri.file(target.project.root)] });
      p = new ReadPanel(panel, target, actions, key);
      ReadPanel.panels.set(key, p);
    } else { p.panel.reveal(); }
    if (at) { const i = readTabs(p.target).findIndex(t => t.parts.some(x => x.file === at.file)); if (i >= 0) { p.tab = i; } }
    void p.render(at);
  }
  /** After the files changed: every Read again, from the reloaded projects. */
  static refreshAll(find: (t: ReadTarget) => ReadTarget | null) {
    for (const p of [...ReadPanel.panels.values()]) {
      const t = find(p.target);
      if (!t) { p.panel.dispose(); continue; }
      p.target = t;
      void p.render();
    }
  }
  static keyOf(t: ReadTarget): string {
    if (t.kind === 'spec') { return `spec:${t.spec.path}`; }
    if (t.kind === 'change') { return `change:${t.change.dir}`; }
    return `bundle:${t.project.root}:${t.changes.map(c => c.name).join(',')}`;
  }

  private constructor(private readonly panel: vscode.WebviewPanel, private target: ReadTarget, private readonly actions: ReadActions, key: string) {
    panel.onDidDispose(() => ReadPanel.panels.delete(key));
    panel.webview.onDidReceiveMessage(m => this.onMessage(m));
  }

  private onMessage(m: { cmd: string; tab?: number; ids?: number[]; file?: string; line?: number; href?: string }) {
    const sel = (m.ids || []).map(i => this.entries[i]).filter(e => e);
    switch (m.cmd) {
      case 'tab': this.tab = m.tab || 0; void this.render(); break;
      case 'edit': if (sel[0]) { void this.actions.edit(sel[0]); } break;
      case 'delete': if (sel.length) { void this.actions.remove(sel); } break;
      case 'toggle': for (const e of sel.filter(x => x.kind === 'task')) { void this.actions.toggle(e); } break;
      case 'agent': if (sel.length) { void this.actions.agent(sel); } break;
      case 'source': {
        const tab = readTabs(this.target)[this.tab];
        const file = m.file || sel[0]?.path || tab?.parts[0]?.file;
        if (file) { void vscode.commands.executeCommand('lazyspec.openFile', file, m.line || sel[0]?.line || 0); }
        break;
      }
      case 'export': void this.actions.exportTarget(this.target); break;
      case 'link': {
        // A link to another document of the project: that one; else the browser.
        const href = m.href || '';
        if (/^[a-z]+:/i.test(href)) { void vscode.env.openExternal(vscode.Uri.parse(href)); break; }
        const file = path.resolve(path.dirname(m.file || ''), decodeURIComponent(href.split('#')[0]));
        if (file) { void vscode.commands.executeCommand('lazyspec.openDocument', file); }
        break;
      }
    }
  }

  private async renderMarkdown(text: string): Promise<string> {
    try {
      const html = await vscode.commands.executeCommand<string>('markdown.api.render', text);
      if (typeof html === 'string') { return html; }
    } catch { /* the built-in Markdown extension is off: as text */ }
    return `<pre>${esc(text)}</pre>`;
  }

  private async render(at?: { file: string; line: number }) {
    const t = this.target;
    const tabs = readTabs(t);
    if (this.tab >= tabs.length) { this.tab = 0; }
    this.panel.title = readTitle(t);
    // The items of the files shown: the same as find's (tasks, requirements, scenarios, sections).
    const files = new Set(tabs[this.tab]?.parts.map(p => p.file) || []);
    this.entries = searchIndex(t.project, true).filter(e => files.has(e.path));
    const itemsByFile: Record<string, Record<number, number>> = {};
    this.entries.forEach((e, i) => { (itemsByFile[e.path] ||= {})[e.line] = i; });
    let body = '';
    for (const part of tabs[this.tab]?.parts || []) {
      let html = await this.renderMarkdown(readText(part.file));
      // Pictures next to the document.
      html = html.replace(/(<img[^>]*\ssrc=")(?![a-z]+:|data:|#)([^"]+)"/gi, (_m, pre, src) => `${pre}${this.panel.webview.asWebviewUri(vscode.Uri.file(path.resolve(path.dirname(part.file), decodeURIComponent(src))))}"`);
      body += `<section class="part" data-file="${esc(part.file)}">${part.heading ? `<div class="part-head">${esc(part.heading)} <a href="#" class="src" data-src="${esc(part.file)}">source</a></div>` : ''}${html}</section>`;
    }
    if (!body) { body = '<p class="muted">Nothing written yet.</p>'; }
    const tabsHtml = tabs.map((x, i) => `<button class="tab${i === this.tab ? ' on' : ''}" data-tab="${i}">${esc(x.title)}</button>`).join('');
    const items = JSON.stringify(itemsByFile);
    const kinds = JSON.stringify(this.entries.map(e => ({ kind: e.kind, done: e.done })));
    const jump = at ? JSON.stringify(at) : 'null';
    this.panel.webview.html = ReadPanel.lastHtml = `<!DOCTYPE html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${this.panel.webview.cspSource} https: data:; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
<style>
body { font-family: var(--vscode-markdown-font-family, var(--vscode-font-family)); font-size: var(--vscode-markdown-font-size, 14px); line-height: var(--vscode-markdown-line-height, 1.6); color: var(--vscode-foreground); padding: 0 24px 60px; max-width: 980px; }
.bar { position: sticky; top: 0; background: var(--vscode-editor-background); padding: 10px 0 6px; z-index: 2; border-bottom: 1px solid var(--vscode-panel-border); }
.tabs { display: flex; flex-wrap: wrap; gap: 4px; }
.tab { background: none; border: none; color: var(--vscode-descriptionForeground); padding: 3px 9px; border-radius: 3px; cursor: pointer; font: inherit; font-size: .92em; }
.tab.on { background: var(--vscode-badge-background); color: var(--vscode-badge-foreground); }
.tools { display: flex; gap: 6px; align-items: center; margin-top: 6px; font-size: .88em; min-height: 26px; }
.tools button { background: var(--vscode-button-secondaryBackground); color: var(--vscode-button-secondaryForeground); border: none; padding: 2px 9px; border-radius: 2px; cursor: pointer; font: inherit; }
.tools button:hover { background: var(--vscode-button-secondaryHoverBackground); }
.tools button[disabled] { opacity: .4; cursor: default; }
.tools .hint { color: var(--vscode-descriptionForeground); margin-left: auto; }
.part-head { margin: 26px 0 0; padding: 4px 8px; background: var(--vscode-textBlockQuote-background); font-weight: 600; font-size: .9em; }
.part-head .src, .muted { color: var(--vscode-descriptionForeground); font-weight: normal; }
a { color: var(--vscode-textLink-foreground); }
code { font-family: var(--vscode-editor-font-family); font-size: .92em; background: var(--vscode-textCodeBlock-background); padding: 1px 4px; border-radius: 3px; }
pre { background: var(--vscode-textCodeBlock-background); padding: 10px; overflow: auto; }
pre code { background: none; padding: 0; }
table { border-collapse: collapse; margin: 10px 0; }
th, td { border: 1px solid var(--vscode-panel-border); padding: 3px 8px; text-align: left; vertical-align: top; }
blockquote { border-left: 3px solid var(--vscode-textBlockQuote-border); margin: 8px 0; padding: 0 12px; color: var(--vscode-descriptionForeground); }
.item { cursor: pointer; border-radius: 3px; outline: 1px solid transparent; }
.item:hover { outline-color: var(--vscode-focusBorder); }
.item.sel { background: var(--vscode-list-activeSelectionBackground); color: var(--vscode-list-activeSelectionForeground); }
li.item { list-style: none; margin-left: -1.3em; }
li.item input { margin-right: 6px; vertical-align: middle; }
li.done-task { color: var(--vscode-descriptionForeground); }
</style></head><body>
<div class="bar"><div class="tabs">${tabsHtml}</div>
<div class="tools">
  <button data-act="edit" disabled title="Enter">Edit</button>
  <button data-act="toggle" disabled title="Space">Done / not</button>
  <button data-act="delete" disabled title="Delete">Delete</button>
  <button data-act="agent" disabled title="A">Agent...</button>
  <span style="width:10px"></span>
  <button data-act="source" title="The Markdown itself">Source</button>
  <button data-act="export">Export...</button>
  <span class="hint" id="hint">Click a task, requirement, scenario or section (Ctrl/Cmd: several)</span>
</div></div>
${body}
<script>
const vscode = acquireVsCodeApi();
const items = ${items};
const kinds = ${kinds};
const jump = ${jump};
let sel = [];
// The items: the rendered blocks whose source line is a task's, requirement's, scenario's or section's.
const els = [];
document.querySelectorAll('section.part').forEach(sec => {
  const map = items[sec.dataset.file] || {};
  // The innermost element first (a list and its first item share a line): each item on one element.
  const taken = new Set();
  [...sec.querySelectorAll('[data-line]')].reverse().forEach(el => {
    const id = map[Number(el.dataset.line) + 1];
    if (id === undefined || el.dataset.item || taken.has(id) || /^(UL|OL|TABLE|BLOCKQUOTE|PRE)$/.test(el.tagName)) { return; }
    taken.add(id);
    // A task: the list item itself (its paragraph inside it has the same line).
    let target = el;
    if (el.tagName === 'P' && el.parentElement && el.parentElement.tagName === 'LI' && el.parentElement.dataset.line === el.dataset.line) { target = el.parentElement; }
    if (target.dataset.item) { return; }
    target.dataset.item = id; target.classList.add('item');
    if (kinds[id].kind === 'task') {
      const walker = document.createTreeWalker(target, NodeFilter.SHOW_TEXT);
      const t = walker.nextNode();
      if (t) { t.textContent = t.textContent.replace(/^\\s*\\[[ xX]\\]\\s*/, ''); }
      const box = document.createElement('input'); box.type = 'checkbox'; box.checked = kinds[id].done;
      box.addEventListener('click', e => { e.stopPropagation(); vscode.postMessage({ cmd: 'toggle', ids: [id] }); });
      target.insertBefore(box, target.firstChild);
      if (kinds[id].done) { target.classList.add('done-task'); }
    }
    els[id] = target;
  });
});
function show() {
  document.querySelectorAll('.item.sel').forEach(e => e.classList.remove('sel'));
  sel.forEach(i => els[i] && els[i].classList.add('sel'));
  const any = sel.length > 0;
  document.querySelector('[data-act=edit]').disabled = sel.length !== 1;
  document.querySelector('[data-act=delete]').disabled = !any;
  document.querySelector('[data-act=agent]').disabled = !any;
  document.querySelector('[data-act=toggle]').disabled = !sel.some(i => kinds[i].kind === 'task');
  document.getElementById('hint').textContent = any ? sel.length + ' selected (Esc: none)' : 'Click a task, requirement, scenario or section (Ctrl/Cmd: several)';
}
function order() { return els.map((e, i) => e ? i : -1).filter(i => i >= 0).sort((a, b) => els[a].compareDocumentPosition(els[b]) & 4 ? -1 : 1); }
document.addEventListener('click', e => {
  const tab = e.target.closest('[data-tab]');
  if (tab) { vscode.postMessage({ cmd: 'tab', tab: Number(tab.dataset.tab) }); return; }
  const act = e.target.closest('[data-act]');
  if (act) { vscode.postMessage({ cmd: act.dataset.act, ids: sel }); return; }
  const src = e.target.closest('[data-src]');
  if (src) { e.preventDefault(); vscode.postMessage({ cmd: 'source', file: src.dataset.src }); return; }
  const a = e.target.closest('a[href]');
  if (a) { e.preventDefault(); const sec = a.closest('section.part'); vscode.postMessage({ cmd: 'link', href: a.getAttribute('href'), file: sec ? sec.dataset.file : '' }); return; }
  const it = e.target.closest('.item');
  if (!it) { return; }
  const id = Number(it.dataset.item);
  if (e.ctrlKey || e.metaKey) { sel = sel.includes(id) ? sel.filter(x => x !== id) : sel.concat(id); }
  else { sel = [id]; }
  show();
});
document.addEventListener('dblclick', e => { const it = e.target.closest('.item'); if (it) { vscode.postMessage({ cmd: 'edit', ids: [Number(it.dataset.item)] }); } });
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') { sel = []; show(); return; }
  if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
    const o = order(); if (!o.length) { return; }
    const cur = sel.length ? o.indexOf(sel[sel.length - 1]) : -1;
    const next = o[Math.max(0, Math.min(o.length - 1, cur + (e.key === 'ArrowDown' ? 1 : -1)))];
    sel = [next]; show(); els[next].scrollIntoView({ block: 'nearest' }); e.preventDefault(); return;
  }
  if (!sel.length) { return; }
  if (e.key === 'Enter') { vscode.postMessage({ cmd: 'edit', ids: sel }); }
  else if (e.key === 'Delete') { vscode.postMessage({ cmd: 'delete', ids: sel }); }
  else if (e.key === ' ') { e.preventDefault(); vscode.postMessage({ cmd: 'toggle', ids: sel }); }
  else if (e.key === 'a') { vscode.postMessage({ cmd: 'agent', ids: sel }); }
});
if (jump) {
  const sec = [...document.querySelectorAll('section.part')].find(s => s.dataset.file === jump.file);
  const id = sec && (items[jump.file] || {})[jump.line];
  if (id !== undefined && els[id]) { sel = [id]; els[id].scrollIntoView({ block: 'center' }); }
}
show();
</script></body></html>`;
  }
}

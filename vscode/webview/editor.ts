// The formatted editor (a webview): Markdown edited as formatted text - a top bar with headings, bold, italic,
// strikethrough, code, links, lists, task lists, quotes, tables; Markdown shortcuts (**, #, - [ ]); the
// selection's toolbar. Milkdown (Crepe, only the features used), its Markdown out on every change; LazySpec's own
// bar above it (Save, Cancel, Source ...). Bundled by esbuild into out/webview/editor.js (+ .css).

import { CrepeBuilder } from '@milkdown/crepe/builder';
import { remarkStringifyOptionsCtx } from '@milkdown/kit/core';
import { cursor } from '@milkdown/crepe/feature/cursor';
import { linkTooltip } from '@milkdown/crepe/feature/link-tooltip';
import { listItem } from '@milkdown/crepe/feature/list-item';
import { placeholder } from '@milkdown/crepe/feature/placeholder';
import { table } from '@milkdown/crepe/feature/table';
import { toolbar } from '@milkdown/crepe/feature/toolbar';
import { topBar } from '@milkdown/crepe/feature/top-bar';
import '@milkdown/crepe/theme/common/prosemirror.css';
import '@milkdown/crepe/theme/common/reset.css';
import '@milkdown/crepe/theme/common/cursor.css';
import '@milkdown/crepe/theme/common/link-tooltip.css';
import '@milkdown/crepe/theme/common/list-item.css';
import '@milkdown/crepe/theme/common/placeholder.css';
import '@milkdown/crepe/theme/common/toolbar.css';
import '@milkdown/crepe/theme/common/table.css';
import '@milkdown/crepe/theme/common/top-bar.css';
import './editor.css';

declare function acquireVsCodeApi(): { postMessage(m: unknown): void };
const vscode = typeof acquireVsCodeApi === 'function' ? acquireVsCodeApi() : { postMessage: (m: unknown) => { (window as unknown as { lastMessage: unknown }).lastMessage = m; } };

interface Button { id: string; label: string; title?: string; primary?: boolean }
let crepe: CrepeBuilder | null = null;
let quiet = false;
let buttons: Button[] = [];

/** LazySpec's bar: what this editor is (note), its buttons. */
function bar(note: string) {
  const el = document.getElementById('lazyspec-bar');
  if (!el) { return; }
  el.innerHTML = '';
  if (note) { const n = document.createElement('span'); n.className = 'note'; n.textContent = note; el.appendChild(n); }
  for (const b of buttons) {
    const btn = document.createElement('button');
    btn.textContent = b.label;
    if (b.title) { btn.title = b.title; }
    if (b.primary) { btn.className = 'primary'; }
    btn.addEventListener('click', () => vscode.postMessage({ type: 'button', id: b.id }));
    el.appendChild(btn);
  }
  el.style.display = note || buttons.length ? '' : 'none';
}

/** The editor, with this Markdown; its Markdown out on every change (not while loading). */
async function load(markdown: string): Promise<string> {
  if (crepe) { await crepe.destroy(); }
  const root = document.getElementById('editor')!;
  root.innerHTML = '';
  quiet = true;
  crepe = new CrepeBuilder({ root, defaultValue: markdown })
    .addFeature(topBar).addFeature(toolbar).addFeature(listItem).addFeature(table).addFeature(linkTooltip)
    .addFeature(cursor).addFeature(placeholder, { text: 'Type, or use the bar above' });
  // OpenSpec's Markdown: - bullets, ** bold, * italic, ``` code.
  crepe.editor.config(ctx => ctx.update(remarkStringifyOptionsCtx, o => ({ ...o, bullet: '-', bulletOther: '*', emphasis: '*', strong: '*', fence: '`', rule: '-' })));
  crepe.on(l => l.markdownUpdated((_ctx, md) => { if (!quiet) { vscode.postMessage({ type: 'change', markdown: md }); } }));
  await crepe.create();
  quiet = false;
  const md = crepe.getMarkdown();
  vscode.postMessage({ type: 'ready', markdown: md });
  return md;
}

/** Scrolled to the block with this text (headings, list items, paragraphs, cells; the nth such), marked. */
function reveal(text: string, nth: number) {
  const norm = (t: string) => t.replace(/[*_`]/g, '').replace(/\s+/g, ' ').trim().toLowerCase();
  const want = norm(text);
  if (!want) { return; }
  const root = document.getElementById('editor')!;
  const blocks = [...root.querySelectorAll('.ProseMirror h1, .ProseMirror h2, .ProseMirror h3, .ProseMirror h4, .ProseMirror h5, .ProseMirror h6, .ProseMirror li, .ProseMirror p, .ProseMirror td')] as HTMLElement[];
  // The innermost blocks that contain it (a list item, not the list around it).
  const hits = blocks.filter(b => norm(b.textContent || '').includes(want) && !blocks.some(c => c !== b && b.contains(c) && norm(c.textContent || '').includes(want)));
  const el = hits[Math.min(nth, hits.length - 1)];
  if (!el) { return; }
  el.scrollIntoView({ block: 'center' });
  // A mark over it, not on it (the editor puts its own elements back as they were).
  document.querySelectorAll('.lazyspec-hit').forEach(x => x.remove());
  const r = el.getBoundingClientRect();
  const mark = document.createElement('div');
  mark.className = 'lazyspec-hit';
  Object.assign(mark.style, { position: 'absolute', left: `${r.left + window.scrollX - 4}px`, top: `${r.top + window.scrollY - 2}px`, width: `${r.width + 8}px`, height: `${r.height + 4}px`, pointerEvents: 'none', zIndex: '10' });
  mark.dataset.text = (el.textContent || '').trim().slice(0, 80);
  document.body.appendChild(mark);
  setTimeout(() => mark.remove(), 2500);
}

window.addEventListener('message', e => {
  const m = e.data as { type: string; markdown?: string; buttons?: Button[]; note?: string; text?: string; nth?: number };
  if (m.type === 'reveal') { setTimeout(() => reveal(m.text || '', m.nth || 0), 50); }
  if (m.type === 'load') { buttons = m.buttons || []; bar(m.note || ''); void load(m.markdown || ''); }
  if (m.type === 'get') { vscode.postMessage({ type: 'markdown', markdown: crepe ? crepe.getMarkdown() : '' }); }
});
// Ctrl+S / Cmd+S: Save, when the editor has one.
window.addEventListener('keydown', e => {
  if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's' && buttons.some(b => b.id === 'save')) { e.preventDefault(); vscode.postMessage({ type: 'button', id: 'save' }); }
}, true);
// For tests in a browser: window.lazyspecLoad(md) -> its Markdown as the editor writes it.
(window as unknown as { lazyspecLoad: (md: string) => Promise<string> }).lazyspecLoad = load;
vscode.postMessage({ type: 'init' });

// Details: the selected change, spec or group, as LazySpec's details pane - progress, tasks by group,
// capabilities, why, documents; a group's description, what it requires, its changes and dependencies.

import * as path from 'path';
import * as vscode from 'vscode';
import { Change, itemTitle, Project, readText, section, Spec } from './model';
import { StaleDoc } from './ops';

export type Selected =
  | { kind: 'change'; project: Project; change: Change }
  | { kind: 'spec'; project: Project; spec: Spec }
  | { kind: 'group'; project: Project; id: string }
  | null;

function esc(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
function bar(done: number, total: number): string {
  const pct = total ? Math.round((100 * done) / total) : 0;
  return `<div class="progress"><div class="bar"><div style="width:${pct}%"></div></div><span>${pct}% &nbsp; ${done} of ${total} tasks</span></div>`;
}
function link(file: string, label: string, line = 0): string {
  return `<a href="#" data-open="${esc(file)}" data-line="${line}">${esc(label)}</a>`;
}
function button(command: string, label: string, args: unknown[] = []): string {
  return `<button data-run="${esc(command)}" data-args="${esc(JSON.stringify(args))}">${esc(label)}</button>`;
}
/** A markdown section's first lines as plain text. */
function summary(text: string, max = 600): string {
  const plain = text.replace(/<!--[\s\S]*?-->/g, '').replace(/\*\*/g, '').replace(/`/g, '').replace(/\[([^\]]+)\]\([^)]+\)/g, '$1').trim();
  return plain.length > max ? plain.slice(0, max).replace(/\s+\S*$/, '') + ' ...' : plain;
}

export class DetailsView implements vscode.WebviewViewProvider {
  private view?: vscode.WebviewView;
  private selected: Selected = null;
  constructor(private readonly staleOf: (p: Project, c: Change) => StaleDoc[] | undefined) { }

  resolveWebviewView(view: vscode.WebviewView): void {
    this.view = view;
    view.webview.options = { enableScripts: true, enableCommandUris: false };
    view.webview.onDidReceiveMessage(m => {
      if (m.open) { void vscode.commands.executeCommand('lazyspec.openFile', m.open, m.line || 0); }
      if (m.run) { void vscode.commands.executeCommand(m.run, ...(m.args || [])); }
    });
    this.render();
  }
  show(sel: Selected): void { this.selected = sel; this.render(); }
  current(): Selected { return this.selected; }
  /** After a reload: the same item, from the new project. */
  refresh(find: (s: NonNullable<Selected>) => Selected): void { if (this.selected) { this.selected = find(this.selected); } this.render(); }

  private render(): void {
    if (!this.view) { return; }
    const s = this.selected;
    let body = '<p class="muted">Select a change, a group or a spec in the Plan or the Scope.</p>';
    if (s?.kind === 'change') { body = this.change(s.project, s.change); }
    else if (s?.kind === 'spec') { body = this.spec(s.spec); }
    else if (s?.kind === 'group') { body = this.group(s.project, s.id); }
    this.view.webview.html = `<!DOCTYPE html><html><head><meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline';">
<style>
body { font-family: var(--vscode-font-family); font-size: var(--vscode-font-size); color: var(--vscode-foreground); padding: 4px 10px 16px; }
h2 { font-size: 1.15em; margin: 6px 0 2px; }
h3 { font-size: .8em; letter-spacing: .06em; color: var(--vscode-descriptionForeground); margin: 16px 0 4px; font-weight: 600; }
.chip { display: inline-block; font-size: .75em; font-weight: 600; padding: 1px 6px; border-radius: 3px; background: var(--vscode-badge-background); color: var(--vscode-badge-foreground); }
.chip.ok { background: var(--vscode-charts-green); color: var(--vscode-editor-background); }
.chip.on { background: var(--vscode-charts-blue); color: var(--vscode-editor-background); }
.muted, .path { color: var(--vscode-descriptionForeground); }
.path { font-family: var(--vscode-editor-font-family); font-size: .85em; word-break: break-all; }
.progress { display: flex; align-items: center; gap: 8px; margin: 8px 0; font-size: .9em; }
.bar { flex: 1; max-width: 220px; height: 6px; background: var(--vscode-progressBar-background, #555); opacity: .35; border-radius: 3px; position: relative; }
.bar > div { position: absolute; inset: 0 auto 0 0; background: var(--vscode-charts-blue); border-radius: 3px; opacity: 1; }
table { border-collapse: collapse; width: 100%; font-size: .92em; }
td { padding: 1px 4px 1px 0; vertical-align: top; }
td.n { text-align: right; white-space: nowrap; color: var(--vscode-descriptionForeground); }
.add { color: var(--vscode-charts-green); } .mod { color: var(--vscode-charts-yellow); } .del { color: var(--vscode-charts-red); }
a { color: var(--vscode-textLink-foreground); text-decoration: none; } a:hover { text-decoration: underline; }
.docs a, .docs span { margin-right: 10px; white-space: nowrap; }
.missing { color: var(--vscode-disabledForeground); }
.actions { margin-top: 16px; display: flex; flex-wrap: wrap; gap: 6px; }
button { background: var(--vscode-button-secondaryBackground); color: var(--vscode-button-secondaryForeground); border: none; padding: 3px 10px; border-radius: 2px; cursor: pointer; }
button:hover { background: var(--vscode-button-secondaryHoverBackground); }
p { margin: 4px 0; line-height: 1.4; }
.warn { color: var(--vscode-charts-yellow); }
</style></head><body><div style="text-align:right"><a href="#" data-run="lazyspec.refresh" data-args="[]" title="Read everything again from openspec/">&#8635; Refresh</a></div>${body}
<script>
const vscode = acquireVsCodeApi();
document.addEventListener('click', e => {
  const a = e.target.closest('[data-open]');
  if (a) { e.preventDefault(); vscode.postMessage({ open: a.dataset.open, line: Number(a.dataset.line) }); return; }
  const b = e.target.closest('[data-run]');
  if (b) { vscode.postMessage({ run: b.dataset.run, args: JSON.parse(b.dataset.args) }); }
});
</script></body></html>`;
  }

  private change(p: Project, c: Change): string {
    const chip = { 'Draft': '', 'In Progress': 'on', 'Completed': 'ok', 'Archived': '' }[c.stage];
    const rel = `openspec/changes/${c.archived ? 'archive/' : ''}${c.name}/`;
    let h = `<span class="chip ${chip}">${c.stage.toUpperCase()}</span><h2>${esc(itemTitle(c))}</h2><div class="path">${esc(rel)}</div>`;
    if (c.group && p.grouping) { h += `<p class="muted">${esc(p.groupTitle(c.group))}</p>`; }
    h += bar(c.done, c.total);
    // Out of date: which documents, and what changed in what they're written from.
    const stale = c.archived ? undefined : this.staleOf(p, c);
    if (stale?.length) {
      h += '<h3 class="warn">OUT OF DATE</h3>';
      for (const st of stale) {
        h += `<p><b>! ${esc(st.doc.title)}</b> <span class="muted">is older than:</span></p><table>`;
        for (const d of st.diffs.slice(0, 8)) {
          const cls = { '+': 'add', '~': 'mod', '-': 'del' }[d.mark];
          h += `<tr><td class="${cls}">${d.mark}</td><td>${esc(d.file.replace(/^openspec\/changes\/[^/]+\//, ''))}${d.req ? ` &middot; ${esc(d.req)}` : ''}</td></tr>`;
        }
        if (st.diffs.length > 8) { h += `<tr><td></td><td class="muted">... ${st.diffs.length - 8} more</td></tr>`; }
        h += '</table>';
      }
      h += '<div class="actions">' + button('lazyspec.sync', 'Update them (the agent)...', [{ type: 'change', root: p.root, name: c.name }]) + button('lazyspec.markInSync', 'Mark as in sync', [{ type: 'change', root: p.root, name: c.name }]) + '</div>';
    }
    if (c.taskGroups.length) {
      h += '<h3>TASKS</h3><table>';
      for (const g of c.taskGroups) {
        const d = g.tasks.filter(t => t.done).length;
        h += `<tr><td>${link(g.path, g.title || 'Tasks', g.line)}</td><td class="n">${d}/${g.tasks.length}</td></tr>`;
      }
      h += '</table>';
    }
    if (c.caps.length) {
      h += '<h3>CAPABILITIES</h3><table>';
      for (const cap of c.caps) {
        const n = [cap.added ? `<span class="add">+${cap.added}</span>` : '', cap.modified ? `<span class="mod">~${cap.modified}</span>` : '', cap.removed ? `<span class="del">-${cap.removed}</span>` : '', cap.renamed ? `${cap.renamed} renamed` : ''].filter(x => x).join(' ');
        const exists = p.specs.some(s => s.name === cap.name);
        h += `<tr><td>${link(cap.path, cap.name)}</td><td class="n">${n} <span class="muted">${exists ? 'existing' : 'new'}</span></td></tr>`;
      }
      h += '</table>';
    }
    const proposal = readText(path.join(c.dir, 'proposal.md'));
    const why = section(proposal, 'Why');
    if (why) { h += `<h3>WHY</h3><p>${esc(summary(why))}</p>`; }
    h += '<h3>DOCUMENTS</h3><p class="docs">';
    for (const d of c.docs) {
      if (d.isSpecs) { h += c.caps.length ? `<span>&#10003; ${c.caps.length} delta spec${c.caps.length === 1 ? '' : 's'}</span>` : '<span class="missing">&#9675; delta specs</span>'; }
      else if (d.files.length) { h += `&#10003; ${link(d.files[0], d.id)}`; }
      else { h += `<span class="missing">&#9675; ${esc(d.id)}</span>`; }
    }
    h += '</p>';
    if (c.workflow.missing) { h += `<p class="warn">workflow '${esc(c.workflow.missing)}' not found: shown as spec-driven</p>`; }
    else if (c.workflow.name !== 'spec-driven') { h += `<p class="muted">workflow ${esc(c.workflow.name)}</p>`; }
    h += '<div class="actions">' + button('lazyspec.read', 'Read', [{ type: 'change', root: p.root, name: c.name }]) + button('lazyspec.openFile', 'Source', [c.path]) + button('lazyspec.exportItem', 'Export...', [{ type: 'change', root: p.root, name: c.name }]);
    if (!c.archived) { h += button('lazyspec.archive', 'Archive...', [{ type: 'change', root: p.root, name: c.name }]); }
    return h + '</div>';
  }

  private spec(s: Spec): string {
    let h = `<span class="chip ${s.platform ? 'on' : 'ok'}">${s.platform ? 'PLATFORM' : 'CAPABILITY'}</span><h2>${esc(itemTitle(s))}</h2><div class="path">openspec/specs/${esc(s.name)}/spec.md</div>`;
    h += `<p class="muted">${s.reqs} requirements, ${s.scenarioCount} scenarios</p>`;
    if (s.purpose) { h += `<h3>PURPOSE</h3><p>${esc(summary(s.purpose))}</p>`; }
    if (s.requirements.length) {
      h += '<h3>REQUIREMENTS</h3><table>';
      for (const r of s.requirements) { h += `<tr><td>${link(s.path, r.name, r.line)}</td><td class="n">${r.scenarios.length}</td></tr>`; }
      h += '</table>';
    }
    return h + '<div class="actions">' + button('lazyspec.read', 'Read', [{ type: 'spec', root: '', name: s.name, path: s.path }]) + button('lazyspec.openFile', 'Source', [s.path]) + button('lazyspec.exportItem', 'Export...', [{ type: 'spec', root: '', name: s.name, path: s.path }]) + '</div>';
  }

  private group(p: Project, id: string): string {
    const g = p.groups().find(x => x.id === id);
    const changes = g ? g.changes : [];
    const d = p.groupDef(id);
    let h = `<span class="chip">${esc(p.config.groupLabel.toUpperCase())}</span><h2>${esc(p.groupTitle(id))}</h2>`;
    h += `<p class="muted">${changes.length} change${changes.length === 1 ? '' : 's'}${!id ? ', without x-group in .openspec.yaml' : !d ? ' - not in openspec/config.yaml groups:' : ''}</p>`;
    if (d?.description) { h += `<p>${esc(d.description)}</p>`; }
    h += bar(g ? g.done : 0, g ? g.total : 0);
    if (d?.requires.length) { h += '<h3>REQUIRES</h3>' + d.requires.map(r => `<p>&#8594; ${esc(p.groupTitle(r))}</p>`).join(''); }
    const by = p.config.groups.filter(x => id && x.requires.includes(id));
    if (by.length) { h += '<h3>REQUIRED BY</h3>' + by.map(x => `<p>&middot; ${esc(p.groupTitle(x.id))}</p>`).join(''); }
    h += '<h3>CHANGES</h3><table>';
    for (const c of changes) { h += `<tr><td>${link(c.path, itemTitle(c))}</td><td class="n">${c.done}/${c.total}</td></tr>`; }
    h += '</table>';
    const caps = new Map<string, number>();
    for (const c of changes) { for (const cap of c.caps) { caps.set(cap.name, (caps.get(cap.name) || 0) + 1); } }
    if (caps.size) { h += '<h3>CAPABILITIES</h3>' + [...caps.keys()].sort().map(k => `<p>&#9679; ${esc(k)}${caps.get(k)! > 1 ? ` <span class="muted">${caps.get(k)} changes</span>` : ''}</p>`).join(''); }
    const deps = p.groupDependencies(id);
    if (deps.length) {
      h += `<h3>ON OTHER ${esc(p.config.groupPlural.toUpperCase())}</h3><table>`;
      let last = '';
      for (const x of deps) {
        h += `<tr><td>${x.change.name === last ? '' : esc(itemTitle(x.change))}</td><td>&#8594; ${esc(itemTitle(x.on))} <span class="muted">(${esc(p.groupTitle(x.on.group))})</span></td></tr>`;
        last = x.change.name;
      }
      h += '</table>';
    }
    h += '<div class="actions">' + button('lazyspec.read', 'Read', [{ type: 'group', root: p.root, name: id }]);
    if (id) { h += button('lazyspec.exportItem', `Export this ${p.config.groupLabel.toLowerCase()}...`, [{ type: 'group', root: p.root, name: id }]); }
    if (p.config.groups.length) { h += button('lazyspec.exportGroups', `Export ${p.config.groupPlural.toLowerCase()}...`, [{ root: p.root, preselect: id ? [id] : [] }]); }
    h += button('lazyspec.openConfig', 'config.yaml', [{ root: p.root }]);
    return h + '</div>';
  }
}

// Runs inside VS Code (run-vscode.ts): the extension activates on the project, its trees, its commands.

import * as assert from 'assert';
import * as cp from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import * as vscode from 'vscode';
import type { Api } from '../src/extension';
import type { Node } from '../src/tree';

export async function run(): Promise<void> {
  const failures: string[] = [];
  let passed = 0;
  const check = async (name: string, fn: () => unknown) => {
    try { await fn(); passed++; console.log(`  PASS  ${name}`); }
    catch (e) { failures.push(name); console.log(`  FAIL  ${name}\n        ${(e as Error).message}`); }
  };
  const work = process.env.LAZYSPEC_TEST_WORKSPACE!;
  const ext = vscode.extensions.getExtension<Api>('netmedia.lazyspec')!;
  const api = await ext.activate();

  if (process.env.LAZYSPEC_TEST_DEEP) {
    await check('a project below the opened folder (apps/portal): found, node_modules skipped, the sidebar shown', async () => {
      assert.deepStrictEqual(api.projects().map(p => path.relative(work, p.root)), [path.join('apps', 'portal')]);
      await new Promise(r => setTimeout(r, 500));
      assert.ok(api.details.current(), 'the first item selected');
    });
    console.log(`
  ${passed} passed, ${failures.length} failed
`);
    if (failures.length) { throw new Error(failures.join('; ')); }
    return;
  }
  await check('activates on a workspace with openspec/', () => {
    assert.strictEqual(api.projects().length, 1);
    assert.strictEqual(api.projects()[0].name, 'Acme Portal');
  });
  await check('opened in a folder with openspec/: the sidebar shown, the first item details', async () => {
    await new Promise(r => setTimeout(r, 500));
    const sel = api.details.current();
    assert.ok(sel && sel.kind === 'group' && sel.id === '1', JSON.stringify(sel && sel.kind));
  });
  await check('its commands are there', async () => {
    const all = await vscode.commands.getCommands(true);
    for (const c of ['lazyspec.read', 'lazyspec.readAsOne', 'lazyspec.readGroups', 'lazyspec.editItem', 'lazyspec.deleteItems', 'lazyspec.agentItems', 'lazyspec.sync', 'lazyspec.undoItem', 'lazyspec.find', 'lazyspec.export', 'lazyspec.exportGroups', 'lazyspec.newChange', 'lazyspec.validate', 'lazyspec.archive', 'lazyspec.openTui', 'lazyspec.openFile']) {
      assert.ok(all.includes(c), c);
    }
  });
  await check('the plan by group: phases by id, ungrouped last, the label from config.yaml', () => {
    const roots = api.plan.getChildren();
    assert.deepStrictEqual(roots.map(n => (api.plan.getTreeItem(n).label as string)), ['Phase 1 – Accounts', 'Phase 2 – Orders', 'Ungrouped']);
    const g1 = api.plan.getChildren(roots[0]);
    assert.strictEqual(api.plan.getTreeItem(g1[0]).label, '01 Add user sign-up');
    assert.strictEqual(api.plan.getTreeItem(g1[0]).description, '5/8');
  });
  await check('a change: its documents; tasks with checkboxes; delta specs down to scenarios', () => {
    const change = api.plan.getChildren(api.plan.getChildren()[0])[0];
    const docs = api.plan.getChildren(change);
    assert.deepStrictEqual(docs.map(d => api.plan.getTreeItem(d).label), ['Proposal', 'Specs', 'Design', 'Tasks', 'Models']);
    const tasks = docs.find(d => api.plan.getTreeItem(d).label === 'Tasks')!;
    const group = api.plan.getChildren(tasks)[0];
    const items = api.plan.getChildren(group).map(t => api.plan.getTreeItem(t));
    assert.strictEqual(items[3].label, '1.4 Nightly removal of unverified accounts');
    assert.strictEqual(items[3].checkboxState, vscode.TreeItemCheckboxState.Unchecked);
    assert.strictEqual(items[0].checkboxState, vscode.TreeItemCheckboxState.Checked);
    const caps = api.plan.getChildren(docs[1]);
    const reqs = api.plan.getChildren(caps[1]);
    assert.strictEqual(api.plan.getTreeItem(reqs[0]).label, 'Self sign-up');
    assert.ok(api.plan.getChildren(reqs[0]).length >= 1);
  });
  await check('the scope: specs, their requirements and scenarios', () => {
    const specs = api.scope.getChildren();
    assert.ok(specs.length >= 5);
    const ua = specs.find(s => api.scope.getTreeItem(s).label === 'User accounts')!;
    const kids = api.scope.getChildren(ua);
    assert.deepStrictEqual(kids.slice(0, 3).map(k => api.scope.getTreeItem(k).label), ['Purpose', 'Sign in', 'Password reset']);
    assert.deepStrictEqual(kids.slice(0, 2).map(k => api.scope.getTreeItem(k).contextValue), ['item.sec', 'item.req']);
  });
  await check('flat on lazyspec.grouped false', async () => {
    await vscode.workspace.getConfiguration('lazyspec').update('grouped', false, vscode.ConfigurationTarget.Workspace);
    await new Promise(r => setTimeout(r, 300));
    assert.deepStrictEqual(api.plan.getChildren().map(n => (n as Node).kind), ['change', 'change', 'change']);
    await vscode.workspace.getConfiguration('lazyspec').update('grouped', true, vscode.ConfigurationTarget.Workspace);
  });
  await check('a task ticked: its box in tasks.md, the tree after it', async () => {
    const file = path.join(work, 'openspec', 'changes', '01-add-user-signup', 'tasks.md');
    const p = api.projects()[0];
    const task = p.changes.find(c => c.name === '01-add-user-signup')!.taskGroups[0].tasks[3];
    await vscode.commands.executeCommand('lazyspec.openFile', file, task.line);
    const ed = vscode.window.activeTextEditor!;
    assert.strictEqual(ed.selection.active.line, task.line - 1, 'opened at its line');
    // As the checkbox does: the line's box, saved.
    const edit = new vscode.WorkspaceEdit();
    const line = ed.document.lineAt(task.line - 1);
    edit.replace(ed.document.uri, line.range, line.text.replace('[ ]', '[x]'));
    await vscode.workspace.applyEdit(edit);
    await ed.document.save();
    assert.ok(fs.readFileSync(file, 'utf8').includes('- [x] 1.4 Nightly removal'));
    api.reload();
    assert.strictEqual(api.plan.getTreeItem(api.plan.getChildren(api.plan.getChildren()[0])[0]).description, '6/8');
  });
  await check('details: a change, a group, a spec render', () => {
    const p = api.projects()[0];
    api.details.show({ kind: 'change', project: p, change: p.changes[0] });
    api.details.show({ kind: 'group', project: p, id: '2' });
    api.details.show({ kind: 'spec', project: p, spec: p.specs[0] });
  });
  await check('a document\'s sections are items; a task, a requirement, a scenario too (edit, delete, the agent)', () => {
    const change = api.plan.getChildren(api.plan.getChildren()[0])[0];
    const proposal = api.plan.getChildren(change)[0];
    const secs = api.plan.getChildren(proposal).map(n => api.plan.getTreeItem(n));
    assert.ok(secs.some(s => s.label === 'Why') && secs.every(s => s.contextValue === 'item.sec'), secs.map(s => s.label).join(', '));
  });
  await check('formatted: the built-in Markdown renders with source lines (Read finds its items by them)', async () => {
    const html = await vscode.commands.executeCommand<string>('markdown.api.render', '# T\n\n- [ ] 1.1 A task\n\n### Requirement: R\n');
    assert.ok(typeof html === 'string' && /data-line="2"/.test(html) && /data-line="4"/.test(html), String(html).slice(0, 300));
  });
  await check('Read opens: a change, its documents as tabs', async () => {
    await vscode.commands.executeCommand('lazyspec.read', { type: 'change', root: api.projects()[0].root, name: '01-add-user-signup' });
    await new Promise(r => setTimeout(r, 800));
    const tabs = vscode.window.tabGroups.all.flatMap(g => g.tabs).map(t => t.label);
    assert.ok(tabs.includes('01 Add user sign-up'), tabs.join(', '));
  });
  await check('Read\'s page: tasks with their checkboxes, each item one element (its script in a browser)', async () => {
    const browser = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Google/Chrome/Application/chrome.exe', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'].find(b => fs.existsSync(b));
    if (!browser) { console.log('        (no Edge or Chrome: skipped)'); return; }
    await vscode.commands.executeCommand('lazyspec.read', { type: 'change', root: api.projects()[0].root, name: '01-add-user-signup' });
    await new Promise(r => setTimeout(r, 500));
    // The Tasks tab: the panel's last page is the first tab; draw the tasks' one.
    const { ReadPanel } = require('../src/read');
    const page = path.join(os.tmpdir(), `lazyspec-read-${Date.now()}.html`);
    const profile = path.join(os.tmpdir(), `lazyspec-read-profile-${Date.now()}`);
    const html = String(ReadPanel.lastHtml).replace('<head>', '<head><script>window.acquireVsCodeApi = () => ({ postMessage() {} });</script>');
    fs.writeFileSync(page, html);
    try {
      const dom = cp.execFileSync(browser, ['--headless=new', '--disable-gpu', `--user-data-dir=${profile}`, '--dump-dom', 'file:///' + page.replace(/\\/g, '/')], { encoding: 'utf8', timeout: 60000 });
      const items = (dom.match(/class="[^"]*\bitem\b[^"]*"/g) || []).length;
      assert.ok(items >= 3, `items: ${items}`);
      assert.ok(!/<ul[^>]*data-item=/.test(dom), 'a list is not an item, its entries are');
      assert.ok(/<h2[^>]*data-item="\d+"[^>]*>Why/.test(dom) || /<h2[^>]*class="[^"]*item[^"]*"[^>]*>Why/.test(dom), 'the section ## Why is an item');
    } finally { fs.rmSync(page, { force: true }); fs.rmSync(profile, { recursive: true, force: true }); }
    // The tasks' document: checkboxes, without the [ ] text.
    const tasksHtml = await vscode.commands.executeCommand<string>('markdown.api.render', fs.readFileSync(path.join(work, 'openspec', 'changes', '01-add-user-signup', 'tasks.md'), 'utf8'));
    assert.ok(/<li data-line="\d+"[^>]*>\[x\] 1\.1/.test(tasksHtml), 'tasks rendered as text with their box: the page turns them into checkboxes');
  });
  await check('out of date: a delta spec changed after the tasks - ! in the plan, the details say what', async () => {
    const spec = path.join(work, 'openspec', 'changes', '01-add-user-signup', 'specs', 'user-accounts', 'spec.md');
    fs.writeFileSync(spec, fs.readFileSync(spec, 'utf8') + '\n### Requirement: Nickname\nThe system SHALL keep a nickname.\n\n#### Scenario: Set\n- **WHEN** the customer sets it\n- **THEN** it is kept\n');
    api.reload();
    const item = api.plan.getTreeItem(api.plan.getChildren(api.plan.getChildren()[0])[0]);
    assert.ok(String(item.description).startsWith('! '), String(item.description));
    assert.strictEqual(item.contextValue, 'staleChange');
  });
  await check('undo: the files changed since the commit, by piece', async () => {
    api.reload();
    const files = api.undo.getChildren();
    const labels = files.map(f => String(api.undo.getTreeItem(f).label));
    assert.ok(labels.some(l => l.endsWith('tasks.md')) && labels.some(l => l.endsWith('user-accounts/spec.md')), labels.join(', '));
    const tasks = files.find(f => String(api.undo.getTreeItem(f).label).endsWith('tasks.md'))!;
    assert.strictEqual(api.undo.getTreeItem(api.undo.getChildren(tasks)[0]).label, '1.4 Nightly removal of unverified accounts');
  });
  await check('the agent\'s sync in the background: exit 1 - not marked; exit 0 - validated, marked (a document it left: in sync)', async () => {
    const { completeSync } = require('../src/agent');
    const ops = require('../src/ops');
    const p = api.projects()[0];
    const ch = path.join(work, 'openspec', 'changes', '01-add-user-signup');
    ops.setInSync(p, p.changes.find(c => c.name === '01-add-user-signup'));
    fs.appendFileSync(path.join(ch, 'proposal.md'), '\nA late note.\n');
    api.reload();
    const c = p.changes.find(x => x.name === '01-add-user-signup')!;
    const docs = ops.syncState(p).get(c.name);
    assert.deepStrictEqual(docs.map((d: { doc: { id: string } }) => d.doc.id).sort(), ['design', 'specs']);
    const file = ops.saveSyncSnapshot(p, c, docs, ops.savePrompt(p, 'sync-01-add-user-signup', ops.syncPrompt(p, c, docs)));
    fs.appendFileSync(path.join(ch, 'design.md'), '\nUpdated by the agent.\n');
    await completeSync(p, file, 1);
    assert.ok(fs.existsSync(file), 'exit code 1: not marked (the snapshot kept)');
    api.reload();
    assert.ok(String(api.plan.getTreeItem(api.plan.getChildren(api.plan.getChildren()[0])[0]).description).startsWith('! '), 'still out of date');
    await completeSync(p, file, 0);
    await new Promise(r => setTimeout(r, 300));
    assert.ok(!fs.existsSync(file), 'exit code 0, validated: marked (the snapshot used up)');
    api.reload();
    const item = api.plan.getTreeItem(api.plan.getChildren(api.plan.getChildren()[0])[0]);
    assert.ok(!String(item.description).startsWith('! '), `in sync: ${item.description}`);
  });
  await check('several out-of-date changes, one agent run: each validated and marked', async () => {
    const { completeSyncs } = require('../src/agent');
    const ops = require('../src/ops');
    const p = api.projects()[0];
    for (const n of ['01-add-user-signup', '03-add-order-history']) {
      ops.setInSync(p, p.changes.find(c => c.name === n));
      fs.appendFileSync(path.join(work, 'openspec', 'changes', n, 'proposal.md'), '\nA batch note.\n');
    }
    api.reload();
    const st = ops.syncState(p);
    const items = ['01-add-user-signup', '03-add-order-history'].map(n => ({ change: p.changes.find(c => c.name === n)!, stale: st.get(n) }));
    const rel = ops.savePrompt(p, 'sync-2-changes', ops.syncPromptMany(p, items));
    const files = items.map(i => ops.saveSyncSnapshot(p, i.change, i.stale, rel, true));
    await completeSyncs(p, files, 0);
    await new Promise(r => setTimeout(r, 300));
    assert.ok(files.every(f => !fs.existsSync(f)), 'both snapshots used up');
    api.reload();
    assert.strictEqual(ops.syncState(p).size, 0, 'both in sync');
  });
  await check('the bundled lazyspec.ps1 is in the extension', () => {
    assert.ok(fs.existsSync(path.join(vscode.extensions.getExtension('netmedia.lazyspec')!.extensionPath, 'kit', 'lazyspec.ps1')));
  });
  console.log(`\n  ${passed} passed, ${failures.length} failed\n`);
  if (failures.length) { throw new Error(`${failures.length} failed: ${failures.join('; ')}`); }
}

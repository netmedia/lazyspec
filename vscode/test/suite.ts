// Runs inside VS Code (run-vscode.ts): the extension activates on the project, its trees, its commands.

import * as assert from 'assert';
import * as fs from 'fs';
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
    for (const c of ['lazyspec.find', 'lazyspec.export', 'lazyspec.exportGroups', 'lazyspec.newChange', 'lazyspec.validate', 'lazyspec.archive', 'lazyspec.openTui', 'lazyspec.openFile']) {
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
    assert.strictEqual(api.scope.getTreeItem(api.scope.getChildren(ua)[0]).label, 'Sign in');
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
  await check('the bundled lazyspec.ps1 is in the extension', () => {
    assert.ok(fs.existsSync(path.join(vscode.extensions.getExtension('netmedia.lazyspec')!.extensionPath, 'kit', 'lazyspec.ps1')));
  });
  console.log(`\n  ${passed} passed, ${failures.length} failed\n`);
  if (failures.length) { throw new Error(`${failures.length} failed: ${failures.join('; ')}`); }
}

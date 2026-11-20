// LazySpec for Claude, end to end: dist/server.js over stdio (as Claude Desktop runs it) on a copy of
// examples/acme-portal in git, with a bare repository as its remote. node --test desktop/test/

const assert = require('assert');
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const readline = require('readline');
const { after, before, test } = require('node:test');

const SERVER = path.join(__dirname, '..', 'dist', 'server.js');
const EXAMPLE = path.join(__dirname, '..', '..', 'examples', 'acme-portal');
let tmp, root, child, rl, nextId = 1;
const waiting = new Map();

function git(args, cwd = root) { return cp.execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }); }
function call(method, params) {
  const id = nextId++;
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
  return new Promise(resolve => waiting.set(id, resolve));
}
async function tool(name, args = {}) {
  const r = await call('tools/call', { name, arguments: args });
  return { text: r.result.content[0].text, isError: r.result.isError };
}
async function ok(name, args) {
  const r = await tool(name, args);
  assert.ok(!r.isError, `${name} failed: ${r.text}`);
  return r.text;
}

before(async () => {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'lazyspec-'));
  root = path.join(tmp, 'projects', 'acme-portal');
  fs.cpSync(EXAMPLE, root, { recursive: true });
  fs.writeFileSync(path.join(root, 'src.cs'), 'public class Refunds { /* RefundWindowDays = 30 */ }\n');
  fs.writeFileSync(path.join(root, '.env'), 'SECRET=1\n');
  git(['init', '-q', '-b', 'develop']);
  git(['-c', 'user.name=t', '-c', 'user.email=t@t', 'add', '-A']);
  git(['-c', 'user.name=t', '-c', 'user.email=t@t', 'commit', '-qm', 'start']);
  git(['init', '-q', '--bare', path.join(tmp, 'remote.git')], tmp);
  git(['remote', 'add', 'origin', path.join(tmp, 'remote.git')]);
  git(['push', '-q', '-u', 'origin', 'develop']);
  git(['config', 'user.name', 't']); git(['config', 'user.email', 't@t']);
  child = cp.spawn(process.execPath, [SERVER, path.join(tmp, 'projects')], { stdio: ['pipe', 'pipe', 'inherit'], env: { ...process.env, PATH: process.env.PATH.split(path.delimiter).filter(d => !/GitHub CLI/i.test(d)).join(path.delimiter) } });
  rl = readline.createInterface({ input: child.stdout });
  rl.on('line', l => { const m = JSON.parse(l); waiting.get(m.id)?.(m); waiting.delete(m.id); });
  const init = await call('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'test', version: '1' } });
  assert.strictEqual(init.result.serverInfo.name, 'lazyspec');
});
after(() => { child?.kill(); fs.rmSync(tmp, { recursive: true, force: true }); });

test('lists tools and prompts', async () => {
  const t = await call('tools/list', {});
  const names = t.result.tools.map(x => x.name);
  for (const n of ['about', 'list_plan', 'find', 'edit_document', 'save', 'search_code']) { assert.ok(names.includes(n), n); }
  assert.ok(t.result.tools.find(x => x.name === 'read_code').annotations.readOnlyHint);
  const p = await call('prompts/get', { name: 'clarify', arguments: { change: '01-add-user-signup' } });
  assert.match(p.result.messages[0].content.text, /01-add-user-signup/);
});

test('reads the plan, specs, documents and context', async () => {
  assert.match(await ok('list_projects'), /acme-portal/);
  const plan = JSON.parse(await ok('list_plan'));
  const signup = plan.groups.flatMap(g => g.changes).find(c => c.change === '01-add-user-signup');
  assert.strictEqual(signup.tasks, '5/8');
  assert.match(await ok('list_specs', { with_requirements: true }), /online-payments/);
  assert.match(await ok('read_document', { change: '01-add-user-signup' }), /Documents of 01-add-user-signup/);
  assert.match(await ok('read_document', { spec: 'user-accounts' }), /Requirement/);
  assert.match(await ok('project_context'), /config\.yaml/);
  assert.ok((await tool('read_document', { path: 'src.cs' })).isError, 'read_document stays in openspec/');
});

test('finds, ticks and edits; main specs only through a change', async () => {
  const found = JSON.parse(await ok('find', { query: '1.4' }));
  assert.match(found.results[0].text, /Nightly removal/);
  await ok('tick_task', { change: '01-add-user-signup', task: '1.4' });
  assert.match(fs.readFileSync(path.join(root, 'openspec/changes/01-add-user-signup/tasks.md'), 'utf8'), /- \[x\] 1\.4/);

  await ok('edit_document', { path: 'openspec/changes/01-add-user-signup/tasks.md', old_text: '3.2 Test the e-mail', new_text: '3.2 Test the verification e-mail' });
  const spec = 'openspec/specs/user-accounts/spec.md';
  const text = fs.readFileSync(path.join(root, spec), 'utf8');
  const reqLine = text.split(/\r?\n/).find(l => /^### Requirement:/.test(l));
  const blocked = await tool('edit_document', { path: spec, old_text: reqLine, new_text: `${reqLine} (edited)` });
  assert.ok(blocked.isError && /through a change/.test(blocked.text), blocked.text);
  assert.ok((await tool('write_document', { path: 'src2.cs', content: 'x' })).isError);
  assert.ok((await tool('write_document', { path: 'openspec/specs/x/spec.md', content: 'x' })).isError);

  const req = JSON.parse(await ok('find', { query: reqLine.replace(/^### Requirement:\s*/, ''), kind: 'requirements' })).results.find(r => r.path === spec);
  assert.match(await ok('change_spec_requirement', { path: req.path, line: req.line, new_text: `${reqLine} (edited)\nThe system SHALL do it better.` }), /New change modify-specs-/);
});

test('new change, documents, out of date, undo', async () => {
  assert.match(await ok('new_change', { name: 'Add invoice export', group: '2' }), /add-invoice-export/);
  await ok('write_document', { path: 'openspec/changes/add-invoice-export/proposal.md', content: '# Proposal: Add invoice export\n\n## Why\nClients ask.\n\n## What Changes\n- Export.\n' });
  assert.ok((await tool('write_document', { path: 'openspec/changes/add-invoice-export/proposal.md', content: 'x' })).isError, 'no overwrite by default');
  await ok('out_of_date');
  const undo = JSON.parse(await ok('undo_list'));
  const tasks = undo.find(f => f.file.endsWith('01-add-user-signup/tasks.md'));
  assert.ok(tasks && tasks.pieces.length >= 1);
  await ok('undo', { file: tasks.file });
  assert.match(fs.readFileSync(path.join(root, 'openspec/changes/01-add-user-signup/tasks.md'), 'utf8'), /- \[ \] 1\.4/);
});

test('code is read-only and secrets stay out', async () => {
  assert.match(await ok('search_code', { query: 'RefundWindowDays' }), /src\.cs:1:/);
  assert.match(await ok('read_code', { path: 'src.cs' }), /class Refunds/);
  assert.ok((await tool('read_code', { path: '.env' })).isError);
  assert.ok((await tool('read_code', { path: '../../x' })).isError);
});

test('save commits openspec/ only on a branch and pushes it', async () => {
  fs.appendFileSync(path.join(root, 'src.cs'), '// not a spec\n');
  const r = await ok('save', { message: 'Spec for invoice export' });
  assert.match(r, /new branch spec\/spec-for-invoice-export-\d{8}/);
  assert.match(r, /pushed to origin/);
  const files = git(['show', '--name-only', '--format=', 'HEAD']);
  assert.ok(files.split('\n').filter(Boolean).every(f => f.startsWith('openspec/')), files);
  assert.match(git(['status', '--porcelain']), /src\.cs/);
});

test('a projects folder that is not there: the folder the server runs in', () => {
  const input = [
    { jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 't', version: '1' } } },
    { jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'about', arguments: {} } },
  ].map(m => JSON.stringify(m)).join('\n') + '\n';
  const r = cp.spawnSync(process.execPath, [SERVER, path.join(tmp, 'no-such-folder')], { cwd: path.join(tmp, 'projects'), input, encoding: 'utf8' });
  const about = JSON.parse(JSON.parse(r.stdout.split('\n')[1]).result.content[0].text);
  assert.deepStrictEqual(about.projects, ['acme-portal']);
  assert.match(about.foldersNotFound[0], /no-such-folder/);
});

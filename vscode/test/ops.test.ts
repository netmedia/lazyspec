// What the extension does to a project's documents, checked against what LazySpec does: deleting items (the
// main specs through a change), editing them, the agent's prompts, out-of-date documents (the same
// .lazyspec/sync.json as lazyspec.ps1 writes), undo against git, config.yaml. node --test out/test/

import * as assert from 'assert';
import * as cp from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { test } from 'node:test';
import { Entry, Project, searchIndex } from '../src/model';
import {
  blockEnd, hunkSummary, itemBlock, newModifyChange, removeEntries, revisionPrompt, setConfigBundle, setConfigValue,
  setInSync, setTaskText, syncPrompt, syncState, undoFile, undoHunk, undoRows, writeItemEdit,
} from '../src/ops';

const repo = path.resolve(__dirname, '..', '..', '..');
const demo = path.join(repo, 'examples', 'acme-portal');
const env = { PATH: '' } as NodeJS.ProcessEnv;

function copyDemo(): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'lazyspec-ops-'));
  fs.cpSync(demo, dir, { recursive: true });
  fs.rmSync(path.join(dir, '.lazyspec'), { recursive: true, force: true });
  return dir;
}
function load(dir: string) { return new Project(dir, env).load(); }
function entry(p: Project, kind: Entry['kind'], text: string): Entry {
  const e = searchIndex(p, false).find(x => x.kind === kind && x.text === text);
  assert.ok(e, `${kind} ${text}`);
  return e!;
}
const read = (f: string) => fs.readFileSync(f, 'utf8');

test('blocks: a task with the lines under it, a requirement, a scenario, a section', () => {
  const l = ['## 1. A', '- [ ] 1.1 One', '  more of it', '- [ ] 1.2 Two', '', '### Requirement: R', 'text', '#### Scenario: S', '- WHEN', '### Requirement: Q', '## Next', '```', '## not a heading', '```', '## Last'];
  assert.strictEqual(blockEnd(l, 1, 'task'), 3);
  assert.strictEqual(blockEnd(l, 5, 'req'), 9);
  assert.strictEqual(blockEnd(l, 7, 'scn'), 9);
  assert.strictEqual(blockEnd(l, 10, 'sec'), 14);
});

test('delete in a change: tasks and a delta spec\'s requirement taken out; a delta spec left empty deleted', () => {
  const dir = copyDemo();
  try {
    let p = load(dir);
    const tasks = path.join(dir, 'openspec', 'changes', '01-add-user-signup', 'tasks.md');
    const report = removeEntries(p, [entry(p, 'task', '1.4 Nightly removal of unverified accounts'), entry(p, 'task', '3.2 Test the e-mail in the common mail clients')]);
    assert.strictEqual(report.length, 2);
    assert.ok(!read(tasks).includes('1.4 Nightly') && !read(tasks).includes('3.2 Test') && read(tasks).includes('1.3 Verification endpoint'));
    assert.ok(!/\n\n\n/.test(read(tasks).replace(/\r/g, '')), 'no two blank lines in a row');
    p = load(dir);
    const notif = path.join(dir, 'openspec', 'changes', '01-add-user-signup', 'specs', 'notifications', 'spec.md');
    const r2 = removeEntries(p, [entry(p, 'req', 'Verification e-mail')]);
    assert.ok(!fs.existsSync(notif), 'its only requirement gone: the delta spec deleted');
    assert.ok(r2.some(x => x.includes('nothing left, deleted')));
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('delete in the main specs: a new change with REMOVED and MODIFIED (as LazySpec)', () => {
  const dir = copyDemo();
  try {
    const p = load(dir);
    const spec = path.join(dir, 'openspec', 'specs', 'user-accounts', 'spec.md');
    const before = read(spec);
    const report = removeEntries(p, [entry(p, 'req', 'Password reset'), entry(p, 'scn', 'Wrong password')]);
    assert.strictEqual(read(spec), before, 'the main spec itself untouched');
    const m = /the change (remove-from-specs-\d{8}(?:-\d+)?)/.exec(report.join('\n'));
    assert.ok(m, report.join('\n'));
    const delta = read(path.join(dir, 'openspec', 'changes', m![1], 'specs', 'user-accounts', 'spec.md'));
    assert.ok(delta.includes('## REMOVED Requirements') && delta.includes('### Requirement: Password reset') && delta.includes('**Reason**'));
    assert.ok(delta.includes('## MODIFIED Requirements') && delta.includes('### Requirement: Sign in') && delta.includes('Valid password') && !delta.includes('Wrong password'));
    assert.ok(fs.existsSync(path.join(dir, 'openspec', 'changes', m![1], 'proposal.md')));
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('edit: an item\'s block; written back where it is; a task\'s text; a main spec through a change', () => {
  const dir = copyDemo();
  try {
    const p = load(dir);
    const e = entry(p, 'req', 'Self sign-up');
    const b = itemBlock(e)!;
    assert.strictEqual(b.lines[0], '### Requirement: Self sign-up');
    assert.ok(b.lines.some(l => l.includes('Address in use')) && !b.lines.some(l => l.includes('E-mail verification')));
    writeItemEdit(e.path, e.line, b.lines, ['### Requirement: Self sign-up', 'The system SHALL let a visitor sign up.']);
    assert.ok(read(e.path).includes('The system SHALL let a visitor sign up.') && read(e.path).includes('### Requirement: E-mail verification'));
    const t = entry(p, 'task', '2.1 Sign-up page');
    setTaskText(t.path, t.line, '2.1 Sign-up page with a password meter');
    assert.ok(read(t.path).includes('- [x] 2.1 Sign-up page with a password meter'));
    const p2 = load(dir);
    const { name, file } = newModifyChange(p2, entry(p2, 'scn', 'Reset link'));
    assert.ok(/^modify-specs-\d{8}/.test(name));
    assert.ok(read(file).startsWith('## MODIFIED Requirements\n\n### Requirement: Password reset'));
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('the agent\'s prompt: each item, where it is, as it is now', () => {
  const p = load(demo);
  const s = revisionPrompt(p, [entry(p, 'task', '1.4 Nightly removal of unverified accounts')], 'change', 'Make it weekly');
  assert.ok(s.includes('> Make it weekly'));
  assert.ok(s.includes('- File: openspec/changes/01-add-user-signup/tasks.md (line 7)'));
  assert.ok(s.includes('```markdown\n- [ ] 1.4 Nightly removal of unverified accounts\n```'));
});

test('config.yaml: a value and a saved whole written, the rest of the file as it was', () => {
  const dir = copyDemo();
  try {
    const cfg = path.join(dir, 'openspec', 'config.yaml');
    const before = read(cfg);
    let p = load(dir);
    setConfigValue(p, 'agent', 'background');
    setConfigValue(p, 'agent', 'here');
    setConfigBundle(p, 'phase-two', 'Phase "two"', [], ['2']);
    p = load(dir);
    assert.strictEqual(p.config.values.agent, 'here');
    assert.deepStrictEqual(p.config.bundles.find(b => b.id === 'phase-two'), { id: 'phase-two', title: "Phase 'two'", changes: [], groups: ['2'] });
    assert.ok(read(cfg).includes('context: |'), 'the rest stays');
    setConfigBundle(p, 'phase-two', '', []);
    setConfigValue(load(dir), 'agent', 'x');
    assert.strictEqual(read(cfg).replace(/  agent: x\n/, ''), before, 'only its own lines');
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('out of date: the baseline noted; a spec changed after the tasks; marked in sync; the prompt', () => {
  const dir = copyDemo();
  try {
    setConfigValue(load(dir), 'syncCheck', 'on');
    let p = load(dir);
    assert.strictEqual(syncState(p).size, 0, 'the first time: the baseline');
    assert.ok(fs.existsSync(path.join(dir, '.lazyspec', 'sync.json')));
    const spec = path.join(dir, 'openspec', 'changes', '01-add-user-signup', 'specs', 'user-accounts', 'spec.md');
    fs.writeFileSync(spec, read(spec).replace('at least 12', 'at least 14') + '\n### Requirement: Nickname\nThe system SHALL keep a nickname.\n');
    p = load(dir);
    const st = syncState(p).get('01-add-user-signup')!;
    assert.ok(st, 'out of date');
    const tasks = st.find(s => s.doc.id === 'tasks')!;
    assert.deepStrictEqual(tasks.diffs.map(d => `${d.mark} ${d.req}`).sort(), ['+ Nickname', '~ Self sign-up']);
    assert.ok(syncPrompt(p, p.changes.find(c => c.name === '01-add-user-signup')!, st).includes('requirement "Nickname" added'));
    setInSync(p, p.changes.find(c => c.name === '01-add-user-signup')!);
    assert.strictEqual(syncState(load(dir)).size, 0);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('out of date: the same .lazyspec/sync.json as lazyspec.ps1 (its baseline: in sync here)', { skip: process.platform !== 'win32' && !fs.existsSync('/usr/local/bin/pwsh') && !fs.existsSync('/opt/homebrew/bin/pwsh') }, () => {
  const dir = copyDemo();
  try {
    setConfigValue(load(dir), 'syncCheck', 'on');
    const ps = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';
    const frames = path.join(dir, 'frames.txt');
    cp.execFileSync(ps, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(repo, 'tools', 'lazyspec', 'lazyspec.ps1'), '-Root', dir, '-Keys', 'snap', '-Frames', frames], { stdio: 'ignore', timeout: 120000 });
    const written = read(path.join(dir, '.lazyspec', 'sync.json'));
    assert.ok(written.includes('01-add-user-signup'), 'LazySpec noted the baseline');
    assert.strictEqual(syncState(load(dir)).size, 0, 'the extension reads it as in sync');
    assert.strictEqual(read(path.join(dir, '.lazyspec', 'sync.json')), written, 'and has nothing to add to it');
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('undo: the files changed since the commit, a piece undone, a new file deleted, a file put back', () => {
  const dir = copyDemo();
  const g = (...a: string[]) => cp.execFileSync('git', ['-c', 'user.name=t', '-c', 'user.email=t@t', '-c', 'core.autocrlf=false', ...a], { cwd: dir, stdio: 'ignore' });
  try {
    g('init', '-q'); g('add', '-A'); g('commit', '-q', '-m', 'start');
    const tasks = path.join(dir, 'openspec', 'changes', '01-add-user-signup', 'tasks.md');
    const original = read(tasks);
    const p = load(dir);
    removeEntries(p, [entry(p, 'task', '1.4 Nightly removal of unverified accounts'), entry(p, 'task', '3.2 Test the e-mail in the common mail clients')]);
    fs.writeFileSync(path.join(dir, 'openspec', 'changes', '01-add-user-signup', 'notes.md'), '# Notes\n');
    let rows = undoRows(dir)!;
    const f = rows.find(r => r.rel.endsWith('tasks.md'))!;
    assert.strictEqual(f.kind, 'changed');
    assert.strictEqual(f.hunks.length, 2);
    assert.deepStrictEqual(f.hunks.map(h => hunkSummary(h).text), ['1.4 Nightly removal of unverified accounts', '3.2 Test the e-mail in the common mail clients']);
    assert.ok(rows.some(r => r.kind === 'new' && r.rel.endsWith('notes.md')));
    undoHunk(dir, f.hunks[1]);
    assert.ok(read(tasks).includes('3.2 Test the e-mail') && !read(tasks).includes('1.4 Nightly'));
    rows = undoRows(dir)!;
    undoFile(dir, rows.find(r => r.kind === 'new')!);
    undoFile(dir, rows.find(r => r.rel.endsWith('tasks.md'))!);
    assert.strictEqual(read(tasks).replace(/\r/g, ''), original.replace(/\r/g, ''), 'as committed (its line ends as git checks it out)');
    assert.deepStrictEqual(undoRows(dir), []);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

// The extension's reading of OpenSpec, as LazySpec reads it: the demo project (examples/acme-portal) and
// a grouped project built in the temp folder. node --test out/test/

import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { test } from 'node:test';
import { artifactFiles, find, globRegex, itemTitle, parseConfig, parseTasks, parseWorkflow, Project, searchIndex, setTaskDone } from '../src/model';

const repo = path.resolve(__dirname, '..', '..', '..');
const demo = path.join(repo, 'examples', 'acme-portal');
const env = { PATH: '' } as NodeJS.ProcessEnv; // no user or CLI schemas: the same everywhere

test('the demo project: its specs, in the Scope order, with titles and counts', () => {
  const p = new Project(demo, env).load();
  assert.strictEqual(p.name, 'Acme Portal');
  assert.deepStrictEqual(p.specs.map(s => s.name).slice(0, 2), ['platform-overview', 'platform-architecture']);
  const ua = p.specs.find(s => s.name === 'user-accounts')!;
  assert.strictEqual(ua.title, 'User accounts');
  assert.ok(ua.reqs >= 2);
  assert.strictEqual(ua.requirements[0].name, 'Sign in');
  assert.strictEqual(ua.requirements[0].scenarios[0].name, 'Valid password');
  assert.ok(ua.requirements[0].line > 1);
});

test('the demo project: a change, its documents, tasks, delta specs and stage', () => {
  const p = new Project(demo, env).load();
  const c = p.changes.find(x => x.name === '01-add-user-signup')!;
  assert.strictEqual(itemTitle(c), '01 Add user sign-up');
  assert.strictEqual(c.stage, 'In Progress');
  assert.strictEqual(c.total, 8);
  assert.strictEqual(c.done, 5);
  assert.deepStrictEqual(c.taskGroups.map(g => g.title), ['1. Backend', '2. Front end', '3. E-mail']);
  assert.strictEqual(c.taskGroups[0].tasks[3].num, '1.4');
  assert.deepStrictEqual(c.caps.map(x => x.name), ['notifications', 'user-accounts']);
  assert.strictEqual(c.caps[1].added, 2);
  assert.deepStrictEqual(c.docs.map(d => d.id), ['proposal', 'specs', 'design', 'tasks', 'models']);
  assert.ok(c.docs.find(d => d.id === 'models')!.extra, 'models.md: not in spec-driven, shown after');
  assert.ok(p.changes.some(x => x.archived && x.stage === 'Archived'));
  const draft = p.changes.find(x => x.name === '02-add-refunds-to-online-payments')!;
  assert.strictEqual(draft.stage, 'Draft');
  assert.strictEqual(p.grouping, false, 'no grouping: the plan flat');
});

test('the demo project: a saved whole in config.yaml', () => {
  const p = new Project(demo, env).load();
  assert.deepStrictEqual(p.config.bundles, [{ id: 'accounts-and-orders', title: 'Accounts and orders', changes: ['01-add-user-signup', '03-add-order-history'], groups: [] }]);
});

test('find: a task number, a change and a number, words, a kind', () => {
  const p = new Project(demo, env).load();
  const idx = searchIndex(p, false);
  const r1 = find(p, idx, '1.3');
  assert.deepStrictEqual(r1.map(e => `${e.where} ${e.text}`), ['01 Add user sign-up 1.3 Verification endpoint', '03 Add order history 1.3 Empty state for customers without orders']);
  assert.strictEqual(find(p, idx, '01 1.3').length, 1);
  const reqs = find(p, idx, 'verif', 'requirements');
  assert.ok(reqs.length >= 1 && reqs.every(e => e.kind === 'req'));
  const pw = find(p, idx, 'password reset');
  assert.strictEqual(pw[0].kind, 'req');
  assert.strictEqual(pw[0].where, 'User accounts');
  assert.strictEqual(find(p, idx, '').length, 0);
  assert.strictEqual(find(p, idx, 'sign-in endpoint').length, 0, 'archived: only when shown');
  assert.ok(find(p, searchIndex(p, true), 'sign-in endpoint').length > 0);
});

test('a schema: artifacts, requires (inline or a list), apply.tracks, language, grouping', () => {
  const wf = parseWorkflow('name: x\ngrouping:\n  - group\nlanguage: hr\nartifacts:\n  - id: brief\n    generates: brief.md\n  - id: specs\n    generates: "specs/**/*.md"\n    requires:\n      - brief\n  - id: work\n    generates: work.md\n    requires: [brief, specs]\napply:\n  requires: [work]\n  tracks: work.md\n', 'x')!;
  assert.deepStrictEqual(wf.artifacts.map(a => a.id), ['brief', 'specs', 'work']);
  assert.deepStrictEqual(wf.artifacts[1].requires, ['brief']);
  assert.deepStrictEqual(wf.artifacts[2].requires, ['brief', 'specs']);
  assert.strictEqual(wf.tracks, 'work.md');
  assert.strictEqual(wf.language, 'hr');
  assert.deepStrictEqual(wf.grouping, ['group']);
  assert.deepStrictEqual(parseWorkflow('grouping: [group]\nartifacts:\n  - id: a\n    generates: a.md\n', 'y')!.grouping, ['group']);
});

test('globs as the schemas write them', () => {
  assert.ok(globRegex('specs/**/*.md').test('specs/a/spec.md'));
  assert.ok(globRegex('specs/**/*.md').test('specs/spec.md'));
  assert.ok(globRegex('{a,b}.md').test('b.md'));
  assert.ok(!globRegex('*.md').test('x/y.md'));
  assert.strictEqual(artifactFiles(path.join(demo, 'openspec', 'changes', '01-add-user-signup'), 'specs/**/*.md').length, 2);
});

test('tasks: groups, numbers, done; a task ticked changes only its box', () => {
  const g = parseTasks('# T\n\n## 1. A\n- [x] 1.1 **One**\n- [ ] 1.2 Two\n\n## 2. B\n* [X] 2.1 Three\n', 'f');
  assert.deepStrictEqual(g.map(x => [x.title, x.tasks.length]), [['1. A', 2], ['2. B', 1]]);
  assert.deepStrictEqual(g[0].tasks.map(t => [t.num, t.text, t.done, t.line]), [['1.1', '1.1 One', true, 4], ['1.2', '1.2 Two', false, 5]]);
  assert.strictEqual(setTaskDone('  - [ ] 1.2 Two [x]', true), '  - [x] 1.2 Two [x]');
  assert.strictEqual(setTaskDone('* [X] 2.1 Three', false), '* [ ] 2.1 Three');
});

test('groups: config, a change\'s group from its four sources, titles, selection, plan, find', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'lazyspec-vscode-'));
  const w = (rel: string, text: string) => { const f = path.join(root, rel); fs.mkdirSync(path.dirname(f), { recursive: true }); fs.writeFileSync(f, text); };
  try {
    w('openspec/config.yaml', 'schema: spec-driven\ngroupLabel: "Phase"\ngroupLabelPlural: "Phases"\ngroups:\n  - id: 1\n    name: "Launch"\n    description: "Sign-up and orders live"\n    requires: []\n  - id: 2\n    name: "Loyalty"\n    description: >\n      Points for every order,\n      redeemed at checkout\n    requires:\n      - 1\n  - id: 3\n    name: "Reports"\n    requires: [2]\nlazyspec:\n  name: Demo Shop\n  bundles:\n    phase-two:\n      title: "Phase two"\n      groups: 2\n');
    const change = (dir: string, h1: string, under: string, group: string, note = '') => {
      w(`openspec/changes/${dir}/proposal.md`, `# ${h1}\n\n${under}\n\n## Why\nBecause. ${note}\n`);
      w(`openspec/changes/${dir}/tasks.md`, '# Tasks\n\n## 1. Work\n- [ ] 1.1 It works\n- [x] 1.2 Done\n');
      w(`openspec/changes/${dir}/.openspec.yaml`, `schema: spec-driven\n${group ? `x-group: ${group}\n` : ''}`);
    };
    change('g1-01-add-signup', 'Proposal: G1 · Add sign-up', '', '1');
    change('add-orders', 'Add orders', 'Phase: 1 – Launch', '');
    change('g2-01-add-points', 'G2 · Add points', '', '', 'Needs g1-01-add-signup first.');
    change('add-report', 'Add report', '', '3');
    change('fix-typo', 'Fix a typo', '', '');
    const p = new Project(root, env).load();
    assert.strictEqual(p.config.groupLabel, 'Phase');
    assert.deepStrictEqual(p.config.groups.map(g => [g.id, g.name, g.requires]), [['1', 'Launch', []], ['2', 'Loyalty', ['1']], ['3', 'Reports', ['2']]]);
    assert.strictEqual(p.config.groups[1].description, 'Points for every order, redeemed at checkout');
    assert.deepStrictEqual(p.config.bundles[0].groups, ['2']);
    const by = (n: string) => p.changes.find(c => c.name === n)!;
    assert.deepStrictEqual([by('g1-01-add-signup').groupFrom, by('add-orders').groupFrom, by('g2-01-add-points').groupFrom, by('fix-typo').groupFrom], ['x-group', 'title', 'folder', '']);
    assert.strictEqual(itemTitle(by('g1-01-add-signup')), '01 Add sign-up');
    assert.strictEqual(itemTitle(by('g2-01-add-points')), '01 Add points');
    assert.ok(p.grouping);
    assert.deepStrictEqual(p.groups().map(g => [g.id, g.changes.length, g.done, g.total]), [['1', 2, 2, 4], ['2', 1, 1, 2], ['3', 1, 1, 2], ['', 1, 1, 2]]);
    assert.strictEqual(p.groupTitle('2'), 'Phase 2 – Loyalty');
    assert.strictEqual(p.groupTitle(''), 'Ungrouped');
    const sel = p.groupSelection(['3']);
    assert.deepStrictEqual(sel.ids, ['1', '2', '3']);
    assert.deepStrictEqual([...sel.added].sort(), ['1', '2']);
    assert.deepStrictEqual(p.groupDependencies('2').map(d => `${d.change.name}>${d.on.name}`), ['g2-01-add-points>g1-01-add-signup']);
    const idx = searchIndex(p, false);
    assert.deepStrictEqual([...new Set(find(p, idx, 'g2 works').map(e => e.item.name))], ['g2-01-add-points']);
    assert.deepStrictEqual([...new Set(find(p, idx, 'phase 1 works').map(e => e.item.name))].sort(), ['add-orders', 'g1-01-add-signup']);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});

test('config: lazyspec values, a list or an inline list', () => {
  const c = parseConfig('lazyspec:\n  name: X\n  agent: here\n  bundles:\n    a:\n      title: "A"\n      changes: [one, two]\n');
  assert.strictEqual(c.values.name, 'X');
  assert.strictEqual(c.values.agent, 'here');
  assert.deepStrictEqual(c.bundles[0].changes, ['one', 'two']);
  assert.strictEqual(c.groupLabel, 'Group');
  assert.strictEqual(c.groupPlural, 'Groups');
});

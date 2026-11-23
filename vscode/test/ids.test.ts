// Item ids (<KEY>-<KIND>-<nn>: OSN-T-04): read from tasks, requirements, scenarios, open questions and decisions,
// openspec/project-tasks.md, openspec/keys.yaml; found by the id or its beginning. test/fixtures/ids.

import * as assert from 'assert';
import * as path from 'path';
import { test } from 'node:test';
import { find, idLabel, isIdLike, itemId, parseKeys, parseRequirements, parseTasks, Project, searchIndex } from '../src/model';

const fixture = path.resolve(__dirname, '..', '..', 'test', 'fixtures', 'ids');
const env = { PATH: '' } as NodeJS.ProcessEnv;
const load = () => new Project(fixture, env).load();
const ids = (list: { id?: string }[]) => list.map(e => e.id || '');

test('ids: a task with and without its number, none', () => {
  const g = parseTasks('## 1. A\n- [ ] 1.1 OSN-T-01 Dodati klase\n- [x] OSN-T-02 Bez broja\n- [ ] 1.3 No id\n- [ ] 1.4 osn-t-05 lower case is not one\n', 'f');
  assert.deepStrictEqual(g[0].tasks.map(t => [t.num, t.id]), [['1.1', 'OSN-T-01'], ['', 'OSN-T-02'], ['1.3', ''], ['1.4', '']]);
  assert.strictEqual(g[0].tasks[0].text, '1.1 OSN-T-01 Dodati klase', 'the text as it is');
  assert.strictEqual(idLabel(g[0].tasks[0].id, g[0].tasks[0].text), 'OSN-T-01 1.1 Dodati klase');
  assert.strictEqual(idLabel('', '1.3 No id'), '1.3 No id');
  assert.strictEqual(itemId('OSN-T-1 one digit'), '');
  assert.strictEqual(itemId('TOOLONG-T-01 x'), '');
});

test('ids: requirement and scenario headings, also in Croatian and German', () => {
  const r = parseRequirements('### Zahtjev: OSN-R-03 Online plaćanje\n#### Scenarij: OSN-S-07 Plaćeno karticom\n### Anforderung: OSN-R-04 Zahlung\n#### Szenario: OSN-S-08 Bezahlt\n### Requirement: Without\n#### Scenario: Plain\n');
  assert.deepStrictEqual(r.map(x => x.id), ['OSN-R-03', 'OSN-R-04', '']);
  assert.deepStrictEqual(r.map(x => x.scenarios[0].id), ['OSN-S-07', 'OSN-S-08', '']);
});

test('keys.yaml: kinds, keys, retired', () => {
  const p = load();
  assert.strictEqual(p.keys.kinds.Q, 'open question');
  assert.deepStrictEqual(p.keys.keys, [{ key: 'OSN', group: '1', name: 'Osnova' }, { key: 'ZAJ', group: '0', name: 'Zajedničko' }]);
  assert.deepStrictEqual(p.keys.retired.map(r => [r.id, r.reason, r.into]), [['OSN-T-11', 'split', ['OSN-T-73', 'OSN-T-74']], ['OSN-T-20', 'removed', []]]);
  assert.deepStrictEqual(parseKeys(''), { kinds: {}, keys: [], retired: [] }, 'missing: empty');
});

test('project-tasks.md: a change of its own, in the index', () => {
  const p = load();
  assert.ok(p.projectTasks);
  assert.strictEqual(p.projectTasks!.name, 'project-tasks');
  assert.strictEqual(p.projectTasks!.total, 2);
  assert.ok(!p.changes.includes(p.projectTasks!), 'not one of the changes');
  const hits = find(p, searchIndex(p, false), 'zaj-t');
  assert.deepStrictEqual(ids(hits), ['ZAJ-T-01', 'ZAJ-T-02']);
  assert.strictEqual(hits[0].where, 'Project tasks');
});

test('the index: an id for every kind; open questions and decisions', () => {
  const p = load();
  const idx = searchIndex(p, false);
  const of = (id: string) => idx.find(e => e.id === id)!;
  assert.strictEqual(of('OSN-T-04').kind, 'task');
  assert.strictEqual(of('OSN-R-03').kind, 'req');
  assert.strictEqual(of('OSN-S-07').kind, 'scn');
  assert.strictEqual(of('OSN-Q-02').kind, 'item');
  assert.strictEqual(of('OSN-D-04').kind, 'item');
  assert.strictEqual(of('OSN-D-04').art, 'Design');
  assert.ok(!idx.some(e => e.kind === 'item' && !e.id), 'list lines without an id: not items');
});

test('find by id: a prefix, the exact one first, then in id order', () => {
  const p = load();
  const idx = searchIndex(p, false);
  assert.deepStrictEqual(ids(find(p, idx, 'OSN-T-0')), ['OSN-T-01', 'OSN-T-04', 'OSN-T-09', 'OSN-T-040', 'OSN-T-041']);
  assert.deepStrictEqual(ids(find(p, idx, 'osn-t-04')), ['OSN-T-04', 'OSN-T-040', 'OSN-T-041']);
  assert.deepStrictEqual(ids(find(p, idx, 'OSN-T')), ['OSN-T-01', 'OSN-T-04', 'OSN-T-09', 'OSN-T-040', 'OSN-T-041', 'OSN-T-73', 'OSN-T-74']);
  const all = find(p, idx, 'osn');
  for (const id of ['OSN-T-01', 'OSN-R-01', 'OSN-R-03', 'OSN-S-07', 'OSN-Q-02', 'OSN-D-04']) { assert.ok(ids(all).includes(id), id); }
  assert.ok(all.some(e => !e.id), 'osn: also the text (Osnova)');
  assert.strictEqual(all.findIndex(e => !e.id), all.filter(e => e.id).length, 'ids first');
  assert.deepStrictEqual(ids(find(p, idx, 'OSN-R-03', 'requirements')), ['OSN-R-03']);
  assert.ok(isIdLike('OSN-') && isIdLike('osn-t-') && isIdLike('OSN-T-0') && !isIdLike('osn') && !isIdLike('sign-up'));
});

test('find a retired id: what became of it, then its successors', () => {
  const p = load();
  const idx = searchIndex(p, false);
  const split = find(p, idx, 'OSN-T-11');
  assert.strictEqual(split[0].text, 'OSN-T-11 - split into OSN-T-73, OSN-T-74');
  assert.deepStrictEqual(ids(split.slice(1)), ['OSN-T-73', 'OSN-T-74']);
  assert.ok(split[0].path.endsWith('keys.yaml'));
  const removed = find(p, idx, 'osn-t-20');
  assert.deepStrictEqual(removed.map(e => e.text), ['OSN-T-20 - removed']);
});

test('no ids: as before', () => {
  const p = load();
  const idx = searchIndex(p, false);
  assert.deepStrictEqual(find(p, idx, '1.8').map(e => e.text), ['1.8 Plain task without an id']);
  assert.deepStrictEqual(find(p, idx, 'plain task', 'tasks').map(e => e.id || ''), ['']);
  assert.strictEqual(find(p, idx, 'without an id', 'requirements')[0].text, 'Without an id');
});

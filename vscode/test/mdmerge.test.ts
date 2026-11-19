// The formatted editor's edits merged back into the files: nothing edited - the file as it was; an edit - only
// its lines. Its Markdown as the real editor writes it: test/fixtures/roundtrip.json (scripts/roundtrip.js on the
// demo project, Milkdown in a browser).

import * as assert from 'assert';
import * as fs from 'fs';
import * as path from 'path';
import { test } from 'node:test';
import { mergeEdit } from '../src/mdmerge';

const repo = path.resolve(__dirname, '..', '..', '..');
const fixture = path.resolve(__dirname, '..', '..', 'test', 'fixtures', 'roundtrip.json');
const docs: { file: string; md: string }[] = JSON.parse(fs.readFileSync(fixture, 'utf8'));
const original = (f: string) => fs.readFileSync(path.join(repo, 'examples', 'acme-portal', 'openspec', f), 'utf8').replace(/\r/g, '');
const changed = (a: string, b: string) => { const x = a.split('\n'), y = b.split('\n'); return x.map((l, i) => l === y[i] ? -1 : i).filter(i => i >= 0); };

test('nothing edited: every document exactly as it was (the editor writes them its own way)', () => {
  assert.ok(docs.length >= 15);
  for (const d of docs) {
    const o = original(d.file);
    assert.notStrictEqual(d.md.trimEnd(), o.trimEnd(), `${d.file}: the editor writes it differently (else this proves nothing)`);
    assert.strictEqual(mergeEdit(o, d.md, d.md), o, d.file);
  }
});

test('a word changed: that line only', () => {
  for (const d of docs) {
    const o = original(d.file);
    const lines = d.md.split('\n');
    const at = lines.findIndex(l => /^[A-Z].{20,}/.test(l));
    if (at < 0) { continue; }
    const word = /^(\S+)/.exec(lines[at])![1];
    lines[at] = lines[at].replace(word, 'Edited');
    const m = mergeEdit(o, d.md, lines.join('\n'));
    const diff = changed(o, m);
    assert.strictEqual(diff.length, 1, `${d.file}: ${diff.length} lines changed`);
    assert.ok(m.split('\n')[diff[0]].startsWith('Edited'), d.file);
  }
});

test('a task ticked, a task added, a scenario removed: only those lines, in OpenSpec\'s form', () => {
  const tasks = docs.find(d => d.file.replace(/\\/g, '/') === 'changes/01-add-user-signup/tasks.md')!;
  const o = original(tasks.file);
  const edited = tasks.md.replace('- [ ] 1.4 Nightly', '- [x] 1.4 Nightly').replace('- [x] 2.1 Sign-up page\n', '- [x] 2.1 Sign-up page\n- [ ] 2.3 A new task\n');
  const m = mergeEdit(o, tasks.md, edited);
  assert.ok(m.includes('- [x] 1.4 Nightly removal') && m.includes('- [x] 2.1 Sign-up page\n- [ ] 2.3 A new task\n- [ ] 2.2'), m);
  assert.strictEqual(m.split('\n').length, o.split('\n').length + 1);
  const spec = docs.find(d => d.file.replace(/\\/g, '/') === 'specs/user-accounts/spec.md')!;
  const so = original(spec.file);
  const cut = spec.md.replace(/#### Scenario: Wrong password\n\n- \*\*WHEN\*\* the password is wrong\n- \*\*THEN\*\* the customer sees an error and stays signed out\n\n/, '');
  assert.notStrictEqual(cut, spec.md, 'the scenario found in the editor\'s Markdown');
  const sm = mergeEdit(so, spec.md, cut);
  assert.ok(!sm.includes('Wrong password') && sm.includes('#### Scenario: Valid password') && sm.includes('### Requirement: Password reset'), sm);
  assert.ok(!/\n\n\n/.test(sm), 'no blank lines piled up');
});

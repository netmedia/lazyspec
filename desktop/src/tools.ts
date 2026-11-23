// LazySpec's tools: what the VS Code extension and the terminal app do to a project's OpenSpec, for Claude.
// Generic on purpose: how a company runs its process belongs in skills, not here.

import * as fs from 'fs';
import * as path from 'path';
import { Change, Entry, find, FindKind, itemTitle, Project, readText, searchIndex, setTaskDone } from '../../vscode/src/model';
import { kindWord, newModifyChange, removeEntries, requirementBlocks, setInSync, slug, syncState, undoFile, undoHunk, undoRows } from '../../vscode/src/ops';
import { Tool, UserError } from './mcp';
import {
  checkToolArgs, clip, discover, exportDir, git, isFile, json, KNOWLEDGE_PATHS, kitScript, missingRoots, NETMEDIA_TOOLS, netmediaScript, onPath, openspec,
  openspecVersion, powershell, project, projectId, python, readableCode, readableDoc, readRaw, rel, roots, run, today, writable, writableFile, writeRaw,
} from './projects';

declare const LAZYSPEC_VERSION: string;
export const VERSION = typeof LAZYSPEC_VERSION === 'string' ? LAZYSPEC_VERSION : '0.0.0-dev';

// --- schema helpers ------------------------------------------------------------------------------------------

const P = { project: { type: 'string', description: 'The project: its name from list_projects (optional when there is only one).' } };
const str = (description: string) => ({ type: 'string', description });
const bool = (description: string) => ({ type: 'boolean', description });
const num = (description: string) => ({ type: 'integer', description });
function schema(props: Record<string, unknown>, required: string[] = []) {
  return { type: 'object', properties: { ...P, ...props }, required, additionalProperties: false };
}
const s = (v: unknown) => (v === undefined || v === null ? '' : String(v));

function change(p: Project, name: unknown, archivedToo = false): Change {
  const n = s(name).trim();
  if (!n) { throw new UserError('change is required (its folder name, from list_plan).'); }
  const pool = p.changes.filter(c => archivedToo || !c.archived);
  const c = pool.find(x => x.name === n) || pool.find(x => x.name.toLowerCase() === n.toLowerCase())
    || (() => { const m = pool.filter(x => x.name.toLowerCase().includes(n.toLowerCase())); return m.length === 1 ? m[0] : undefined; })();
  if (!c) { throw new UserError(`No change "${n}". Active: ${p.changes.filter(x => !x.archived).map(x => x.name).join(', ') || 'none'}.`); }
  return c;
}
function entryOut(p: Project, e: Entry) {
  return {
    kind: kindWord(e.kind), in: e.where, capability: e.cap || undefined, under: e.context || undefined,
    number: e.num || undefined, text: e.text, done: e.kind === 'task' ? e.done : undefined, path: rel(p, e.path), line: e.line,
  };
}
function entriesAt(p: Project, items: unknown): { found: Entry[]; missing: string[] } {
  const list = Array.isArray(items) ? items as { path?: string; line?: number }[] : [];
  if (!list.length) { throw new UserError('items is required: [{ path, line }] as find returns them.'); }
  const index = searchIndex(p, false);
  const found: Entry[] = [], missing: string[] = [];
  for (const it of list) {
    const want = path.resolve(p.root, s(it.path)).toLowerCase();
    const e = index.find(x => x.path.toLowerCase() === want && x.line === Number(it.line));
    if (e) { found.push(e); } else { missing.push(`${it.path}:${it.line}`); }
  }
  return { found, missing };
}

// --- the tools ---------------------------------------------------------------------------------------------------

export const tools: Tool[] = [
  {
    name: 'about', title: 'About LazySpec', readOnly: true,
    description: 'LazySpec\'s version, the folders it looks in, the projects it found, and whether git, GitHub CLI, the OpenSpec CLI, PowerShell and the Netmedia tools (Python with python-docx, openpyxl and pyyaml; where each tool\'s script comes from) are there. Call it first when a skill needs a minimum LazySpec version or something does not work.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
    run: () => {
      const py = python();
      const check = run(py.cmd, [...py.pre, '-c', 'import sys, docx, openpyxl, yaml; print(sys.version.split()[0])'], process.cwd(), 30000);
      const netmediaTools = Object.fromEntries(Object.keys(NETMEDIA_TOOLS).map(n => [n, netmediaScript(n).from || 'not found']));
      return {
        text: json({
          lazyspec: VERSION, folders: roots(), foldersNotFound: missingRoots().length ? missingRoots() : undefined, projects: discover().map(f => f.id), node: process.version,
          git: !!onPath('git'), gh: !!onPath('gh'), openspec: openspecVersion(), powershell: powershell(),
          python: check.missing ? 'not found' : check.code ? `${py.cmd}: python-docx, openpyxl or pyyaml missing (Netmedia setup: ~/.netmedia/python)` : `${check.out.trim()} (${py.env ? '~/.netmedia/python' : py.cmd})`,
          netmediaTools,
        }),
      };
    },
  },
  {
    name: 'list_projects', title: 'List projects', readOnly: true,
    description: 'The OpenSpec projects (folders with openspec/) in the configured folders: name, path, number of specs and active changes.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
    run: () => {
      const all = discover().map(f => {
        const p = new Project(f.root).load();
        return { project: f.id, path: f.root, specs: p.specs.length, activeChanges: p.changes.filter(c => !c.archived).length };
      });
      return { text: all.length ? json(all) : `No OpenSpec project found in ${roots().join(', ')}.` };
    },
  },
  {
    name: 'project_context', title: 'Project context', readOnly: true,
    description: 'How this project is run: openspec/config.yaml (schema, language, groups, context), the workflow\'s documents, and the project\'s own instructions when present (CLAUDE.md, .claude/rules/pm-profile.md, in the project and its workspace folder). Read it before writing or changing specs.',
    inputSchema: schema({}),
    run: (a) => {
      const p = project(a.project);
      const wf = p.workflowFor(path.join(p.osDir, 'changes', '__none__'));
      const files: Record<string, string> = {};
      const parent = path.dirname(p.root);
      const candidates = [path.join(p.root, 'CLAUDE.md'), path.join(p.root, '.claude', 'rules', 'pm-profile.md')];
      if (isFile(path.join(parent, 'workspace.json')) || isFile(path.join(parent, '.claude', 'rules', 'pm-profile.md'))) {
        candidates.push(path.join(parent, 'CLAUDE.md'), path.join(parent, '.claude', 'rules', 'pm-profile.md'));
      }
      for (const f of candidates) { if (isFile(f)) { files[path.relative(parent, f).replace(/\\/g, '/')] = clip(readText(f), 20000); } }
      return {
        text: json({
          project: projectId(p), name: p.name, path: p.root,
          schema: { name: wf.name, missing: wf.missing || undefined, language: wf.language || undefined, documents: wf.artifacts.map(x => ({ id: x.id, file: x.generates, requires: x.requires })), tasks: wf.tracks },
          groups: p.config.groups.length ? { label: p.config.groupLabel, list: p.config.groups } : undefined,
          bundles: p.config.bundles.length ? p.config.bundles : undefined,
          'openspec/config.yaml': clip(readText(path.join(p.osDir, 'config.yaml')), 20000),
          ...files,
        }),
      };
    },
  },
  {
    name: 'list_plan', title: 'The plan (changes)', readOnly: true,
    description: 'The changes by group: name, title, stage (Draft, In Progress, Completed), tasks done/total, the capabilities whose requirements they add, modify or remove, their documents, and which documents are out of date.',
    inputSchema: schema({ include_archived: bool('Also the archived changes (default false).') }),
    run: (a) => {
      const p = project(a.project);
      const stale = syncState(p);
      const out = (c: Change) => ({
        change: c.name, title: itemTitle(c), stage: c.stage, tasks: `${c.done}/${c.total}`,
        capabilities: c.caps.map(x => ({ name: x.name, added: x.added, modified: x.modified, removed: x.removed, renamed: x.renamed })),
        documents: c.docs.map(d => ({ id: d.id, files: d.files.map(f => rel(p, f)), missing: d.files.length ? undefined : true })),
        outOfDate: stale.get(c.name)?.map(x => x.doc.id),
        schema: c.workflow.name,
      });
      const groups = p.groups().map(g => ({ group: p.groupTitle(g.id), id: g.id || undefined, tasks: `${g.done}/${g.total}`, changes: g.changes.map(out) }));
      const archived = a.include_archived ? p.changes.filter(c => c.archived).map(c => ({ change: c.name, title: itemTitle(c) })) : undefined;
      return { text: json({ project: projectId(p), groups, archived }) };
    },
  },
  {
    name: 'list_specs', title: 'The specifications', readOnly: true,
    description: 'The main specifications (openspec/specs/): platform pages and capability specs with their purpose and number of requirements and scenarios; with_requirements lists the requirement names too.',
    inputSchema: schema({ with_requirements: bool('Also each spec\'s requirement names (default false).') }),
    run: (a) => {
      const p = project(a.project);
      return {
        text: json(p.specs.map(x => ({
          spec: x.name, title: itemTitle(x), platform: x.platform || undefined, requirements: x.reqs, scenarios: x.scenarioCount,
          purpose: clip(x.purpose, 400) || undefined, path: rel(p, x.path),
          requirementNames: a.with_requirements ? x.requirements.map(r => r.name) : undefined,
        }))),
      };
    },
  },
  {
    name: 'read_document', title: 'Read a document', readOnly: true,
    description: 'A document of the specs or a change, in full: by path (under openspec/), by spec name, or by change (and document id, e.g. proposal, design, tasks, specs; without one: the list of its documents and the proposal).',
    inputSchema: schema({ path: str('A file under openspec/, from the project folder.'), spec: str('A spec\'s name.'), change: str('A change\'s folder name.'), document: str('With change: the document id (proposal, specs, design, tasks, ...).') }),
    run: (a) => {
      const p = project(a.project);
      if (a.path) { const f = readableDoc(p, a.path); return { text: `# ${rel(p, f)}\n\n${readText(f)}` }; }
      if (a.spec) {
        const sp = p.specs.find(x => x.name === s(a.spec) || x.short === s(a.spec));
        if (!sp) { throw new UserError(`No spec "${a.spec}". Specs: ${p.specs.map(x => x.name).join(', ')}.`); }
        return { text: `# ${rel(p, sp.path)}\n\n${readText(sp.path)}` };
      }
      if (a.change) {
        const c = change(p, a.change, true);
        const want = s(a.document).toLowerCase();
        const d = want ? c.docs.find(x => x.id.toLowerCase() === want || x.title.toLowerCase() === want) : c.docs.find(x => x.id === 'proposal') || c.docs.find(x => x.files.length);
        const listing = `Documents of ${c.name}: ${c.docs.map(x => `${x.id}${x.files.length ? '' : ' (not written yet)'}`).join(', ')}.`;
        if (!d) { throw new UserError(`${want ? `No document "${a.document}". ` : ''}${listing}`); }
        if (!d.files.length) { return { text: `${d.id} of ${c.name} is not written yet (${d.generates}). ${listing}` }; }
        return { text: (want ? '' : `${listing}\n\n`) + d.files.map(f => `# ${rel(p, f)}\n\n${readText(f)}`).join('\n\n---\n\n') };
      }
      throw new UserError('Give path, spec, or change.');
    },
  },
  {
    name: 'find', title: 'Find', readOnly: true,
    description: 'Tasks, requirements, scenarios and sections in the specs and changes: by task number (1.3), by words (all must match), g2 / group 2 for one group. Each result has path and line, which edit and remove tools take.',
    inputSchema: schema({
      query: str('Words, a task number, or g<group>.'),
      kind: { type: 'string', enum: ['all', 'tasks', 'open tasks', 'requirements', 'scenarios', 'sections'], description: 'Only this kind (default all).' },
      include_archived: bool('Also archived changes.'), limit: num('At most this many (default 50).'),
    }, ['query']),
    run: (a) => {
      const p = project(a.project);
      const hits = find(p, searchIndex(p, !!a.include_archived), s(a.query), (s(a.kind) || 'all') as FindKind);
      const limit = Number(a.limit) || 50;
      return { text: hits.length ? json({ total: hits.length, shown: Math.min(limit, hits.length), results: hits.slice(0, limit).map(e => entryOut(p, e)) }) : 'Nothing found.' };
    },
  },
  {
    name: 'out_of_date', title: 'Out-of-date documents', readOnly: true,
    description: 'Documents of active changes written before what they are written from changed (e.g. tasks older than the delta specs): which requirement was added, changed or removed. with_text shows each requirement before and now.',
    inputSchema: schema({ change: str('Only this change.'), with_text: bool('Each changed requirement before and now (default false).') }),
    run: (a) => {
      const p = project(a.project);
      const st = syncState(p);
      const list = [...st].filter(([n]) => !a.change || n === change(p, a.change).name).map(([n, docs]) => ({
        change: n,
        documents: docs.map(d => ({
          document: d.doc.id, files: d.doc.files.map(f => rel(p, f)),
          changed: d.diffs.map(x => ({ in: x.file, what: { '+': 'added', '~': 'changed', '-': 'removed' }[x.mark], requirement: x.req || undefined, before: a.with_text ? x.old || undefined : undefined, now: a.with_text ? x.now || undefined : undefined })),
        })),
      }));
      return { text: list.length ? json(list) : 'Everything is in sync.' };
    },
  },
  {
    name: 'mark_in_sync', title: 'Mark as in sync',
    description: 'A change\'s documents marked as in sync with what they are written from, as it is now - after they were updated, or when the change needs no update.',
    inputSchema: schema({ change: str('The change.') }, ['change']),
    run: (a) => { const p = project(a.project); const c = change(p, a.change); setInSync(p, c); return { text: `${c.name}: marked as in sync.` }; },
  },
  {
    name: 'tick_task', title: 'Tick a task',
    description: 'A task of a change ticked as done (or not): by its number (1.3) or words of its text.',
    inputSchema: schema({ change: str('The change.'), task: str('The task number or words of it.'), done: bool('Done (default true) or not.') }, ['change', 'task']),
    run: (a) => {
      const p = project(a.project);
      const c = change(p, a.change);
      const want = s(a.task).trim().replace(/\.$/, '').toLowerCase();
      const all = c.taskGroups.flatMap(g => g.tasks);
      const hits = all.filter(t => t.num === want).length ? all.filter(t => t.num === want) : all.filter(t => t.text.toLowerCase().includes(want));
      if (hits.length !== 1) { throw new UserError(hits.length ? `More than one task matches: ${hits.map(t => t.text).join(' | ')}` : `No task "${a.task}" in ${c.name}.`); }
      const t = hits[0];
      const { text, nl, bom } = readRaw(t.path);
      const lines = text.split('\n');
      lines[t.line - 1] = setTaskDone(lines[t.line - 1], a.done !== false);
      writeRaw(t.path, lines.join('\n'), nl, bom);
      return { text: `${a.done !== false ? 'Done' : 'Not done'}: ${t.text}` };
    },
  },
  {
    name: 'edit_document', title: 'Edit a document', destructive: true,
    description: 'Replace text in a document under openspec/ (exact text, as read_document shows it), or in one of the process\'s files outside it (write_file lists them). A main spec\'s requirements and scenarios (openspec/specs/) are not edited directly: use change_spec_requirement or remove_items, which make a change for it, as OpenSpec wants.',
    inputSchema: schema({ path: str('The file, under openspec/ or one of the process\'s files (write_file).'), old_text: str('The exact text to replace (unique in the file unless replace_all).'), new_text: str('The new text.'), replace_all: bool('Replace every occurrence.') }, ['path', 'old_text', 'new_text']),
    run: (a) => {
      const p = project(a.project);
      const target = path.resolve(p.root, s(a.path)).toLowerCase();
      const under = (dir: string) => target.startsWith(dir.toLowerCase() + path.sep);
      const file = under(p.osDir) && !under(exportDir(p)) ? writable(p, a.path) : writableFile(p, a.path);
      if (!isFile(file)) { throw new UserError(`There's no ${rel(p, file)}; write_document makes new documents.`); }
      const { text, nl, bom } = readRaw(file);
      const oldT = s(a.old_text).replace(/\r\n/g, '\n'), newT = s(a.new_text).replace(/\r\n/g, '\n');
      if (!oldT) { throw new UserError('old_text is empty.'); }
      const n = text.split(oldT).length - 1;
      if (!n) { throw new UserError(`old_text is not in ${rel(p, file)} (it must match exactly; read_document shows the file as it is).`); }
      if (n > 1 && !a.replace_all) { throw new UserError(`old_text is in ${rel(p, file)} ${n} times; give more of it, or replace_all.`); }
      const after = a.replace_all ? text.split(oldT).join(newT) : text.replace(oldT, () => newT);
      if (rel(p, file).startsWith('openspec/specs/') && json(requirementBlocks(text)) !== json(requirementBlocks(after))) {
        throw new UserError('This changes a requirement or scenario of a main spec. Make it through a change: change_spec_requirement (edit) or remove_items (remove).');
      }
      writeRaw(file, after, nl, bom);
      return { text: `${rel(p, file)}: ${a.replace_all ? `${n} replacements` : 'edited'}.` };
    },
  },
  {
    name: 'write_document', title: 'Write a document', destructive: true,
    description: 'Write a whole document of a change (under openspec/changes/<change>/): a new proposal, design, tasks or delta spec (specs/<capability>/spec.md). An existing file is replaced only with overwrite.',
    inputSchema: schema({ path: str('The file, under openspec/changes/.'), content: str('The whole document, Markdown.'), overwrite: bool('Replace the file when it exists.') }, ['path', 'content']),
    run: (a) => {
      const p = project(a.project);
      const file = writable(p, a.path, 'changes');
      if (path.relative(path.join(p.osDir, 'changes'), file).split(path.sep).length < 2) { throw new UserError('A document goes in a change\'s folder: openspec/changes/<change>/...; new_change makes one.'); }
      const exists = isFile(file);
      if (exists && !a.overwrite) { throw new UserError(`${rel(p, file)} exists; read it and use edit_document, or overwrite.`); }
      const old = exists ? readRaw(file) : { nl: '\n', bom: false };
      writeRaw(file, s(a.content).replace(/\n*$/, '\n'), old.nl, old.bom);
      return { text: `${rel(p, file)}: ${exists ? 'replaced' : 'written'}.` };
    },
  },
  {
    name: 'write_file', title: 'Write a process file', destructive: true,
    description: 'Write a whole file the process keeps outside the specs - the same files on every surface: in the export folder (netmedia: exportDir: in openspec/config.yaml, default openspec/exports/) the Markdown, JSON, YAML or CSV sources and data of exports (an offer\'s Markdown, an estimate\'s JSON, a price plan); the team\'s shared knowledge: .claude/offers.yaml, .claude/estimates/, .claude/rules/*-profile.md and *-gotchas.md. An existing file is replaced only with overwrite.',
    inputSchema: schema({ path: str('The file, from the project folder.'), content: str('The whole file.'), overwrite: bool('Replace the file when it exists.') }, ['path', 'content']),
    run: (a) => {
      const p = project(a.project);
      const file = writableFile(p, a.path);
      const exists = isFile(file);
      if (exists && !a.overwrite) { throw new UserError(`${rel(p, file)} exists; read it (read_code) and use edit_document, or overwrite.`); }
      const old = exists ? readRaw(file) : { nl: '\n', bom: false };
      writeRaw(file, s(a.content).replace(/\n*$/, '\n'), old.nl, old.bom);
      return { text: `${rel(p, file)}: ${exists ? 'replaced' : 'written'}.` };
    },
  },
  {
    name: 'list_exports', title: 'List the export folder', readOnly: true,
    description: 'The files in the project\'s export folder (netmedia: exportDir: in openspec/config.yaml, default openspec/exports/): spec exports, estimate workbooks, offers - newest first, with size and date.',
    inputSchema: schema({ pattern: str('Only names that contain this text (e.g. .xlsx).') }),
    run: (a) => {
      const p = project(a.project);
      const dir = exportDir(p);
      const want = s(a.pattern).toLowerCase();
      const out: { file: string; size: number; modified: string }[] = [];
      const walk = (d: string, depth: number) => {
        let entries: fs.Dirent[] = [];
        try { entries = fs.readdirSync(d, { withFileTypes: true }); } catch { return; }
        for (const e of entries) {
          const f = path.join(d, e.name);
          if (e.isDirectory()) { if (depth < 3) { walk(f, depth + 1); } continue; }
          if (want && !e.name.toLowerCase().includes(want)) { continue; }
          const st = fs.statSync(f);
          out.push({ file: rel(p, f), size: st.size, modified: st.mtime.toISOString().slice(0, 16).replace('T', ' ') });
        }
      };
      walk(dir, 0);
      out.sort((x, y) => y.modified.localeCompare(x.modified));
      return { text: out.length ? json({ folder: rel(p, dir), files: out }) : `Nothing in ${rel(p, dir)}/${want ? ` matching "${want}"` : ''}.` };
    },
  },
  {
    name: 'run_tool', title: 'Run a Netmedia tool', destructive: true,
    description: `Run one of the Netmedia plugins' tools in the project folder - the same script Claude Code runs, so every surface gives the same result: ${Object.entries(NETMEDIA_TOOLS).map(([n, t]) => `${n} (${t.what})`).join('; ')}. args are the script's own arguments, as its skill writes them (paths from the project folder; they must stay inside the project). Python tools need the Netmedia Python environment (about shows it).`,
    inputSchema: schema({
      tool: { type: 'string', enum: Object.keys(NETMEDIA_TOOLS), description: 'The tool.' },
      args: { type: 'array', items: { type: 'string' }, description: 'The script\'s arguments, one per item.' },
    }, ['tool']),
    run: (a) => {
      const p = project(a.project);
      const name = s(a.tool);
      const t = NETMEDIA_TOOLS[name];
      if (!t) { throw new UserError(`tool: one of ${Object.keys(NETMEDIA_TOOLS).join(', ')}.`); }
      const args = Array.isArray(a.args) ? (a.args as unknown[]).map(x => s(x)) : [];
      checkToolArgs(p, args);
      const { file, from } = netmediaScript(name);
      if (!file) { return { text: `The ${t.plugin} plugin's ${t.script} was not found (installed plugin or LazySpec's bundled copy).`, isError: true }; }
      let r;
      if (t.runtime === 'python') {
        const py = python();
        r = run(py.cmd, [...py.pre, file, ...args], p.root, 600000);
        if (r.missing) { return { text: 'Python is not there. Netmedia setup: Python 3.12 and ~/.netmedia/python with python-docx, openpyxl, pyyaml and pillow (the team onboarding).', isError: true }; }
      } else {
        r = run(process.execPath, [file, ...args], p.root, 600000);
      }
      const text = clip(`${r.out}\n${r.err}`.trim() || (r.code ? 'Failed.' : 'Done.'), 30000);
      return { text: `[${name} from ${from}]\n${text}`, isError: r.code !== 0 };
    },
  },
  {
    name: 'remove_items', title: 'Remove items', destructive: true,
    description: 'Remove tasks, requirements, scenarios or sections (path and line from find). In a change they are taken out; a main spec\'s requirements and scenarios get a new change that removes them (REMOVED / MODIFIED), applied when it is archived.',
    inputSchema: schema({ items: { type: 'array', items: { type: 'object', properties: { path: { type: 'string' }, line: { type: 'integer' } }, required: ['path', 'line'] }, description: 'The items, as find returns them.' } }, ['items']),
    run: (a) => {
      const p = project(a.project);
      const { found, missing } = entriesAt(p, a.items);
      if (!found.length) { throw new UserError(`None of these is there (run find again; lines move): ${missing.join(', ')}`); }
      const report = removeEntries(p, found);
      return { text: [...report, ...missing.map(m => `! not found: ${m}`)].join('\n') };
    },
  },
  {
    name: 'change_spec_requirement', title: 'Change a spec requirement', destructive: true,
    description: 'Edit a main spec\'s requirement (or one of its scenarios) the OpenSpec way: a new change with the whole requirement, as edited, under MODIFIED Requirements, plus a proposal and a task. new_text is the item\'s new Markdown (from its ### / #### heading); without it the change carries it as it is, to edit there.',
    inputSchema: schema({ path: str('The spec, from find.'), line: num('The requirement\'s or scenario\'s line, from find.'), new_text: str('The item\'s new text, its heading included.') }, ['path', 'line']),
    run: (a) => {
      const p = project(a.project);
      const { found } = entriesAt(p, [{ path: a.path, line: a.line }]);
      const e = found[0];
      if (!e || e.item.type !== 'spec' || (e.kind !== 'req' && e.kind !== 'scn')) { throw new UserError('That is not a requirement or scenario of a main spec (find gives path and line).'); }
      const edited = a.new_text ? s(a.new_text).replace(/\r\n/g, '\n').replace(/\n+$/, '').split('\n') : undefined;
      const r = newModifyChange(p, e, edited);
      return { text: `New change ${r.name}: ${rel(p, r.file)} carries the requirement under MODIFIED; its proposal and tasks are written. Archiving the change applies it to the spec.` };
    },
  },
  {
    name: 'new_change', title: 'New change', destructive: true,
    description: 'A new change folder (openspec/changes/<name>/) with the project\'s schema, through the OpenSpec CLI when it is there. Then write its documents with write_document; instructions gives each document\'s template.',
    inputSchema: schema({ name: str('kebab-case, e.g. add-invoice-export.'), schema: str('The workflow schema (default: the project\'s, from config.yaml), e.g. tiny for a small change.'), group: str('The group id, when the project groups changes.') }, ['name']),
    run: (a) => {
      const p = project(a.project);
      const name = slug(s(a.name));
      if (!name) { throw new UserError('name is required.'); }
      const dir = path.join(p.osDir, 'changes', name);
      if (fs.existsSync(dir)) { throw new UserError(`openspec/changes/${name} exists.`); }
      const wanted = s(a.schema).trim() || p.config.schema || 'spec-driven';
      if (!/^[\w.-]+$/.test(wanted)) { throw new UserError(`Not a schema name: ${wanted}.`); }
      const r = openspec(p, ['new', 'change', name, '--schema', wanted]);
      if (!fs.existsSync(dir)) {
        writeRaw(path.join(dir, '.openspec.yaml'), `schema: ${wanted}\ncreated: ${today()}\n`);
      }
      const made = new Project(p.root).load().changes.find(x => x.name === name);
      if (made?.workflow.missing) { fs.rmSync(dir, { recursive: true, force: true }); throw new UserError(`There's no schema "${wanted}" (openspec/schemas/ or the CLI's).`); }
      if (a.group) {
        const meta = path.join(dir, '.openspec.yaml');
        const t = readText(meta);
        if (!/^x-group:/m.test(t)) { writeRaw(meta, `${t.replace(/\n*$/, '\n')}x-group: ${slug(s(a.group)) || s(a.group)}\n`); }
      }
      const c = new Project(p.root).load().changes.find(x => x.name === name);
      return { text: `openspec/changes/${name}/ made${r.missing ? ' (without the OpenSpec CLI)' : ''}. Its documents (${c?.workflow.name}): ${c?.docs.map(d => `${d.id} → ${d.generates}${d.requires.length ? ` (after ${d.requires.join(', ')})` : ''}`).join('; ')}.` };
    },
  },
  {
    name: 'instructions', title: 'Document instructions', readOnly: true,
    description: 'The OpenSpec CLI\'s instructions and template for a document of a change (openspec instructions <document> --change <change>): what goes in it, by the project\'s schema.',
    inputSchema: schema({ change: str('The change.'), document: str('The document id: proposal, specs, design, tasks, ...') }, ['change', 'document']),
    run: (a) => {
      const p = project(a.project);
      const c = change(p, a.change);
      const r = openspec(p, ['instructions', slug(s(a.document)) || s(a.document), '--change', c.name]);
      if (r.missing) { return { text: r.err, isError: true }; }
      return { text: clip((r.out + (r.code ? `\n${r.err}` : '')).trim(), 40000), isError: r.code !== 0 };
    },
  },
  {
    name: 'validate', title: 'Validate', readOnly: true,
    description: 'The OpenSpec CLI\'s strict validation of one change, or of everything: what it reports.',
    inputSchema: schema({ change: str('One change; without it, everything.') }),
    run: (a) => {
      const p = project(a.project);
      const args = a.change ? ['validate', change(p, a.change).name, '--strict', '--no-interactive'] : ['validate', '--all', '--strict', '--no-interactive'];
      const r = openspec(p, args);
      if (r.missing) { return { text: r.err, isError: true }; }
      return { text: clip(`${r.out}\n${r.err}`.trim() || (r.code ? 'Validation failed.' : 'Valid.'), 40000), isError: r.code !== 0 };
    },
  },
  {
    name: 'archive_change', title: 'Archive a change', destructive: true,
    description: 'Archive a finished change (openspec archive): its delta specs applied to the main specs, the folder moved to changes/archive/. Usually done after the work is merged; ask before doing it.',
    inputSchema: schema({ change: str('The change.') }, ['change']),
    run: (a) => {
      const p = project(a.project);
      const r = openspec(p, ['archive', change(p, a.change).name, '--yes']);
      if (r.missing) { return { text: r.err, isError: true }; }
      return { text: `${r.out}\n${r.err}`.trim(), isError: r.code !== 0 };
    },
  },
  {
    name: 'undo_list', title: 'What changed', readOnly: true,
    description: 'Every file changed in openspec/ since the last git commit, with its pieces (numbered), to undo with undo.',
    inputSchema: schema({}),
    run: (a) => {
      const p = project(a.project);
      const rows = undoRows(p.root);
      if (!rows) { return { text: 'This project is not in git: nothing to undo against.', isError: true }; }
      if (!rows.length) { return { text: 'Nothing changed in openspec/ since the last commit.' }; }
      return {
        text: json(rows.map(f => ({
          file: f.rel, kind: f.kind,
          pieces: f.hunks.map((h, i) => {
            const minus = h.lines.filter(l => l.startsWith('-')).length, plus = h.lines.filter(l => l.startsWith('+')).length;
            const first = h.lines.find(l => (l[0] === '-' || l[0] === '+') && l.slice(1).trim());
            return { piece: i + 1, removed: minus, added: plus, first: first ? first.slice(0, 120) : '' };
          }),
        }))),
      };
    },
  },
  {
    name: 'undo', title: 'Undo', destructive: true,
    description: 'Undo a piece of a changed file (piece from undo_list), or the whole file (back as committed; a new file deleted).',
    inputSchema: schema({ file: str('The file, from undo_list.'), piece: num('The piece number; without it, the whole file.') }, ['file']),
    run: (a) => {
      const p = project(a.project);
      const rows = undoRows(p.root) || [];
      const f = rows.find(x => x.rel === s(a.file).replace(/\\/g, '/'));
      if (!f) { throw new UserError(`${a.file} has no changes since the last commit (undo_list).`); }
      if (a.piece) {
        const h = f.hunks[Number(a.piece) - 1];
        if (!h) { throw new UserError(`${f.rel} has ${f.hunks.length} piece(s).`); }
        undoHunk(p.root, h);
        return { text: `${f.rel}: piece ${a.piece} undone.` };
      }
      undoFile(p.root, f);
      return { text: f.kind === 'new' ? `${f.rel}: deleted (it was new).` : `${f.rel}: back as committed.` };
    },
  },
  {
    name: 'search_code', title: 'Search the code', readOnly: true,
    description: 'Search the project\'s files (code, docs, config; git-tracked and new, not ignored ones) for text: file, line and the line itself. Read-only, to investigate what the system does today.',
    inputSchema: schema({ query: str('The text (or a regular expression with regex).'), regex: bool('query is a regular expression.'), glob: str('Only files matching, e.g. *.cs or src/**.'), case_sensitive: bool('Match case (default no).'), limit: num('At most this many lines (default 100).') }, ['query']),
    run: (a) => {
      const p = project(a.project);
      const limit = Number(a.limit) || 100;
      const args = ['grep', '-n', '-I', '--untracked', '--no-color', a.regex ? '-E' : '-F'];
      if (!a.case_sensitive) { args.push('-i'); }
      args.push('-e', s(a.query), '--', a.glob ? s(a.glob) : '.');
      const r = git(p, args);
      if (r.code > 1) { return { text: `git grep failed: ${r.err}`, isError: true }; }
      const lines = r.out.replace(/\r/g, '').split('\n').filter(l => l && !/^(\.env|.*\.(pem|key|pfx))/i.test(l));
      if (!lines.length) { return { text: 'Nothing found.' }; }
      const shown = lines.slice(0, limit).map(l => l.length > 240 ? `${l.slice(0, 240)}…` : l);
      return { text: `${lines.length} line(s)${lines.length > limit ? `, the first ${limit}` : ''}:\n${shown.join('\n')}` };
    },
  },
  {
    name: 'read_code', title: 'Read a file', readOnly: true,
    description: 'Read any file of the project (code, config, docs) with line numbers; files that may hold secrets are not read.',
    inputSchema: schema({ path: str('The file, from the project folder.'), offset: num('The first line (default 1).'), limit: num('How many lines (default 400).') }, ['path']),
    run: (a) => {
      const p = project(a.project);
      const file = readableCode(p, a.path);
      const buf = fs.readFileSync(file);
      if (buf.subarray(0, 8000).includes(0)) { return { text: `${rel(p, file)} is a binary file.`, isError: true }; }
      const lines = buf.toString('utf8').replace(/^﻿/, '').replace(/\r/g, '').split('\n');
      const from = Math.max(1, Number(a.offset) || 1), n = Number(a.limit) || 400;
      const part = lines.slice(from - 1, from - 1 + n).map((l, i) => `${String(from + i).padStart(5)}  ${l}`);
      return { text: `# ${rel(p, file)} (lines ${from}-${from + part.length - 1} of ${lines.length})\n${part.join('\n')}` };
    },
  },
  {
    name: 'git_status', title: 'Git status', readOnly: true,
    description: 'The project\'s branch, how far it is from its remote, and what is changed (openspec/ and the rest).',
    inputSchema: schema({}),
    run: (a) => {
      const p = project(a.project);
      git(p, ['fetch', '--quiet'], 30000);
      const r = git(p, ['status', '-sb', '--untracked-files=all']);
      if (r.code) { return { text: `Not a git repository, or git is not there: ${r.err}`, isError: true }; }
      const [head, ...files] = r.out.replace(/\r/g, '').split('\n').filter(Boolean);
      const spec = files.filter(f => /\sopenspec\//.test(f) || / "?openspec\//.test(f));
      return { text: json({ branch: head.replace(/^## /, ''), openspecChanges: spec, otherChanges: files.length - spec.length }) };
    },
  },
  {
    name: 'get_latest', title: 'Get the latest',
    description: 'Bring the project up to date with its remote (git pull --ff-only): before starting work.',
    inputSchema: schema({}),
    run: (a) => {
      const p = project(a.project);
      const r = git(p, ['pull', '--ff-only'], 120000);
      return { text: `${r.out}\n${r.err}`.trim() || (r.code ? 'git pull failed.' : 'Up to date.'), isError: r.code !== 0 };
    },
  },
  {
    name: 'save', title: 'Save as a pull request', destructive: true,
    description: 'Save the work: commit what changed in openspec/ and the team\'s shared knowledge (.claude/offers.yaml, .claude/estimates/, .claude/rules/) - never the export folder or code - on a branch of its own (a new spec/<name> branch when on the main branch), push it, and open a pull request with GitHub CLI when it is there (else the link to open one). Tell the user what will be committed first.',
    inputSchema: schema({ message: str('The commit message: what changed and why, one line.'), branch: str('The branch name (default spec/<message>-<date>).'), body: str('The pull request\'s description (Markdown).'), pull_request: bool('Open a pull request (default true).') }, ['message']),
    run: (a) => {
      const p = project(a.project);
      const msg = s(a.message).trim();
      if (!msg) { throw new UserError('message is required.'); }
      const steps: string[] = [];
      const must = (r: ReturnType<typeof git>, what: string) => { if (r.code) { throw new UserError(`${steps.join('\n')}\n✗ ${what}: ${(r.err || r.out).trim()}`); } return r.out.trim(); };
      let cur = must(git(p, ['rev-parse', '--abbrev-ref', 'HEAD']), 'git');
      const remoteHead = git(p, ['symbolic-ref', '--short', 'refs/remotes/origin/HEAD']).out.trim().replace(/^origin\//, '');
      const base = remoteHead || ['develop', 'main', 'master'].find(b => git(p, ['rev-parse', '--verify', '--quiet', b]).code === 0) || 'main';
      if (cur === base || cur === 'HEAD' || ['main', 'master', 'develop'].includes(cur)) {
        const name = s(a.branch).trim() || `spec/${slug(msg).slice(0, 40).replace(/-+$/, '')}-${today('')}`;
        must(git(p, ['switch', '-c', name]), `new branch ${name}`);
        steps.push(`✓ new branch ${name} (from ${cur})`);
        cur = name;
      } else { steps.push(`✓ on branch ${cur}`); }
      const knowledge = KNOWLEDGE_PATHS.filter(k => fs.existsSync(path.join(p.root, k)));
      const exportsAt = rel(p, exportDir(p));
      must(git(p, ['add', '-A', '--', 'openspec', ...knowledge, ':(exclude)openspec/exports', `:(exclude)${exportsAt}`]), 'git add');
      const staged = git(p, ['diff', '--cached', '--name-only', '--', 'openspec', ...knowledge]).out.trim();
      if (!staged) { return { text: `${steps.join('\n')}\nNothing changed in openspec/ or the shared knowledge to save.` }; }
      must(git(p, ['commit', '-m', msg, '--', 'openspec', ...knowledge]), 'git commit');
      steps.push(`✓ committed ${staged.split('\n').length} file(s): ${msg}`);
      must(git(p, ['push', '-u', 'origin', cur], 120000), 'git push');
      steps.push(`✓ pushed to origin/${cur}`);
      if (a.pull_request === false) { return { text: steps.join('\n') }; }
      const remote = git(p, ['remote', 'get-url', 'origin']).out.trim();
      const web = remote.replace(/^git@([^:]+):/, 'https://$1/').replace(/\.git$/, '');
      if (onPath('gh')) {
        const existing = run('gh', ['pr', 'view', cur, '--json', 'url', '-q', '.url'], p.root);
        if (!existing.code && existing.out.trim()) { steps.push(`✓ the pull request is updated: ${existing.out.trim()}`); return { text: steps.join('\n') }; }
        const body = s(a.body) || `${msg}\n\nSpec changes (openspec/) saved from Claude with LazySpec.`;
        const pr = run('gh', ['pr', 'create', '--base', base, '--head', cur, '--title', msg, '--body', body], p.root, 60000);
        if (!pr.code) { steps.push(`✓ pull request: ${pr.out.trim().split('\n').pop()}`); return { text: steps.join('\n') }; }
        steps.push(`! gh could not open the pull request (${pr.err.trim().split('\n')[0]})`);
      }
      if (/^https:\/\//.test(web)) { steps.push(`→ open the pull request: ${web}/compare/${base}...${encodeURIComponent(cur).replace(/%2F/g, '/')}?expand=1`); }
      return { text: steps.join('\n') };
    },
  },
  {
    name: 'export_document', title: 'Export for the client',
    description: 'A document for the client in the company look (PDF, Word or HTML) into the export folder (netmedia: exportDir: in openspec/config.yaml, default openspec/exports/): the whole specification (optionally with the plan), one spec or change (item), a saved bundle (item), or groups. Uses LazySpec\'s exporter (PowerShell; Edge or Chrome for PDF).',
    inputSchema: schema({
      format: { type: 'string', enum: ['pdf', 'word', 'html'], description: 'The format.' },
      item: str('A spec, a change or a saved bundle (its name); without it, the whole specification.'),
      groups: { type: 'array', items: { type: 'string' }, description: 'Instead of item: these groups\' changes as one document.' },
      include_changes: bool('With the whole specification: the active changes after it.'),
      client_friendly: bool('Scenarios as sentences, for the client (default true); false: technical, as written.'),
      language: str('Translate into this language (e.g. hr, de, en), when the project is set up for it.'),
    }, ['format']),
    run: (a) => {
      const p = project(a.project);
      const script = kitScript(p);
      if (!script) { return { text: 'LazySpec\'s exporter (lazyspec.ps1) is not there.', isError: true }; }
      const fmt = ({ pdf: 'Pdf', word: 'Word', html: 'Html' } as Record<string, string>)[s(a.format).toLowerCase()];
      if (!fmt) { throw new UserError('format: pdf, word or html.'); }
      const args = ['-NoProfile', ...(process.platform === 'win32' ? ['-ExecutionPolicy', 'Bypass'] : []), '-File', script, '-Root', p.root, '-Export', fmt];
      if (a.client_friendly !== false) { args.push('-ClientFriendly'); }
      if (a.language) { args.push('-Language', s(a.language)); }
      if (Array.isArray(a.groups) && a.groups.length) { args.push('-Groups', (a.groups as string[]).join(',')); }
      else if (a.item) { args.push('-Item', s(a.item)); }
      else if (a.include_changes) { args.push('-IncludeChanges'); }
      const r = run(powershell(), args, p.root, 300000);
      if (r.missing) { return { text: `PowerShell is not there (${powershell()}); on macOS: brew install powershell.`, isError: true }; }
      const written = /Written:\s*(.+?)\s*$/m.exec(r.out + r.err);
      if (!r.code && written) { return { text: `Written: ${written[1]}` }; }
      return { text: clip(`The export failed.\n${r.out}\n${r.err}`.trim(), 8000), isError: true };
    },
  },
];


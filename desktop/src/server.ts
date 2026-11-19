// LazySpec for Claude: a project's OpenSpec specs and changes as MCP tools (Claude Desktop as a .mcpb extension,
// Claude Code as a plugin). The project's folders: the arguments, LAZYSPEC_PROJECTS, else the current folder.

import { Prompt, serve } from './mcp';
import { tools, VERSION } from './tools';

const instructions = `LazySpec works on OpenSpec projects: openspec/specs/ (the main specifications: what the system does) and openspec/changes/ (proposed changes: proposal, delta specs, design, tasks).
- Start with list_projects / list_plan / list_specs; project_context says how the project is run - read it before writing.
- Read documents with read_document; find items with find (path + line).
- Change a change's documents with edit_document / write_document. A main spec's requirements are never edited in place: change_spec_requirement or remove_items make a change for it.
- After edits: out_of_date and validate. Show the user what you changed.
- search_code / read_code are read-only, to check what the system does today; cite files and lines.
- save commits openspec/ only, on a branch, and opens a pull request; get_latest first when starting. Tell the user before save, archive_change and undo.`;

const prompts: Prompt[] = [
  {
    name: 'refine', title: 'Refine a change',
    description: 'Tighten a change: testable requirements and scenarios, proposal, specs and tasks consistent, validated.',
    arguments: [{ name: 'change', description: 'The change (folder name).', required: true }, { name: 'project', description: 'The project, when there are several.' }],
    text: a => `Refine the OpenSpec change "${a.change}"${a.project ? ` in the project ${a.project}` : ''} with the LazySpec tools.
1. project_context, then read_document for each of its documents (proposal, delta specs, design, tasks).
2. Check: every requirement is one testable behaviour with SHALL/MUST; every scenario has WHEN/THEN and tests one thing; the proposal's Why and What Changes match the delta specs; the tasks cover every requirement; nothing contradicts the main specs (find, read_document).
3. Show me the problems and the edits you propose, grouped by document. Wait for my go.
4. Make the edits (edit_document), then out_of_date and validate, and fix what they report.`,
  },
  {
    name: 'clarify', title: 'Clarify a change',
    description: 'Find ambiguities, gaps and contradictions in a change and write them down as open questions.',
    arguments: [{ name: 'change', description: 'The change (folder name).', required: true }, { name: 'project', description: 'The project, when there are several.' }],
    text: a => `Clarify the OpenSpec change "${a.change}"${a.project ? ` in the project ${a.project}` : ''} with the LazySpec tools.
1. Read its documents (read_document) and the main specs it touches; check what the code does today where it matters (search_code, read_code).
2. List what is ambiguous, missing, contradictory or assumed: each as a question, why it matters, and who should answer (client, PM, developer).
3. Show me the list. When I agree, add it to the proposal as a "## Open questions" section (edit_document), numbered; questions for the client in the client's language.`,
  },
  {
    name: 'investigate', title: 'Investigate',
    description: 'Answer a question from the specs and the code, read-only, with sources.',
    arguments: [{ name: 'question', description: 'What you want to know.', required: true }, { name: 'project', description: 'The project, when there are several.' }],
    text: a => `Investigate${a.project ? ` in the project ${a.project}` : ''}: ${a.question}
Use the LazySpec tools read-only: list_specs, find, read_document for what the specs say; list_plan for what is planned; search_code and read_code for what the code does today.
Answer plainly, and give every claim its source (file and line). Say what the specs and the code disagree on, and what you could not find out.`,
  },
];

serve({ name: 'lazyspec', version: VERSION, instructions }, tools, prompts);

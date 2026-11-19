# Changelog

## 0.3.0

- Sync Out-of-Date Documents, update them: the agent done, the change marked as in sync by itself (background:
  exit code 0 and openspec validate passes; here: Claude Code as the terminal itself, asked when it ends; a
  saved prompt done outside: offered), against what the agent was given (<prompt>.sync.json, the same as
  LazySpec's): a document it left unchanged is in sync, a spec edited meanwhile still shows.

## 0.2.1

- The built-in LazySpec (export, the terminal UI): after the agent brings a change's documents up to date,
  it marks the change as in sync by itself (background: exit code 0 and validated; here: asked).

## 0.2.0

Everything LazySpec's terminal UI does, on the same files:

- Read: a change, spec, group or changes as one, formatted, a tab per document; its tasks, requirements,
  scenarios and sections selectable (Ctrl/Cmd: several): edit, done, delete, the agent; Source.
- Items in the trees: a document's sections, a spec's sections; several selected; edit (F2; a task's text in
  place; a main spec through a MODIFIED change), done (Space), delete (Delete; the main specs through a
  REMOVED / MODIFIED change), the agent (change it, write it again).
- The agent (Claude Code): here, in the background (answer it after), or the prompt saved; remembered.
- Out of date: ! in the plan, what changed in the details, update (the agent) or mark in sync; the same
  .lazyspec/sync.json as LazySpec.
- Undo: the changes since the last commit by file and piece, their diffs, undone piece by piece.
- Find: buttons per result (read, edit, done, agent, delete), by document, several at once.
- Changes as one (saved wholes in config.yaml: read, save, remove), groups as one, export in another language,
  sort, help; documents open formatted or as source (lazyspec.documents).

## 0.1.2

- A folder without `openspec/` at its top: the projects up to three levels below it (a monorepo,
  `apps/portal`, `examples/acme-portal`), each its own part of the Plan and the Scope.

## 0.1.1

- Opening a folder with an openspec folder (`code .` there) shows LazySpec's sidebar, the Plan's first item
  selected and its details shown (`lazyspec.openOnStartup`: false to keep the Explorer).

## 0.1.0

- The Plan (by group, or flat) and the Scope as trees: changes with their documents, tasks with checkboxes,
  delta specs down to scenarios; specs with their requirements and scenarios.
- Details of the selected change, group or spec.
- Find: task numbers, words, a kind, one group.
- Validate, new change and archive through the OpenSpec CLI.
- Export for the client (PDF, Word, HTML): the specification, a change, chosen changes, groups, saved bundles,
  any Markdown file; through LazySpec's lazyspec.ps1 (the project's or the one built in).
- LazySpec's terminal UI in an editor tab.

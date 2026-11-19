# Changelog

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

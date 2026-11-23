# Changelog

## 0.7.0

- **Word and PDF exports are Netmedia documents**, made by the `netmedia-document` generator as every Netmedia
  document: the Netmedia cover (the logo, the title, subtitle, date and the cover's lines), the table of contents
  in the export's language, the template's styles, header and footer. The installed `netmedia-document` plugin
  is used (the latest Netmedia template), else LazySpec's own copy in `tools/lazyspec/netmedia-document/`
  (`tools/update-netmedia-document.ps1` refreshes it). Needs Python 3.10+ with `python-docx`; PDF: Microsoft
  Word exports the Word document. A project's own copy of the template: `documentTemplate:` / `-Template`.
- The document theme (`documentTheme:` / `-Theme`) is HTML's look only; LazySpec's own Word and PDF engines
  (and pandoc) are gone.
- LazySpec's documents (`docs/`) are built like every Netmedia repository's: `docs/documents.json` and
  `docs/build-documents.ps1`; the demo project's exports with `docs/build-examples.ps1`.

## 0.6.1

- Tab / Shift+Tab: the next / previous pane - the Scope, the Plan, Undo, the Details, as in the terminal UI; the
  side bar's views in that order.

## 0.6.0

- The same letters as LazySpec in the terminal: Ctrl+Alt+R refresh (was Read), Ctrl+Alt+Enter Read, Ctrl+Alt+Y
  out of date (the change selected); T, U, A, P, S, D, H as before. The terminal UI took them over: p / s / d
  the plan, the scope, the details, h back to the document, A (Shift) archive, o sort, . archived.

## 0.5.3

- The panes without a chord, the same letters everywhere: Ctrl+Alt+P / S / D / U / H (Plan, Scope, Details, Undo,
  here: the document); on a Mac Control+Option (⌃⌥) and the same letters - also for find (T), Read (R), the agent (A).

## 0.5.2

- The agent in the background, visible: a spinner in the status bar (what, how long, its last step; a click:
  its output), the changes it updates spinning in the Plan (updating...), its steps in the output as they
  happen (Claude Code's stream); Show Claude Code's Output and Stop Claude Code in the Plan's menu.

## 0.5.1

- Help and Keys (the ? in the Plan's title bar, the LazySpec menu of a document): every key, Windows / Linux and
  Mac side by side (this computer's marked), Find's filters, the formatted editor; a link to change them.

## 0.5.0

- Find: each result's document (TASKS, DESIGN ...) and kind on a small line of its own; in:<document> and
  is:<kind> typed with the words (in:design, in:open, is:task, is:req ...).
- A document opened from LazySpec (find, the trees, Details) is focused, the cursor at the item: the
  keyboard scrolls it right away.
- The panes: Ctrl+; then P (Plan), S (Scope), D (Details), U (Undo), E (the document); Mac Cmd+;.

## 0.4.2

- A document's link without an item (Details' documents and capabilities) opened the Markdown source: now
  the formatted editor too.

## 0.4.1

- Everything formatted: tasks, task groups, requirements, scenarios, sections, find results and Details links
  open their document in the formatted editor, scrolled to the item and marked.
- openspec's Markdown opens formatted wherever it is opened from (lazyspec.openMarkdownFormatted, on by
  default: workbench.editorAssociations); Source still opens the Markdown.

## 0.4.0

- A formatted editor (Milkdown): Edit opens the item alone, formatted, with Save / Cancel; documents open in it
  too. A bar for headings, bold, italic, strikethrough, code, lists, task lists, links, tables, code blocks,
  quotes, rules; Markdown shortcuts. Only the lines you edit change in the file; the rest stays byte for byte.
- The title bar of any Markdown file: Formatted, and a LazySpec menu (formatted editor, source, preview, Read,
  export as a document).
- Refresh in Read and in Details (the views' title bars had it).

## 0.3.1

- Sync All Out-of-Date Changes... (the Plan's title bar, the status bar's count), and Sync on several selected
  changes: one agent run for all of them (each validated and marked after), or all marked as in sync.

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

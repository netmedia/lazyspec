# LazySpec for VS Code

A project's [OpenSpec](https://github.com/Fission-AI/OpenSpec) in the editor you already use: VS Code, Cursor,
Windsurf or any other editor built on VS Code. It does what [LazySpec](https://github.com/netmedia/lazyspec)
does in the terminal, and works on the same files, so you can switch between the two at any time:

- the specifications and the plan (by group), formatted or as Markdown
- tasks, requirements, scenarios and sections to edit, tick, delete or hand to the agent
- find, out-of-date documents, undo
- validate, new change, archive
- exports for the client in the company look

By [Netmedia](https://netmedia.agency).

## The sidebar

The checklist icon in the activity bar opens it. Opening a folder with `openspec/` (`code .` there) opens it
by itself.

- **Plan**: the active changes, with their stage and tasks done.
  - In a project with groups (phases, modules) the plan is **by group**: a row per group, its changes and
    task progress under it.
  - A change whose documents are **out of date** gets `!` and a warning icon.
  - Under a change are its documents in its workflow's order (proposal, specs, design, tasks ...); the
    missing ones say *not yet*.
  - Under a document are its **sections** (`## Why`, `### ADR-001` ...).
  - Under **Tasks** are the tasks with checkboxes.
  - Under **Specs** are the capabilities, their requirements and scenarios.
- **Scope**: the specifications, each with its sections, requirements and scenarios.
- **Details**: the selected change, spec or group.
  - A change: its progress, tasks by group, capabilities, why and documents. When it is out of date: which
    documents and what changed, with *Update them* and *Mark as in sync*.
  - A group: its description, what it requires and what requires it, its changes, capabilities and
    dependencies on other groups.
- **Undo (since the last commit)**: every change to `openspec/` since the last git commit (yours, LazySpec's
  or the agent's), by file and by piece.
  - Click a piece to see its diff.
  - The discard button undoes it. On a file it puts the whole file back as committed, or deletes a new file.
- **Status bar**: the tasks done, and how many changes are out of date.

## Editing formatted

Markdown is edited as formatted text, like a word processor: no `**` or `#` to type, unless you want to.

- **Edit** on a task, requirement, scenario or section (`F2`, the pencil, Read's **Edit**) opens it alone in
  the **formatted editor**. Its bar has **Save** (`Ctrl+S`), **Cancel** and **Edit in the File** (the Markdown
  with its lines selected). A main spec's requirement or scenario is saved through a new change
  (`MODIFIED`), or directly, as you choose.
- A **document** clicked in the Plan or the Scope opens in the formatted editor too; save it with `Ctrl+S`.
- So does **everything in it**: a task, task group, requirement, scenario or section clicked in the trees, a
  find result, a link in Details. Its document opens formatted, scrolled to it, and the item is marked for a
  moment.
- **Wherever openspec's Markdown is opened from** (the Explorer, `Ctrl+P`, a link), it opens formatted:
  LazySpec sets `workbench.editorAssociations` for `**/openspec/**/*.md` in your user settings. Turn
  `lazyspec.openMarkdownFormatted` off to take that out again.
- The **formatting bar** on top has a heading level (H1-H6, text), bold, italic, strikethrough, inline code,
  bullet, numbered and task lists, link, table, code block, quote and a rule. Selected text gets a small bar
  too. Markdown shortcuts work as you type: `**bold**`, `# ` for a heading, `- [ ] ` for a task.
- **Only what you edit changes in the file.** The editor writes Markdown its own way (a blank line after a
  heading, padded tables), so LazySpec writes back only the lines you changed; everything else stays as it
  was, byte for byte. A document you open and don't edit is never rewritten.
- **The buttons in the title bar** of any open Markdown file: **Formatted** (the pencil) opens it in the
  formatted editor, and the **LazySpec** menu next to it switches between Formatted Editor, Source and
  Preview, opens it in LazySpec's Read, or exports it as a document.
- `lazyspec.documents` (`formatted`, `preview`, `source`) says how a clicked document opens;
  `lazyspec.editor` (`formatted`, `source`) says how Edit opens an item.

## Refresh

LazySpec picks up changes to the files by itself: an editor, git or the agent. To read everything again
anyway, use **⟳** in the Plan's, Scope's or Undo's title bar, or **Refresh** in Read and in Details. Refresh
also checks again which documents are out of date.

## Reading: formatted or the source

- **Read** (the book button on a change, spec or group, or `Ctrl+Alt+R` / `Cmd+Alt+R`) opens a formatted view
  with a tab per document. For several changes or groups as one, it has a tab per kind of document, with each
  change's part under its title.
  - Click a task, requirement, scenario or section to select it; `Ctrl`/`Cmd`-click selects several.
  - Then **Edit**, **Done / not**, **Delete**, or **Agent...**. Keys: `Enter`, `Space`, `Delete`, `A`;
    `↑` `↓` move, `Esc` clears.
  - Double-click edits. Tasks have checkboxes. **Source** opens the Markdown itself.
- A **document** clicked in the trees opens formatted (the Markdown preview) or as its source, as
  `lazyspec.documents` says. Right-click for the other one.
- A **task, requirement, scenario or section** clicked opens its file at its line.

## Items: edit, tick, delete, the agent

Right-click an item in the Plan or the Scope (several: `Ctrl`/`Shift`-click), use the buttons on its row, or
use the keys.

| | Keys | |
|---|---|---|
| Edit | `F2` | The item alone in the formatted editor (Save, Cancel); **Edit in the File** for its Markdown. A requirement or scenario of the **main specs**: through a new change (`MODIFIED`, archive it to apply it), or directly. |
| Done / not | `Space`, or its checkbox | Writes `[x]` / `[ ]` into the tasks file. |
| Delete | `Delete` (Mac `Cmd+Backspace`) | Asked first. In a change's documents, it is taken out; a delta spec left empty is deleted. From the main specs, a new change `remove-from-specs-<date>` gets `REMOVED` (a requirement) or `MODIFIED` (a requirement without the scenario), as OpenSpec wants it. Undo puts it back. |
| The agent | `Ctrl+Alt+A` | **Change it** (your note says how) or **write it again** (to match the current specs, proposal and design). |

**The agent** (Claude Code): the work is written as a prompt in `.lazyspec/prompts/`, then you choose how to
run it:

- **Here**: Claude Code in a terminal. It may ask; you answer.
- **In the background**: it decides instead of asking, and its output goes to a channel. When it's done you
  can answer it or have it go on (*Answer Claude Code*, `claude -c`).
- **Save the prompt**: the command to give it is copied.

The choice is the project's default next time (`lazyspec: agent:` in `openspec/config.yaml`), the same as in
LazySpec.

**Out of date**: tasks (or a design) older than the specs they are written from. LazySpec notes what each
document was written from in `.lazyspec/sync.json`, and the extension reads and writes the same file.

- The first time it happens, you are asked whether to watch for it (`lazyspec: syncCheck:`).
- **Sync Out-of-Date Documents** (the warning button on the change) either has the agent update them (it
  gets what changed, before and now) or marks them as in sync.
- **Several at once**: **Sync All Out-of-Date Changes...** (the warning button in the Plan's title bar, or
  the `⚠` count in the status bar) lists every out-of-date change, all chosen. Untick the ones to leave, then
  update them (one agent run for all of them; each change validated and marked after) or mark them all as in
  sync. Selecting several changes in the Plan (`Ctrl`/`Shift`-click) and pressing `⚠` does the same for those.
- When the agent is done, the change is **marked as in sync by itself**, as in LazySpec:
  - **In the background**: when Claude Code ends with exit code 0 and `openspec validate <change> --strict`
    passes. Otherwise it isn't marked, and a message says why.
  - **Here**: Claude Code runs as the terminal itself. When it ends with 0 you are asked *mark as in sync?*
    (`/exit` also ends with 0 when you stopped it halfway).
  - **Save the prompt**: nothing is marked. Once the agent has changed a document the prompt names and the
    change is still out of date, you are offered to mark it.
- It marks against what the agent was given (`<prompt>.sync.json` next to the prompt, the same file LazySpec
  writes and reads). A document the agent rightly left unchanged is in sync too. A spec someone edited during
  the run still shows as out of date.

## Keys: the panes

All of LazySpec's keys, Windows / Linux and Mac side by side: **Help and Keys** (the `?` in the Plan's title
bar, or the LazySpec menu of an open document).

`Ctrl+;` then a letter (Mac `Cmd+;`), wherever you are. The view gets the keyboard, so the arrows, `PgUp`
and `PgDn` work right away; the Plan keeps its selection.

| Windows, Linux | Mac | Goes to |
|---|---|---|
| `Ctrl+;` `P` | `⌘;` `P` | the Plan |
| `Ctrl+;` `S` | `⌘;` `S` | the Scope |
| `Ctrl+;` `D` | `⌘;` `D` | the Details |
| `Ctrl+;` `U` | `⌘;` `U` | Undo |
| `Ctrl+;` `E` | `⌘;` `E` | the open document (the formatted editor: its text) |

| Windows, Linux | Mac | In the Plan and the Scope |
|---|---|---|
| `↑` `↓`, `→` `←`, `Enter` | the same | select; open and close a node; open (a document, or an item's document, formatted, at it) |
| `F2` | `F2` (`fn`+`F2` on a laptop) | edit the item |
| `Space` | `Space` | a task done / not done |
| `Delete` | `⌘⌫` | delete (asked first) |
| `Ctrl+Alt+A` | `⌘⌥A` | the agent |
| `Ctrl+Alt+R` | `⌘⌥R` | Read |
| `Ctrl+Alt+T` | `⌘⌥T` | Find (anywhere) |

VS Code's own: `Ctrl+B` / `⌘B` shows or hides the side bar, `Ctrl+0` / `⌘0` goes to it, `Ctrl+1` / `⌘1`
to the editor.

## Find

`Ctrl+Alt+T` (Mac `⌘⌥T`) finds tasks, requirements, scenarios and sections as you type.

- Each result has a small second line: the document it is in (TASKS, DESIGN, SPECS, OPEN QUESTIONS ...),
  what it is (task, requirement, scenario, section) and its requirement or task group.
- **By document**: type `in:` and the document's name, or its beginning, with your words: `in:design cache`,
  `in:open` (open questions), `in:tasks 1.3`. Alone, `in:design` lists all of that document's items.
- **By kind**: `is:task`, `is:open` (open tasks), `is:req`, `is:scenario`, `is:section`.
- Opening a result puts the keyboard in the document, with the cursor on it, so you can scroll right away.

- What you can type:
  - a task number: `1.3`
  - a change and a number: `01 1.3`
  - words
  - `g1` or `group 1`: one group only
- The buttons on top switch the kind (tasks, open tasks, requirements, scenarios, sections), the document
  (proposal, specs, design ...), and *select several*.
- Each result has buttons: read it, edit, done, the agent, delete.
- With several selected, `Enter` offers delete, the agent, done or not done.

## Changes and groups as one; export

- **Read Changes as One...** (the Plan's `...` menu): a saved whole, or changes you choose.
  - A title, then *save it?* (`lazyspec: bundles:` in `openspec/config.yaml`).
  - **Remove a Saved Whole...** takes one out.
- **Read Groups...** / **Export Groups...**: the groups you choose, with the ones they require added.
- **Export for the Client...**: PDF, Word or HTML, for the client (scenarios as sentences) or technical. It can
  export:
  - the specification, with or without the plan
  - a change
  - chosen changes as one
  - groups
  - a saved whole
  - a spec
- **Export in Another Language...**: the same, translated (DeepL; `translation:` in `config.yaml`).
- **Export Markdown as a Document...**: right-click any `.md` in the Explorer.
- **Export...** in Read exports what you are reading.

## And

| Command | |
|---|---|
| New Change, Validate All, Archive Change | Run the OpenSpec CLI in a terminal (`openspec new change`, `validate --all --strict`, `archive --yes`, asked first). |
| Plan: by Group or Flat; Show or Hide Archived; Sort Changes | Name A-Z, Z-A, or recently modified. |
| Open LazySpec (Terminal UI) | The terminal version, in an editor tab. |
| Open openspec/config.yaml, Help | |

## What it needs

- A folder with an `openspec/` folder: at its top, or up to three levels below it (a monorepo, `apps/portal`);
  `lazyspec.roots` names deeper ones.
- **The OpenSpec CLI** for validate, new change and archive: `npm install -g @fission-ai/openspec`.
- **git** for undo. **Claude Code** (`claude`) for the agent.
- **PowerShell** for export and the terminal UI. It is built into Windows; on macOS and Linux install
  PowerShell 7 (`brew install powershell`, https://aka.ms/powershell).
- **Edge or Chrome** for PDF export. **Word** (or pandoc) for Word export.

Export uses the project's own LazySpec (`tools/lazyspec/lazyspec.ps1`) when it has one, otherwise the copy
built into the extension. The company look (`documentTheme` / `documentTemplate` in `openspec/config.yaml`) and
every other project setting work the same as in LazySpec; see
[LAZYSPEC.md](https://github.com/netmedia/lazyspec/blob/develop/tools/lazyspec/LAZYSPEC.md).

## Settings

| Setting | Default | |
|---|---|---|
| `lazyspec.openOnStartup` | `true` | Opening a folder with `openspec/` (`code .` there) shows LazySpec's sidebar |
| `lazyspec.documents` | `formatted` | A document clicked opens in the formatted editor (`formatted`), the preview (`preview`) or as its Markdown (`source`) |
| `lazyspec.openMarkdownFormatted` | `true` | openspec's `.md` files open in the formatted editor wherever they are opened from (`workbench.editorAssociations`) |
| `lazyspec.editor` | `formatted` | Edit on an item: the item alone in the formatted editor (`formatted`), or its lines in the Markdown (`source`) |
| `lazyspec.grouped` | `true` | The plan by group (in projects that group their changes) |
| `lazyspec.showArchived` | `false` | Archived changes at the end of the plan |
| `lazyspec.sort` | `name` | `name`, `name-desc`, `recent` |
| `lazyspec.roots` | `[]` | Projects deeper than the workspace's folders, e.g. `apps/portal` |
| `lazyspec.openspec` | `openspec` | The OpenSpec CLI |
| `lazyspec.powershell` | | Empty: `powershell.exe` on Windows, `pwsh` elsewhere |
| `lazyspec.script` | | A `lazyspec.ps1` of your choice |

## Groups

A project groups its changes (phases, modules, packages the client can order on its own) in
`openspec/config.yaml`:

```yaml
groupLabel: "Phase"          # what a group is called (default Group)
groupLabelPlural: "Phases"
groups:
  - id: 1
    name: "Launch"
    description: "Sign-up, ordering and payment live"
  - id: 2
    name: "Loyalty"
    requires: [1]
```

Each change names its group with `x-group: <id>` in its `.openspec.yaml`. If that is missing, LazySpec looks
for the line `Phase: 1 – Launch` under the title of the change's first document, then for the folder prefix
`g1-`. A schema with `grouping: [group]` turns grouping on.

## Install

From the root of the LazySpec repository:

```
.\install-vscode.exe                  # Windows: every VS Code, Cursor, Windsurf, VSCodium found
.\install-vscode.exe -Editor cursor    # only these
./install-vscode.sh                   # macOS, Linux
```

For each editor it runs `<editor> --install-extension vscode/lazyspec.vsix --force`. `-Uninstall`
(`--uninstall`) removes it. After a `git pull`, run it again to update. Or in the editor: **Extensions: Install
from VSIX...** and pick `vscode/lazyspec.vsix`.

To build it yourself: `cd vscode`, `npm install`, `npm run package`.

## Develop

- `npm test`: the reading and the operations (node only). Includes a check that the out-of-date notes are the
  same as LazySpec's own.
- `npm run test:vscode`: the extension inside a downloaded VS Code, on a copy of the demo project in git.
- To debug, press `F5` with the `vscode` folder open.

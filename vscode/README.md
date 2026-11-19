# LazySpec for VS Code

A project's [OpenSpec](https://github.com/Fission-AI/OpenSpec) in the editor you already use: VS Code, Cursor,
Windsurf or any other editor built on VS Code. It shows what [LazySpec](https://github.com/netmedia/lazyspec)
shows in the terminal: the specifications, the plan with its groups and task progress, each change's documents,
tasks, requirements and scenarios. The documents themselves stay Markdown files that you open, edit and
review in the editor.

By [Netmedia](https://netmedia.agency).

## What you get

**The LazySpec sidebar** (the checklist icon in the activity bar):

- **Plan**: the active changes, each with its stage (draft, in progress, completed) and tasks done. If the
  project groups its changes (phases, modules), the plan is shown **by group**: a row per group with its changes
  and task progress. Under a change are its workflow's documents in the schema's order (proposal, specs,
  design, tasks ...), and documents not created yet are marked *not yet*.
  - **Tasks**: grouped by `## 1. ...` heading, each with a checkbox. Ticking it writes `[x]` into `tasks.md`.
  - **Specs**: each capability with its added, modified and removed requirements, down to their scenarios.
  - Click any item to open the file at that line.
- **Scope**: the specifications in the project's order, with their requirements and scenarios.
- **Details**: the selected item in full.
  - A change: its progress, tasks by group, capabilities (new or existing), why, and documents.
  - A spec: its purpose and requirements.
  - A group: its description, the groups it requires and those that require it, its changes and
    capabilities, and changes that depend on another group's changes.
- **Status bar**: the tasks done across the active changes.

**Commands** (also in the views' title bars and right-click menus):

| Command | What it does |
|---|---|
| LazySpec: Find (`Ctrl+Alt+T`, Mac `Cmd+Alt+T`) | Finds a task, requirement, scenario or section as you type. Accepts a task number (`1.3`), a change and a number (`01 1.3`), or words. `g1` or `group 1` limits it to one group. The filter button switches the kind: tasks, open tasks, requirements, scenarios, sections. |
| New Change | `openspec new change <name>` |
| Validate All | `openspec validate --all --strict` |
| Archive Change | `openspec archive <change> --yes`, after asking first |
| Export for the Client... | PDF, Word or HTML, for the client (scenarios as sentences) or technical. Can export the specification (with or without the plan), a change, chosen changes as one, groups, a saved bundle, or a spec. |
| Export Groups... | Exports the chosen groups as one document. Groups they require are added automatically, with a part per group. |
| Export Markdown as a Document... | Any `.md` file (meeting notes, a summary) as a document in the company look. Right-click it in the Explorer. |
| Plan: by Group or Flat; Show or Hide Archived | |
| Open LazySpec (Terminal UI) | The full LazySpec in an editor tab. Use it for everything this extension doesn't do yet: undo, out-of-date documents updated by the agent, removing or rewriting items through the agent. |

## What it needs

- A folder with an `openspec/` folder (or set `lazyspec.roots` for projects deeper in the workspace).
- **The OpenSpec CLI** for validate, new change and archive: `npm install -g @fission-ai/openspec`.
- **PowerShell** for export and the terminal UI. It is built into Windows; on macOS and Linux install
  PowerShell 7 (`brew install powershell`, https://aka.ms/powershell).
- **Edge or Chrome** for PDF export. **Word** (or pandoc) for Word export.

The extension uses the project's own LazySpec (`tools/lazyspec/lazyspec.ps1`) when it has one, otherwise the
copy built into it. The company look (`documentTheme` / `documentTemplate` in `openspec/config.yaml`) and every
other project setting work the same as in LazySpec; see
[LAZYSPEC.md](https://github.com/netmedia/lazyspec/blob/develop/tools/lazyspec/LAZYSPEC.md).

## Settings

| Setting | Default | |
|---|---|---|
| `lazyspec.openOnStartup` | `true` | Opening a folder with `openspec/` (`code .` there) shows LazySpec's sidebar |
| `lazyspec.grouped` | `true` | The plan by group (in projects that group their changes) |
| `lazyspec.showArchived` | `false` | Archived changes at the end of the plan |
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

It runs `<editor> --install-extension vscode/lazyspec.vsix --force` for each; `-Uninstall` (`--uninstall`)
removes it. After a `git pull`, run it again to update. Or in the editor: **Extensions: Install from VSIX...**
and pick `vscode/lazyspec.vsix`.

To build it yourself: `cd vscode`, `npm install`, `npm run package`.

## Develop

`npm test` runs the parsing tests (node only). `npm run test:vscode` runs the extension inside a downloaded VS
Code, on a copy of the demo project. To debug, press `F5` with the `vscode` folder open.

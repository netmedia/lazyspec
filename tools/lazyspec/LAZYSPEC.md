# LazySpec

**A Netmedia product.** Made and maintained by [Netmedia](https://netmedia.agency) (netmedia@netmedia.hr).

A project's [OpenSpec](https://github.com/Fission-AI/OpenSpec) in one terminal screen: the specifications
(`openspec/specs/`) with their requirements, the changes (`openspec/changes/`) with their stage, task
progress, capabilities and tasks, each readable in full. The OpenSpec CLI does the rest (validate,
archive, new change); LazySpec runs it and shows its output.

Windows PowerShell 5.1 or PowerShell 7, no modules. Reading needs only the files; the actions need the
OpenSpec CLI (`npm install -g @fission-ai/openspec`).

## Starting it

| From | Command |
|---|---|
| Anywhere in a project, LazySpec installed on the PC | `lazyspec` |
| The project's root, its kit, PowerShell | `.\lazyspec.exe` (or `.\lazyspec`) |
| The project's root, its kit, cmd | `lazyspec` |
| Anywhere | `.\tools\lazyspec\lazyspec.ps1 [-Root <project>]` |

PowerShell never runs a program from the current folder by its name alone, for safety: hence `.\`.
To type just `lazyspec` (like `lazygit`), once per PC — from the LazySpec repository (`install.exe`) or
from a project's kit (`.\lazyspec.exe -Install ...`):

| Command | What it does |
|---|---|
| `install.exe Profile`, `lazyspec.exe -Install Profile` | A `lazyspec` function in your PowerShell profiles: the nearest project's own `lazyspec.exe` (subfolders too); else, installed from the repository, the repository's copy |
| `install.exe Global`, `lazyspec.exe -Install Global` | A copy in `%LOCALAPPDATA%\Programs\LazySpec`, on your user PATH: one version for every project |
| `install.exe Both`, `lazyspec.exe -Install Both` | Both: the project's copy first, else the global one |
| `install.exe -Uninstall`, `lazyspec.exe -Uninstall` | Removes them |

Then open a new terminal. Installed on the PC, LazySpec puts nothing into the projects.
`lazyspec.exe` starts `tools\lazyspec\lazyspec.ps1` with the same arguments in the same console (no
execution policy to think about; double-click works too). `-Help` shows the guide.

The project is the nearest folder with `openspec\` above the current folder (else above the script).

## The screens

**Home** — two lists on the left, the selected item's details on the right, with a scrollbar. `→` moves into the details (`↑` `↓` scroll them), `←` back; `z` zooms the details to the whole width and back.

- *Scope* (the specifications): `◆` a platform page (`platform-*`, shown without the prefix), `●` a capability spec;
  the requirement count. Platform pages come first, `overview` on top.
- *Plan* (the changes): `○` draft (no tasks yet), `◆` in progress, `●` completed, `·` archived (hidden until `h`);
  done/total tasks and a bar. Sorted by name (01, 02 ...); `s` cycles name A-Z, Z-A, recently modified.
- The lists show titles: a spec's `# Title`, a change's number and the title of its proposal
  (`01 Platform foundations`).
- On the right, a summary of the selected item (no need to open it):
  - a spec: its requirement and scenario counts, the first paragraph of its purpose, its requirements, and
    the changes that will change it (with `+` added, `~` modified, `-` removed requirements);
  - a change: its progress (bar, %, tasks done), the tasks by group, the capabilities it touches, why (the
    first paragraph), which documents it has.
- `Enter` opens the whole page.

**Read** (`Enter`) — the whole page: the spec, or the change's documents as its workflow names them (proposal, delta specs, design, tasks ...; `←` `→`), formatted:
headings, lists, checkboxes, tables, code, requirements (`◆`), scenarios (`▸`) with WHEN / THEN.

**Run** — the OpenSpec CLI's output, coloured (`✓` passed, `✗` failed, `⚠` warnings).

**Help** (`?`) — the keys and who made it.

It refreshes by itself when files under `openspec/` change (an editor, git, an agent).

## Keys

| Screen | Keys |
|---|---|
| Home | `↑` `↓` select · `Tab` scope ↔ plan · `→` into the details (`↑` `↓` scroll them), `←`/`Esc` back · `z` zoom the details to the whole width (again: the lists back) · `PgUp` `PgDn` `Home` `End` scroll the details · `Enter` read · `v` validate all · `a` archive the change · `n` new change · `x` export (PDF, Word, HTML) · `e` edit · `s` sort · `h` archived · `/` filter · `r` refresh · `?` help · `q` quit |
| Read | `↑` `↓` `PgUp` `PgDn` `Home` `End` scroll · `←` `→` document · `x` export this spec or change · `e` edit · `Esc` back |
| Run | `PgUp` `PgDn` `Home` `End` scroll · `Esc` stop (asked first); when done `Enter`/`Esc` back |

## What the actions run

| Key | Command | Notes |
|---|---|---|
| `v` | `openspec validate --all --strict --no-interactive` | |
| `a` | `openspec archive <change> --yes` | asked first (with the open task count); merges the delta specs into `openspec/specs` |
| `n` | `openspec new change <name>` | the name is asked: kebab-case (a space becomes `-`) |
| `x` | `lazyspec -Export Pdf\|Word\|Html [-IncludeChanges] -Open` | the format is asked (`p` `w` `h`), then, with active changes, specs only or with the plan; no specs yet: the selected change alone; see [Export](#export-for-the-client) |
| `x` (Read) | `lazyspec -Export Pdf\|Word\|Html -Item <name> -Open` | the spec or change being read, alone; the format is asked (`p` `w` `h`) |
| `e` | `$env:VISUAL` / `$env:EDITOR` (in the console), else VS Code (`code`), else the file's default app | the spec, or the proposal / the document being read |

## Conventions it understands

- `openspec/specs/<name>/spec.md` — a spec; its `# Title` is shown without the project's name in front
  (`RAGmatic — Costs` → `Costs`). Specs named `platform-*` are platform pages (overview, architecture,
  costs, roadmap, decisions...).
- `openspec/changes/<name>/` — `proposal.md` (`## Why`, `## What Changes`, `## Impact`), `design.md`,
  `tasks.md` (`## 1. Group` + `- [ ]` / `- [x]`), `specs/<capability>/spec.md` (`## ADDED|MODIFIED|REMOVED|RENAMED Requirements`).
- `openspec/changes/archive/<date>-<name>/` — archived changes.

## The workflow (schema)

A change's documents come from its OpenSpec workflow, found as the CLI finds it: the change's
`.openspec.yaml` `schema:`, else `openspec/config.yaml` `schema:`, else `spec-driven`; its `schema.yaml`
in `openspec/schemas/<name>/`, then `%LOCALAPPDATA%\openspec\schemas\<name>\` (or
`$XDG_DATA_HOME\openspec\schemas`), then the CLI's built-in schemas.

- **Read** has one tab per artifact, in the schema's order (`open-questions` → *Open questions*); an
  artifact whose `generates` is a glob shows all its files; `specs/...` is the delta specs tab.
- **Documents** (in the details) lists them as done `✓` or not yet `○`, and names the workflow when it isn't
  `spec-driven`.
- **Tasks** and progress come from the file `apply.tracks` names (`tasks.md` by default).
- Other `.md` files in the change's folder are shown after the workflow's own.
- A schema it can't find: shown as `spec-driven`, with a warning in the details.

## Export for the client

The specification as one document: a cover page, the contents, a chapter per spec in the Scope order
(requirements and scenarios formatted, tables, code). With the plan: the active changes after it (each
one's proposal and delta specs).

```
.\lazyspec.exe -Export Pdf                        # or Word, Html
.\lazyspec.exe -Export Word -IncludeChanges -Open
.\lazyspec.exe -Export Pdf -Out D:\Clients\RAGmatic.pdf
.\lazyspec.exe -Export Pdf -Item add-user-login  # one spec or change alone (x in Read)
```

**One spec or change** (`-Item <name>`, or `x` while reading it): a spec alone, or a change with every
document of its [workflow](#the-workflow-schema), a chapter each in its order (proposal, specifications,
design, ... tasks). Works with no specs in `openspec/specs` yet. Written to `export\<project>-<name>-<date>.<ext>`.

| Format | Made with | Notes |
|---|---|---|
| PDF | Microsoft Edge (else Google Chrome), headless | page numbers and the title in the footer, links in the contents |
| Word (`.docx`) | Microsoft Word, else pandoc | Word's own table of contents (with page numbers) and page numbering; editable |
| HTML | LazySpec itself | one file, the styles inside |

Written to `export\<project>-specification-<date>.<ext>` in the project (add `export/` to `.gitignore`, or
commit what was sent); `-Out` writes elsewhere, `-Open` opens it. In the UI (`x`) it runs in the run screen
and opens the document when it's done.

## The project's settings

`tools/lazyspec/lazyspec.json` in a project with the kit (`initintoproject -Update` keeps it), else
`lazyspec.json` in the project's root (LazySpec installed on the PC); optional:

```json
{
  "specOrder": ["platform-overview", "platform-functional", "platform-architecture"],
  "export": { "title": "RAGmatic", "subtitle": "Functional specification", "client": "Acme d.o.o.", "author": "Netmedia" }
}
```

`specOrder` — the order of the Scope list (spec names); the rest follow (platform pages, then capabilities).
It is the order of the exported chapters too.

`export` — the cover page of an export, all optional: `title` (default: the project folder's name),
`subtitle` (`Specification`), `client` (none), `author` (`Netmedia`).

## The kit

| File | What |
|---|---|
| `tools/lazyspec/lazyspec.ps1` | The program |
| `tools/lazyspec/lazyspec.exe` | Starts it (also in the project's root) |
| `tools/lazyspec/kit.json` | Version and the kit's files |
| `tools/lazyspec/LAZYSPEC.md` | This |

Put into a project and updated by `initintoproject.ps1` of the LazySpec repository
(`.\initintoproject.ps1 <project> [-Update]`). Commit `tools/lazyspec/` and `lazyspec.exe`: everyone
gets it with the project. `-Remove` takes it out again, for LazySpec installed on the PC (`install.exe`):
the settings move to `lazyspec.json` in the project's root.

Testing: `lazyspec.ps1 -Keys "Down,Enter,snap" -Frames frames.txt [-Width 120 -Height 36]` presses keys
without a console and writes the screens as text.

---

LazySpec is developed by **Netmedia**  ·  https://netmedia.agency  ·  netmedia@netmedia.hr

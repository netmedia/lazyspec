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
| The project's root, PowerShell | `.\lazyspec.exe` (or `.\lazyspec`) |
| The project's root, cmd | `lazyspec` |
| Anywhere | `.\tools\lazyspec\lazyspec.ps1 [-Root <project>]` |

PowerShell never runs a program from the current folder by its name alone, for safety: hence `.\`.
`lazyspec.exe` starts `tools\lazyspec\lazyspec.ps1` with the same arguments in the same console (no
execution policy to think about; double-click works too). `-Help` shows the guide.

The project is the nearest folder with `openspec\` above the current folder (else above the script).

## The screens

**Home** — two lists on the left, the selected item's details on the right.

- *Specifications*: `◆` a platform page (`platform-*`, shown without the prefix), `●` a capability spec;
  the requirement count. Platform pages come first, `overview` on top.
- *Changes*: `○` draft (no tasks yet), `◆` in progress, `●` completed, `·` archived (hidden until `h`);
  done/total tasks and a bar. Sorted by name (01, 02 ...); `s` cycles name A-Z, Z-A, recently modified.
- Details of a spec: title, path, purpose (formatted: tables, lists), requirements with their scenario
  counts.
- Details of a change: stage, progress, Why / What Changes / Impact from `proposal.md`, the capabilities it
  touches (`+` added, `~` modified, `-` removed requirements; new or existing spec), the tasks by group.

**Read** (`Enter`) — the spec, or the change's proposal, design, tasks and delta specs (`←` `→`), formatted:
headings, lists, checkboxes, tables, code, requirements (`◆`), scenarios (`▸`) with WHEN / THEN.

**Run** — the OpenSpec CLI's output, coloured (`✓` passed, `✗` failed, `⚠` warnings).

**Help** (`?`) — the keys and who made it.

It refreshes by itself when files under `openspec/` change (an editor, git, an agent).

## Keys

| Screen | Keys |
|---|---|
| Home | `↑` `↓` select · `Tab` specs ↔ changes · `Enter` read · `PgUp` `PgDn` scroll the details · `v` validate all · `a` archive the change · `n` new change · `e` edit · `s` sort · `h` archived · `/` filter · `r` refresh · `?` help · `q` quit |
| Read | `↑` `↓` `PgUp` `PgDn` `Home` `End` scroll · `←` `→` document · `e` edit · `Esc` back |
| Run | `PgUp` `PgDn` `Home` `End` scroll · `Esc` stop (asked first); when done `Enter`/`Esc` back |

## What the actions run

| Key | Command | Notes |
|---|---|---|
| `v` | `openspec validate --all --strict --no-interactive` | |
| `a` | `openspec archive <change> --yes` | asked first (with the open task count); merges the delta specs into `openspec/specs` |
| `n` | `openspec new change <name>` | the name is asked: kebab-case (a space becomes `-`) |
| `e` | `$env:VISUAL` / `$env:EDITOR` (in the console), else VS Code (`code`), else the file's default app | the spec, or the proposal / the document being read |

## Conventions it understands

- `openspec/specs/<name>/spec.md` — a spec; its `# Title` is shown without the project's name in front
  (`RAGmatic — Costs` → `Costs`). Specs named `platform-*` are platform pages (overview, architecture,
  costs, roadmap, decisions...).
- `openspec/changes/<name>/` — `proposal.md` (`## Why`, `## What Changes`, `## Impact`), `design.md`,
  `tasks.md` (`## 1. Group` + `- [ ]` / `- [x]`), `specs/<capability>/spec.md` (`## ADDED|MODIFIED|REMOVED|RENAMED Requirements`).
- `openspec/changes/archive/<date>-<name>/` — archived changes.

## The kit

| File | What |
|---|---|
| `tools/lazyspec/lazyspec.ps1` | The program |
| `tools/lazyspec/lazyspec.exe` | Starts it (also in the project's root) |
| `tools/lazyspec/kit.json` | Version and the kit's files |
| `tools/lazyspec/LAZYSPEC.md` | This |

Put into a project and updated by `initintoproject.ps1` of the LazySpec repository
(`.\initintoproject.ps1 <project> [-Update]`). Commit `tools/lazyspec/` and `lazyspec.exe`: everyone
gets it with the project.

Testing: `lazyspec.ps1 -Keys "Down,Enter,snap" -Frames frames.txt [-Width 120 -Height 36]` presses keys
without a console and writes the screens as text.

---

LazySpec is developed by **Netmedia**  ·  https://netmedia.agency  ·  netmedia@netmedia.hr

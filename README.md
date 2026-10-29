# LazySpec

**A Netmedia product.** Made and maintained by [Netmedia](https://netmedia.agency)
(netmedia@netmedia.hr) for the projects Netmedia builds with spec-driven development.

A project's **OpenSpec** specifications and changes in **one terminal screen** — the sibling of
[LazyBicep](https://github.com/netmedia/lazybicep), with the same look, keys and technology.

- **Specifications** (`openspec/specs/`): platform pages (`platform-*`: overview, architecture, costs,
  roadmap, decisions) and capability specs, with their purpose and requirements.
- **Changes** (`openspec/changes/`): stage, task progress, why / what changes / impact, the capabilities
  they add, modify or remove requirements in, tasks by group; archived ones on `h`.
- **Read** any of them in full (proposal, design, tasks, delta specs), formatted for the terminal.
- **Actions** through the OpenSpec CLI: validate all, archive a change, new change; the output in the
  same screen. Edit opens your editor.

Windows PowerShell 5.1 or PowerShell 7, no modules. The OpenSpec CLI for the actions
(`npm install -g @fission-ai/openspec`). It works alongside other OpenSpec tools (the CLI, openspec-ui,
coding agents): it reads the same files and refreshes when they change.

## How to use it

Every script explains itself: run it with `-Help` (or `-h`).

| Script | What it is for |
|---|---|
| `initintoproject.exe` / `.ps1` | (this repository) Puts the kit into a project, or updates it there |
| `lazyspec.exe`, `tools\lazyspec\lazyspec.exe` / `.ps1` | (in the project: its root and `tools\lazyspec`) The terminal UI; `?` shows the keys |

**The .exe files** start the `.ps1` of the same name next to them (or in `tools\lazyspec\` below them),
with the same arguments, in the same console (no execution policy to think about; double-click works
too). The `.ps1` stays the program: changing it needs no new build. Their file properties say Netmedia,
LazySpec and the version; `.\build-exe.ps1` rebuilds them (only after `launcher\launcher.cs` or the
version changes). They aren't code-signed, so Windows SmartScreen may ask once on a new PC.

**From the command line:** in PowerShell type `.\lazyspec.exe` (or `.\lazyspec`): PowerShell never runs
a program from the current folder by its name alone, for safety. In cmd, `lazyspec` is enough.

### 1. Into a project

```
.\initintoproject.exe D:\Development\Netmedia\MyProject
cd D:\Development\Netmedia\MyProject
openspec init                       # once, if the project has no openspec\ yet
.\lazyspec.exe
```

Commit `tools\lazyspec\` and `lazyspec.exe`: everyone gets it with the project.

### 2. Updating a project's kit

```
.\initintoproject.ps1 D:\Development\Netmedia\MyProject -Update
```

Replaces the kit's files (`tools/lazyspec/kit.json` lists them); the project's `openspec/` is never touched.

Everything else (screens, keys, conventions): [`tools/lazyspec/LAZYSPEC.md`](tools/lazyspec/LAZYSPEC.md).

## In this repository

| Path | What |
|---|---|
| `initintoproject.exe`, `initintoproject.ps1` | Puts the kit into a project, or updates it (the .exe starts the .ps1) |
| `build-exe.ps1`, `launcher/launcher.cs` | Builds the two .exe launchers |
| `tools/lazyspec/` | The kit, as it lands in a project |
| `tools/lazyspec/LAZYSPEC.md` | Everything about it |

---

LazySpec is developed by **Netmedia**  ·  https://netmedia.agency  ·  netmedia@netmedia.hr

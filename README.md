# LazySpec

**A Netmedia product.** Made and maintained by [Netmedia](https://netmedia.agency)
(netmedia@netmedia.hr) for the projects Netmedia builds with spec-driven development.

A project's **OpenSpec** specifications and changes in **one terminal screen** — the sibling of
[LazyBicep](https://github.com/netmedia/lazybicep), with the same look, keys and technology.

- **Specifications** (`openspec/specs/`): platform pages (`platform-*`: overview, architecture, costs,
  roadmap, decisions) and capability specs, with their purpose and requirements.
- **Changes** (`openspec/changes/`): stage, task progress, why / what changes / impact, the capabilities
  they add, modify or remove requirements in, tasks by group; archived ones on `h`.
- **Read** any of them in full (proposal, design, tasks, delta specs, or whatever documents the change's
  OpenSpec workflow schema defines), formatted for the terminal.
- **Actions** through the OpenSpec CLI: validate all, archive a change, new change; the output in the
  same screen. Edit opens your editor.

Windows PowerShell 5.1 or PowerShell 7, no modules. The OpenSpec CLI for the actions
(`npm install -g @fission-ai/openspec`). It works alongside other OpenSpec tools (the CLI, openspec-ui,
coding agents): it reads the same files and refreshes when they change.

## How to use it

Two ways; a PC can use both (a project's own copy always wins):

| | **Installed on the PC** | **In the project** |
|---|---|---|
| What | LazySpec from this repository; nothing goes into the projects | The kit in the project (`tools\lazyspec\`), committed with it |
| Set up | `.\install.exe Profile` (or `Global`, `Both`), once per PC | `.\initintoproject.exe <project>`, once per project |
| Start | `lazyspec`, anywhere inside a project | `.\lazyspec.exe` in its root (or `lazyspec` with the profile function) |
| Version | this repository's (`git pull`), or the global copy's | the project's: everyone on the team has the same one |
| Settings | `lazyspec.json` in the project's root | `tools\lazyspec\lazyspec.json` |

Every script explains itself: run it with `-Help` (or `-h`).

| Script | What it is for |
|---|---|
| `install.exe` / `.ps1` | (this repository) Installs LazySpec on this PC, or removes it |
| `initintoproject.exe` / `.ps1` | (this repository) Puts the kit into a project, or updates it there |
| `lazyspec.exe`, `tools\lazyspec\lazyspec.exe` / `.ps1` | The terminal UI (in a project: its root and `tools\lazyspec`); `?` shows the keys |

**The .exe files** start the `.ps1` of the same name next to them (or in `tools\lazyspec\` below them),
with the same arguments, in the same console (no execution policy to think about; double-click works
too). The `.ps1` stays the program: changing it needs no new build. Their file properties say Netmedia,
LazySpec and the version; `.\build-exe.ps1` rebuilds them (only after `launcher\launcher.cs` or the
version changes). They aren't code-signed, so Windows SmartScreen may ask once on a new PC.

**For the client:** `x` in the UI, or `lazyspec -Export Pdf` (or `Word`, `Html`), makes one document
of the whole specification: a cover, the contents, a chapter per spec. See
[Export for the client](tools/lazyspec/LAZYSPEC.md#export-for-the-client).

### 1. Installed on the PC (not in the project)

```
.\install.exe Profile               # in this repository
cd D:\Development\Netmedia\MyProject
lazyspec                            # in a new terminal
```

| Command (in this repository) | What it does |
|---|---|
| `.\install.exe Profile` | A `lazyspec` function in your PowerShell profiles: the project's own copy when it has one, else this repository's `tools\lazyspec\lazyspec.exe` (a `git pull` here updates it). |
| `.\install.exe Global` | A copy in `%LOCALAPPDATA%\Programs\LazySpec`, on your user PATH, like lazygit: works in cmd and other shells too. A fixed version: install again to update. |
| `.\install.exe Both` | Both: the function runs the project's own copy, else the global one. |
| `.\install.exe Update` | After a `git pull` here: the global copy gets this repository's version (old → new shown), the profile function is rewritten as this version writes it. |
| `.\install.exe -Uninstall` | Removes them. |

Open a new terminal afterwards. The profile needs an execution policy that runs local scripts
(`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`); `install.exe Profile` says so when it doesn't.
The same from a project's kit: `.\lazyspec.exe -Install Profile|Global|Both`, `.\lazyspec.exe -Uninstall`
(installed from a project, the function runs only projects' own copies, and the global one if installed).

### 2. In the project

```
.\initintoproject.exe D:\Development\Netmedia\MyProject
cd D:\Development\Netmedia\MyProject
openspec init                       # once, if the project has no openspec\ yet
.\lazyspec.exe
```

Commit `tools\lazyspec\` and `lazyspec.exe`: everyone gets it with the project. In PowerShell type
`.\lazyspec.exe` (or `.\lazyspec`): PowerShell never runs a program from the current folder by its name
alone, for safety. In cmd, `lazyspec` is enough; in PowerShell too with the profile function (above).

### 3. Updating a project's kit

```
.\initintoproject.ps1 D:\Development\Netmedia\MyProject -Update
```

Replaces the kit's files (`tools/lazyspec/kit.json` lists them); the project's `openspec/` is never touched.

### 4. Taking the kit out of a project

```
.\initintoproject.ps1 D:\Development\Netmedia\MyProject -Remove [-DryRun]
```

For a project that should use LazySpec installed on the PC (1.) instead of its own copy. It removes the kit's
files (`tools\lazyspec\` and `lazyspec.exe` in the root) and moves the project's settings from
`tools\lazyspec\lazyspec.json` to `lazyspec.json` in the root, where installed LazySpec reads them (when the
root has a different one already, it keeps both and says so). Folders with anything else in them stay;
`openspec\` is never touched. It tells you when LazySpec isn't installed on this PC yet. Commit the
removal: the team then installs LazySpec on their PCs too.

Everything else (screens, keys, conventions): [`tools/lazyspec/LAZYSPEC.md`](tools/lazyspec/LAZYSPEC.md).

## In this repository

| Path | What |
|---|---|
| `install.exe`, `install.ps1` | Installs LazySpec on this PC, not into a project (the .exe starts the .ps1) |
| `initintoproject.exe`, `initintoproject.ps1` | Puts the kit into a project, or updates it (the .exe starts the .ps1) |
| `build-exe.ps1`, `launcher/launcher.cs` | Builds the .exe launchers |
| `tools/lazyspec/` | The kit, as it lands in a project (and what `install` runs) |
| `tools/lazyspec/LAZYSPEC.md` | Everything about it |

---

LazySpec is developed by **Netmedia**  ·  https://netmedia.agency  ·  netmedia@netmedia.hr

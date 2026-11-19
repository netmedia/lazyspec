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
- **Find** (`t`, or `Ctrl+F` from any screen): a task by its number (`1.3`, `01 1.3`) or words, a requirement,
  a scenario - in the specs and the changes; `Enter` opens it in Read, at it.
- **Edit in place**: in Read, `↑` `↓` pick a task, requirement or scenario; `Enter` edits only it in a window
  (`Ctrl+S`), `Space` ticks a task, `Del` deletes it, `a` hands it to the agent (Claude Code). Several at once
  from Find: mark them, then delete, change or write them again. A main spec is changed through a change
  (`REMOVED` / `MODIFIED`), as OpenSpec wants it.
- **Out of date**: tasks (or a design) older than the specs they're written from get `!` and what changed;
  `y` has the agent update them, or marks them as in sync.
- **Undo** (`u`): every change to `openspec/` since the last git commit, piece by piece; undo one, or a whole
  file.
- **Documents for the client**: PDF, Word, HTML in the company look (a theme), one spec or change, several
  changes as one, any Markdown file; written to `openspec/exports/`.

In a project's `.gitignore`: `.lazyspec/` (LazySpec's own notes and the agent's prompts) and, unless you commit
what went to the client, `openspec/exports/`. The Netmedia conventions keep the document theme in
`openspec/artifacts/` (`document-theme.yaml`, used when `documentTheme:` isn't set).

**Windows and macOS.** Windows PowerShell 5.1 or PowerShell 7 on Windows, PowerShell 7 on macOS; no
modules. The OpenSpec CLI for the actions (`npm install -g @fission-ai/openspec`). It works alongside other
OpenSpec tools (the CLI, openspec-ui, coding agents): it reads the same files and refreshes when they change.

## Windows and macOS

The program is the same `.ps1` on both; only how it starts and what the exports use differ.

| | Windows | macOS |
|---|---|---|
| PowerShell | Windows PowerShell 5.1 (built in) or PowerShell 7 | PowerShell 7: `brew install powershell` |
| Start in a project | `.\lazyspec.exe` (or `.\tools\lazyspec\lazyspec.ps1`) | `pwsh tools/lazyspec/lazyspec.ps1` |
| The `.exe` files | start the `.ps1` next to them | Windows only: use `pwsh <script>.ps1` |
| Kit into a project | `.\initintoproject.exe <project>` | `pwsh initintoproject.ps1 <project>` |
| Plain `lazyspec` | `.\install.exe Profile` / `Global` / `Both` | an alias in your shell (below); `install` is for Windows |
| PDF export | Edge (always there) or Chrome | Chrome or Edge in `/Applications` |
| Word export, default look | Microsoft Word, else pandoc | pandoc (`brew install pandoc`) |
| Word export, theme or template | LazySpec writes it; Word fills in the contents' page numbers | LazySpec writes it; page numbers: open it in Word, right-click the contents, Update Field |
| Data-model diagram | a picture in Word made by Edge/Chrome; vector in PDF and HTML | the same (Chrome or Edge) |
| Your per-user data (translation cache) | `%LOCALAPPDATA%\LazySpec` | `~/Library/Application Support/LazySpec` |

### Starting on macOS

```
brew install powershell                          # once
cd ~/Development/MyProject
pwsh tools/lazyspec/lazyspec.ps1                 # the project's own kit (initintoproject put it there)
```

A project without the kit: LazySpec from this repository, inside the project or pointed at it.

```
pwsh <this repository>/tools/lazyspec/lazyspec.ps1
pwsh <this repository>/tools/lazyspec/lazyspec.ps1 -Root ~/Development/MyProject
```

Plain `lazyspec` in every terminal: an alias to this repository's copy (a `git pull` here updates it).

```
# zsh (the macOS default)
echo "alias lazyspec='pwsh -NoProfile -File <this repository>/tools/lazyspec/lazyspec.ps1'" >> ~/.zshrc
# fish
alias --save lazyspec 'pwsh -NoProfile -File <this repository>/tools/lazyspec/lazyspec.ps1'
```

The alias always runs this repository's version; in a project with its own kit,
`pwsh tools/lazyspec/lazyspec.ps1` runs the team's. Paths in `openspec/config.yaml` (theme, template) may
use `/` or `\`: both work on both systems.

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
[Export for the client](tools/lazyspec/LAZYSPEC.md#export-for-the-client). Changes that go to the client as
one whole: `m` (mark them, read them together, `x` exports them; saved as a named whole in
`openspec/config.yaml` for next time) or `lazyspec -Export Word -Item <change>,<change> -Title "<title>"`
(a saved one: `-Item <its key>`). Word documents in the company's
layout: `documentTemplate: <path to a .docx>` under `lazyspec:` in the project's `openspec/config.yaml`
(relative to the project's root), or `-Template <path>` for one export; see
[Word document template](tools/lazyspec/LAZYSPEC.md#word-document-template). The same company look in PDF,
Word and HTML, with no Word needed: `documentTheme: <path to a .yaml>` (or `-Theme <path>`), its fonts in
`fonts/` next to it (embedded in Word); see [Document theme](tools/lazyspec/LAZYSPEC.md#document-theme) and
the example [`examples/document-theme/document-theme.yaml`](examples/document-theme/document-theme.yaml).
Any Markdown file (meeting notes, a summary) as a document in that look: `lazyspec -Export Word -Markdown <file.md>`
(or `Pdf`, `Html`; its front matter: title, subtitle, toc ...); see
[Markdown documents](tools/lazyspec/LAZYSPEC.md#markdown-documents).
In another language: `lazyspec -Export Pdf -Language en` translates the documents with DeepL (`translation:` in
`openspec/config.yaml`, the key in `DEEPL_AUTH_KEY`; `-Beta` for DeepL beta languages such as Croatian; an export into
Croatian is checked by Hasek/ispravi.me); `lazyspec -AddLanguage it` adds LazySpec's texts for a new language. See
[Export in another language](tools/lazyspec/LAZYSPEC.md#export-in-another-language-deepl).
Tests: `.\tests\Test-WordTemplate.ps1`, `.\tests\Test-DocumentTheme.ps1`, `.\tests\Test-MarkdownDocument.ps1`, `.\tests\Test-Translation.ps1`, `.\tests\Test-Search.ps1`, `.\tests\Test-Revise.ps1`
(macOS: `pwsh tests/Test-WordTemplate.ps1` and so on). They use the system's Georgia, which Windows and macOS both have.

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
Step by step for developers, with diagrams and screenshots: [`docs/developer-guide.md`](docs/developer-guide.md) (as Word: [`docs/LazySpec-Developer-Guide.docx`](docs/LazySpec-Developer-Guide.docx)).

## In this repository

| Path | What |
|---|---|
| `install.exe`, `install.ps1` | Installs LazySpec on this PC, not into a project (the .exe starts the .ps1) |
| `initintoproject.exe`, `initintoproject.ps1` | Puts the kit into a project, or updates it (the .exe starts the .ps1) |
| `build-exe.ps1`, `launcher/launcher.cs` | Builds the .exe launchers |
| `tools/lazyspec/` | The kit, as it lands in a project (and what `install` runs) |
| `tools/lazyspec/LAZYSPEC.md` | Everything about it |
| `docs/developer-guide.md` | Developer guide: install, add to a project, every workflow, with diagrams and screenshots |
| `docs/LazySpec-Developer-Guide.docx` / `.pdf` | The developer guide as Word and PDF |
| `docs/LazySpec-Reference.docx` / `.pdf`, `docs/LazySpec-README.docx` / `.pdf` | `LAZYSPEC.md` and this README as Word and PDF |
| `docs/examples/` | What a client gets: the demo project's specification with the plan, one change (PDF, Word), a saved bundle |
| `docs/build-documents.ps1` | Makes all of the above with LazySpec itself, in a document theme (Netmedia's: the AIToolbelt repository's `plugins/netmedia-document/theme/`) |
| `examples/acme-portal/` | A made-up demo project (specs, changes, models): the guide's screenshots and `docs/examples/` come from it |
| `examples/document-theme/` | An example document theme (every key explained) |
| `tests/` | Tests of the export (Word template, document theme): `.\tests\Test-*.ps1` |

---

LazySpec is developed by **Netmedia**  ·  https://netmedia.agency  ·  netmedia@netmedia.hr

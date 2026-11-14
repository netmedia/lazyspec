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
| `install.exe Update` | After a `git pull` in the repository: the global copy and the profile function get its version |
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

**Changes as one** (`m`) — the changes that go to the client as one whole. On top, the **saved wholes**
(`lazyspec: bundles:` in `openspec/config.yaml`): `Enter` reads one, `Space` marks its changes (to change
them), `d` removes it (asked first). Below, the active changes: `Space` marks them (`a` all or none), `Enter`
asks a title for the whole (on the cover; nothing: the changes' titles) and, when it isn't saved yet, whether
to save it (`s` save, `n` not now) — its key is the title without accents (`Online rezervacije` →
`online-rezervacije`). Then Read shows them together: a tab per kind of document (*Proposal (2)*, *Specs*,
*Design (2)* ...), each change's part under its title. `x` there exports them as one document.

**Run** — the OpenSpec CLI's output, coloured (`✓` passed, `✗` failed, `⚠` warnings).

**Help** (`?`) — the keys and who made it.

It refreshes by itself when files under `openspec/` change (an editor, git, an agent).

## Keys

| Screen | Keys |
|---|---|
| Home | `↑` `↓` select · `Tab` scope ↔ plan · `→` into the details (`↑` `↓` scroll them), `←`/`Esc` back · `z` zoom the details to the whole width (again: the lists back) · `PgUp` `PgDn` `Home` `End` scroll the details · `Enter` read · `v` validate all · `a` archive the change · `n` new change · `x` export (PDF, Word, HTML) · `m` changes as one · `e` edit · `s` sort · `h` archived · `/` filter · `r` refresh · `?` help · `q` quit |
| Read | `↑` `↓` `PgUp` `PgDn` `Home` `End` scroll · `←` `→` document · `x` export this spec, change or changes as one · `e` edit · `Esc` back |
| Changes as one | `↑` `↓` select · `Space` mark (a saved whole: its changes) · `a` all, none · `Enter` go on (a saved whole: read it; else a title, save it?, then Read) · `d` remove a saved whole · `Esc` cancel |
| Run | `PgUp` `PgDn` `Home` `End` scroll · `Esc` stop (asked first); when done `Enter`/`Esc` back |

## What the actions run

| Key | Command | Notes |
|---|---|---|
| `v` | `openspec validate --all --strict --no-interactive` | |
| `a` | `openspec archive <change> --yes` | asked first (with the open task count); merges the delta specs into `openspec/specs` |
| `n` | `openspec new change <name>` | the name is asked: kebab-case (a space becomes `-`) |
| `x` | `lazyspec -Export Pdf\|Word\|Html [-IncludeChanges] -Open` | the format is asked (`p` `w` `h`), then, with active changes, specs only or with the plan, then for the client or technical (`c` `t`); with two or more active changes also *chosen changes, as one* (`c`: marked as with `m`); no specs yet: the selected change alone or chosen changes as one; see [Export](#export-for-the-client) |
| `m`, then `x` | `lazyspec -Export Pdf\|Word\|Html -Item <change>,<change> -Title <title> -Open`, a saved whole: `-Item <its key>` | changes as one whole; see [Several changes as one](#export-for-the-client) |
| `x` (Read) | `lazyspec -Export Pdf\|Word\|Html -Item <name> -Open` | the spec or change being read, alone; the format is asked (`p` `w` `h`), then for the client or technical (`c` `t`) |
| `e` | `$env:VISUAL` / `$env:EDITOR` (in the console), else VS Code (`code`), else the file's default app | the spec, or the proposal / the document being read |

## Conventions it understands

- `openspec/specs/<name>/spec.md` — a spec; its `# Title` is shown without the project's name in front
  (`RAGmatic — Costs` → `Costs`). Specs named `platform-*` are platform pages (overview, architecture,
  costs, roadmap, decisions...).
- `openspec/changes/<name>/` — `proposal.md` (`## Why`, `## What Changes`, `## Impact`), `design.md`,
  `tasks.md` (`## 1. Group` + `- [ ]` / `- [x]`), `specs/<capability>/spec.md` (`## ADDED|MODIFIED|REMOVED|RENAMED Requirements`).
- `openspec/changes/archive/<date>-<name>/` — archived changes.
- `models.md` (the v2 schemas' `models` artifact: a change's new and changed models and lookup lists) — a
  tab in Read and a chapter in the export (*Models*, *Modeli*, *Datenmodelle*). A table whose first column is
  *Change* / *Promjena* / *Änderung* is a table of changes: a row marked `+` is green, `~` yellow, `-` red
  (PDF, HTML and Word). The export draws the **models' diagram** from it, after the overview table: a box per
  model under ``### `Name` `` (new: green, all fields up to 10; changed: yellow, only its `+` `~` `-` fields;
  lookup lists: grey, dashed), and the relations from the `**Veze:**` / `**Relations:**` lines
  (`` `A` N:1 `B` (`BId`); + `C` 1:N `A` ``) and from fields typed as another model or list, with their
  cardinality; new relations green, removed red. To stay simple it leaves out a changed model's unchanged
  relations to models the document doesn't describe (they stay in its table and relations line).
- HTML comments (`<!-- ... -->`, a template's guidance) aren't shown in the export.

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
.\lazyspec.exe -Export Word -Item add-guest-account,add-online-booking -Title "Online booking"
```

**One spec or change** (`-Item <name>`, or `x` while reading it): a spec alone, or a change with every
document of its [workflow](#the-workflow-schema), a chapter each in its order (proposal, specifications,
design, ... tasks). Works with no specs in `openspec/specs` yet. Written to `export\<project>-<name>-<date>.<ext>`.

**Several changes as one** (`-Item a,b,c`, or `m` / `x` *chosen changes* in the UI): changes that reach the
client as one whole, in one document. A chapter per kind of document, in the workflows' order (proposal,
specifications, models, design, ... tasks; the documents no workflow names last), each change's part under
its title; the specifications chapter has one contents of all their capabilities, each change's diagram
before its own. `-Title` is the cover's subtitle (else the changes' titles, comma-separated) and names the
file: `export\<project>-<title>-<date>.<ext>` (without accents). Changes only; an archived one by its name
too (its folder `<date>-<name>`).

**Saved wholes** (`m` asks to save one; or by hand, in `openspec/config.yaml`):

```yaml
lazyspec:
  bundles:
    online-rezervacije:                    # its key: -Item online-rezervacije, the file's name
      title: "Online rezervacije i gostinski račun"
      changes: add-guest-account, add-backoffice-online-reservations
```

`lazyspec -Export Word -Item online-rezervacije` exports it with its title (`-Title` wins). Saving and
removing in the UI change only these lines; the rest of `config.yaml` stays as it is.

**For the client or technical** (asked last in the UI; `-ClientFriendly` on the command line): for the
client, a scenario's steps become one sentence (`- **WHEN** x` / `- **THEN** y` → *When x, then y.*; also
`KADA` / `TADA`, `WENN` / `DANN` ...), and the normative keywords in brackets (`MORA (MUST)`) go. The text
itself stays as written. Technical: as written. Tasks are bullets either way (done ones with `✓`).

**The language:** the workflow schema's `language:` (LazySpec's own key; the OpenSpec CLI ignores it):

```yaml
name: nava-spec-driven
version: 1
language: hr
artifacts: ...
```

else `lazyspec.json` `export.language`, else `en`. In the export, everything LazySpec writes (the chapters
*Proposal*, *Tasks* ..., *Requirement*, *Scenario*, the cover, the contents, the date) and OpenSpec's fixed
English headings (`## ADDED Requirements`, `## Purpose`, `## Why` ...) are in that language; in the
documents themselves and in the UI they stay English, as OpenSpec needs them. `en`, `hr`, `de` and `nl` are in
`tools/lazyspec/export-texts.json`: another language is another block there (`lazyspec -AddLanguage <xx>` makes one
with DeepL, below).

### Export in another language (DeepL)

`-Language <xx>` exports in that language. When the documents are written in another one (the workflow schema's
`language:`), LazySpec translates them with DeepL: the chapters, titles and capability titles; code, LazySpec's own
texts and the layout stay. The settings are the project's `translation:` block in `openspec/config.yaml`, shared
with the netmedia plugin (`netmedia:translate`):

```yaml
translation:
  provider: deepl          # needed for -Language and -AddLanguage
  keyEnv: DEEPL_AUTH_KEY   # the environment variable with the key (default DEEPL_AUTH_KEY)
  english: en-GB           # DeepL's variant for English
  formality: prefer_more   # optional, where DeepL supports it
  hasek: ask               # translations into Croatian: ask | always | never
```

The key only in that environment variable (`setx DEEPL_AUTH_KEY "<key>"`, then a new terminal); a key in
`config.yaml` is refused - the file is in git. Free keys end with `:fx` (api-free.deepl.com).

```
lazyspec -Export Pdf -Language en                 # a Croatian spec for an English-speaking reader
lazyspec -Export Word -Item add-online-booking -Language de
lazyspec -Export Pdf -Language hr -Beta           # into a DeepL beta language
```

- **Beta languages:** DeepL's additional languages (Croatian among them) run on its next-generation model:
  no glossary, no formal/informal tone, often no markup handling - LazySpec then translates text by text,
  which can split a sentence around bold or links. A beta language (source or target) needs `-Beta`; without
  it LazySpec asks in a console, or stops and says so.
- **Cache:** each text is translated once per language pair (`%LOCALAPPDATA%\LazySpec\translations\`), so a
  second export costs no DeepL characters.
- **Hasek:** an export into Croatian is checked by ispravi.me (the same API as Netmedia's Hasek add-ins), as
  `translation: hasek:` says (`ask` asks in a console). The findings go to `<document>.hasek.md` next to the
  document; nothing is changed - fix the source documents, or accept them.
- **New languages:** `lazyspec -AddLanguage it` adds LazySpec's texts and OpenSpec's English headings for
  Italian to `export-texts.json`, translated from English (`-Force` replaces them; `-Beta` for a beta
  language). Have a native speaker read them, then commit the kit's `export-texts.json`.

Tests: `.\tests\Test-Translation.ps1` (no network: `LAZYSPEC_DEEPL_FAKE`, `LAZYSPEC_HASEK_FAKE`).

| Format | Made with | Notes |
|---|---|---|
| PDF | Microsoft Edge (else Google Chrome), headless | page numbers and the title in the footer, links in the contents |
| Word (`.docx`) | Microsoft Word, else pandoc; with a [document template](#word-document-template): LazySpec itself | Word's own table of contents (with page numbers) and page numbering; editable |
| HTML | LazySpec itself | one file, the styles inside |

Written to `export\<project>-specification-<date>.<ext>` in the project (add `export/` to `.gitignore`, or
commit what was sent); `-Out` writes elsewhere, `-Open` opens it. In the UI (`x`) it runs in the run screen
and opens the document when it's done.

### Markdown documents

Any Markdown file (meeting notes, a summary, a letter, anything sent to the client) as a document in the
project's look (its [theme](#document-theme), or its [template](#word-document-template) for Word), in any
of the three formats:

```
lazyspec -Export Word -Markdown "openspec_meetings\2026-11-04 summary.md"     # or Pdf, Html
lazyspec -Export Pdf -Markdown notes.md -Out D:\Clients\notes.pdf -Open
```

- **Written next to the file**, the same name (`summary.docx`); `-Out` writes elsewhere.
- **The project** is the one the file is in (an `openspec` folder above it): its theme, template, language,
  author, client. A file outside a project: the default look (`-Theme`, `-Template` still work).
- **The front matter** (all optional):

  ```markdown
  ---
  title: Nava Charter booking
  subtitle: Meeting summary, 4 November 2026
  client: Nava d.o.o.             # else the project's
  author: Netmedia                # else the project's
  date: 4. 11. 2026.              # else today
  language: hr                    # the cover's and contents' words; else the project's
  toc: true                       # a contents of headings 1-2 (default: none)
  cover: false                    # no cover page: the title at the top of the first page (default: a cover)
  ---
  ```

  No `title`: the first `# ` heading (then not repeated in the text), else the file's name.
- **The text:** as in the export (headings, lists, tables, code, links, quotes); `# ` headings don't start
  pages here; a hard line break (`\` or two spaces at a line's end) is kept.

Tests: `.\tests\Test-MarkdownDocument.ps1` (in the LazySpec repository).

### Document theme

One look for every document LazySpec makes, **in all three formats** (PDF, Word, HTML), with no Word or other
program needed: `documentTheme:` under `lazyspec:` in `openspec/config.yaml`, a YAML file relative to the
project's root (spaces are fine); `-Theme <path>` (relative to the current folder) wins over it for one export.

```yaml
lazyspec:
  # documentTheme: the look of every generated document - export, meeting notes, summaries.
  documentTheme: openspec_artifacts/theme/document-theme.yaml
```

The theme sets the page (size, margins), colours, the styles (the cover's title and subtitle, headings 1-6,
text, the contents' heading, tables, links, code: font, size, bold, italic, underline, colour, spacing, line
height, alignment), the header and footer (left, centre, right: a text with `{title}` `{subtitle}`
`{client}` `{date}` `{page}` `{pages}`, or the logo; none on the cover unless `firstPage: true`) and the
cover's logo. Every key, explained: [`examples/document-theme/document-theme.yaml`](../../examples/document-theme/document-theme.yaml)
in the LazySpec repository.

Next to the theme:

- `fonts/`: the fonts' `.ttf` (or `.otf`) files. PDF and HTML use them without installing them (inside the
  document); **Word gets them embedded** (as Word embeds fonts: regular, bold, italic, bold italic), so the
  document shows them on any PC. Name a family in the theme as the font calls itself (`Montserrat`); a font
  not in `fonts/` must be installed, else a warning names it. Use `.ttf` for Word (an `.otf` gets a warning).
  Check that the font's licence allows embedding (OFL fonts, such as Montserrat, do).
- the logos (`.png`, `.jpg`, `.gif`), at the paths the theme names (relative to it).

| | HTML | PDF (Edge) | Word |
|---|---|---|---|
| Fonts | `@font-face`, from `fonts/` | the same, embedded in the PDF | embedded in the .docx (obfuscated, as Word does) |
| Styles | CSS | CSS | the built-in styles: Normal, Title, Subtitle, Heading 1-6, TOC Heading, Table Grid, Hyperlink |
| Page, header, footer | - | `@page`: size, margins, logo, texts, page numbers | section: size, margins, header and footer parts, PAGE / NUMPAGES |

- **Set, but missing, broken (the error names the line) or a logo missing:** the export stops with an error
  naming the path (exit code 1), never the default look.
- **A theme and a [document template](#word-document-template):** Word documents use the template, PDF and
  HTML the theme (the export says so); `-Theme` on the command line: Word uses the theme too.
- **Not set:** as before.

Tests: `.\tests\Test-DocumentTheme.ps1` (in the LazySpec repository).

### Word document template

Client documents in the company's layout: `documentTemplate:` under `lazyspec:` in `openspec/config.yaml`,
a `.docx` relative to the project's root (spaces are fine, no quotes needed); `-Template <path>` (relative to
the current folder) wins over it for one export.

```yaml
lazyspec:
  # documentTemplate: the Word template (.docx) every generated document uses - export, meeting notes, summaries.
  documentTemplate: openspec_artifacts/Document template.docx
```

Every Word document LazySpec makes is then built on that template:

- **Kept from the template:** its styles, page setup, section properties, headers and footers with their
  pictures (the logo), the first page's own header and footer, its fonts (LazySpec sets none, except a
  monospace one for code).
- **Not kept:** its sample body (a sample cover "DOCUMENT TITLE", a sample contents, sample sections), with
  the pictures and links only that sample used. Only the body's last section properties (`w:sectPr`) stay.
- **The content in the template's built-in styles:** `Title` and `Subtitle` (the cover), `Heading1`..`Heading6`,
  `Normal` (text), `ListParagraph` (lists; their numbering after the template's own), `TableGrid` (tables),
  `TOCHeading` (the contents' heading; the contents a Word TOC field). Found by their names, so a template in
  another Word language works too.
- **Built by LazySpec itself** (no Word or pandoc needed); Word, when it's there, fills in the contents' page
  numbers (else: right-click the contents in Word, Update Field).
- **Set, but missing or not a .docx:** the export stops with an error naming the resolved path (exit code 1),
  never the default look.
- **Fonts:** the ones the template sets or declares that this PC lacks are named in a warning (Word puts
  others in their place until they are installed).
- Not set: Word documents as before. PDF and HTML don't use the template.

Tests: `.\tests\Test-WordTemplate.ps1` (in the LazySpec repository).

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

**In the project's OpenSpec config** (`openspec/config.yaml`, under `lazyspec:`; the OpenSpec CLI ignores
it), the export's settings that belong to the specification; they win over `lazyspec.json`:

```yaml
lazyspec:
  name: Nava – Backoffice i javni API      # on the cover, instead of the folder's name
  client: Nava d.o.o.                      # also: subtitle, author, language
  documentTemplate: openspec_artifacts/Document template.docx   # Word documents on it (see Export)
  documentTheme: openspec_artifacts/theme/document-theme.yaml    # PDF, Word and HTML in that look (see Export)
  titles:                                  # a capability's (or spec's) title in the export
    add-charter-reservation-payment:       # a group per change (its folder's name): for that change
      reservation-booking: Rezervacija bookinga
    fix-mmk-extras-import:
      mmk-extras-import: Uvoz dodataka iz MMK-a
    platform-overview: Pregled platforme   # straight under titles: for every change, and for specs
```

A capability's title: its change's group first, then the ones straight under `titles`, then its name.

**Saved wholes** (`bundles:`): changes that go to the client as one document; see
[Several changes as one](#export-for-the-client).

**Diagrams** (`diagrams:`, grouped as `titles`): a FigJam (or Figma) section, or an image file, at the top
of what it belongs to. `change` in a change's group: the whole change's diagram, at the top of its
specifications; a capability's: at the top of the capability, before its purpose; straight under
`diagrams`, by a spec's name: at the top of that spec's chapter.

```yaml
lazyspec:
  diagrams:
    add-charter-reservation-payment:
      change: https://www.figma.com/board/<file>/<name>?node-id=18-350      # FigJam: Copy link to selection
      reservation-availability: https://www.figma.com/board/<file>/<name>?node-id=35-2839
      reservation-booking: diagrams/booking.png                               # or an image, in the change's folder
```

A Figma link is saved as a PNG in the change's `diagrams\` folder (`openspec\diagrams\` for specs), as
`<name>.<node>.png`, its margins cut (a FigJam section's background and frame and the space around its part
of the process). Every diagram of a change from the same Figma file is shown at the scale of the change's
whole diagram (`change`; the one at which that fits the page): the boxes as large in all of them. Without a
whole diagram: two thirds of its size on the board. Commit it, and the export
works without Figma, for everyone. In PDF and HTML the images are inside the document; Word embeds them too.

**Every export** (PDF, Word, HTML; the UI and the command line), for each diagram:

- with a Figma token: the latest from Figma; when that fails, the saved image (a refused token is tried once);
- without one: the saved image;
- no saved image: no diagram (the output says so).

The token: a Figma personal access token (Figma: Settings, Security, Personal access tokens; read access to
file content is enough, give it an expiry), `figmaToken:` under `lazyspec:` in `openspec/config.yaml`, else
`FIGMA_TOKEN` (`[Environment]::SetEnvironmentVariable('FIGMA_TOKEN', '<token>', 'User')`). config.yaml is in
git: everyone with the repository can use that token; `FIGMA_TOKEN` keeps it on your PC.

With a token and diagrams, the UI asks last: the latest from Figma (`d`), or the saved ones (`s`). The
command line: `-KeepDiagrams` the saved ones only (no Figma), `-RefreshDiagrams` the latest in any case.

**Small contents** in the export: at the top of the specifications, the capabilities; under a section
with requirements (*Novi zahtjevi* ...), its requirements; under a requirement, its scenarios on one line,
comma-separated. All of them links within the document (in PDF and Word too).

`export` — the cover page of an export, all optional: `title` (default: the project folder's name),
`subtitle` (`Specification`, in the export's language), `client` (none), `author` (`Netmedia`), `language`
(when the workflow schema has none), `titles` (capability or spec name → its title in the export).

## The kit

| File | What |
|---|---|
| `tools/lazyspec/lazyspec.ps1` | The program |
| `tools/lazyspec/lazyspec.exe` | Starts it (also in the project's root) |
| `tools/lazyspec/kit.json` | Version and the kit's files |
| `tools/lazyspec/LAZYSPEC.md` | This |
| `tools/lazyspec/export-texts.json` | The export's texts and OpenSpec's headings per language (en, hr, de, nl; `-AddLanguage` adds more) |

Put into a project and updated by `initintoproject.ps1` of the LazySpec repository
(`.\initintoproject.ps1 <project> [-Update]`). Commit `tools/lazyspec/` and `lazyspec.exe`: everyone
gets it with the project. `-Remove` takes it out again, for LazySpec installed on the PC (`install.exe`):
the settings move to `lazyspec.json` in the project's root.

Testing: `lazyspec.ps1 -Keys "Down,Enter,snap" -Frames frames.txt [-Width 120 -Height 36]` presses keys
without a console and writes the screens as text.

---

LazySpec is developed by **Netmedia**  ·  https://netmedia.agency  ·  netmedia@netmedia.hr

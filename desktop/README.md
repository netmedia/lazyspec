# LazySpec for Claude

A project's OpenSpec as tools for Claude: in **Claude Desktop** (Chat and Cowork) as the extension
`lazyspec.mcpb`, in **Claude Code** as the plugin `lazyspec`. The same reading and writing of `openspec/` as the
terminal app and the VS Code extension: it bundles their code (`vscode/src/model.ts`, `ops.ts`).

Made for product managers: refine, clarify and investigate specs with Claude, without an editor, a terminal or git.

## What Claude can do with it

| | Tools |
|---|---|
| Look around | `about`, `list_projects`, `project_context`, `list_plan`, `list_specs`, `read_document`, `find` |
| Write | `new_change`, `instructions` (a document's template), `write_document`, `edit_document`, `tick_task`, `remove_items`, `change_spec_requirement` |
| Keep it right | `out_of_date`, `mark_in_sync`, `validate`, `archive_change`, `undo_list`, `undo` |
| Investigate the code (read-only) | `search_code`, `read_code` |
| Process files outside the specs | `write_file` (the export folder's sources, the team's shared knowledge), `list_exports` |
| Netmedia tools | `run_tool`: the Netmedia plugins' scripts (estimate, offer and project plan preparation, offer, document, translate, hasek) - the same scripts Claude Code runs |
| Git, for people who don't use git | `git_status`, `get_latest`, `save` (commits `openspec/` and the shared knowledge, on a `spec/...` branch, pushes, opens a pull request) |
| For the client | `export_document` (PDF, Word, HTML in the company look, into the export folder) |

Prompts: **refine**, **clarify**, **investigate** (in Claude's `+` / slash menu).

**The export folder** is `netmedia: exportDir:` in `openspec/config.yaml` - the one setting every Netmedia tool reads
(`lazyspec: exportDir:` still works for older projects); default `openspec/exports/`. Spec exports, estimate
workbooks, offers and documents all go there.

The guards - the same list on every surface (Claude Code follows it through the skills):
- Writing is allowed under `openspec/` (not in the export folder or archived changes), and with `write_file` /
  `edit_document` in two more places: the export folder (Markdown, JSON, YAML and CSV sources of exports; documents
  come from `export_document` and `run_tool`) and the team's shared knowledge (`.claude/offers.yaml`,
  `.claude/estimates/`, `.claude/rules/*-profile.md` and `*-gotchas.md`).
- `run_tool` runs only its listed scripts, without a shell, in the project folder; every path in its arguments must
  stay inside the project and must not be a secret.
- A main spec's requirements and scenarios are changed only through a change (MODIFIED / REMOVED), as OpenSpec wants.
- The code is read-only.
- Files that may hold secrets (`.env`, keys, publish profiles, `local.settings.json`...) are never read.
- `save` commits `openspec/` and the shared knowledge, never the export folder or code.

The tools are generic. How a company runs its process (Netmedia: the `netmedia` plugin, the same for Claude Code and Claude Desktop) is in skills, not here.

## Install

**Claude Desktop:** download `lazyspec.mcpb` from the [releases](https://github.com/netmedia/lazyspec/releases) and
double-click it. Alternatively, an organization Owner can add it under *Organization settings → Connectors → Desktop*
so everyone gets it. Then choose the **projects folder**, where your git repositories are (e.g. GitHub Desktop's).
It brings its own OpenSpec CLI. For exports it needs PowerShell (built into Windows; on macOS `brew install powershell`).
For `run_tool` it needs Python with `python-docx`, `openpyxl`, `pyyaml` and `pillow`: the Netmedia environment
`~/.netmedia/python` (the team onboarding; the same on Windows and macOS), else `py -3` / `python3`. `about` shows
whether it is there and where each tool's script comes from: `NETMEDIA_PLUGINS` (a folder with the plugins), the
plugins installed in Claude Code (`~/.claude/plugins`), else the copy bundled in the extension.
For `save` it needs git with access to the repository, and for pull requests the GitHub CLI (`gh auth login`); without
`gh` you get a link to open the pull request.

**Claude Code:** from the `netmedia` marketplace: `/plugin install lazyspec@netmedia`. It works on the folder Claude
Code is started in, and uses the OpenSpec CLI on PATH.

## Build

```
cd desktop
npm install
npm run check     # typecheck
npm test          # build dist/server.js, then end-to-end tests over stdio on a copy of examples/acme-portal
npm run pack      # lazyspec.mcpb: manifest (tools and prompts asked from the server), server, exporter, OpenSpec CLI,
                  # and the Netmedia tools copied from AIToolbelt (NETMEDIA_AITOOLBELT, else ../AIToolbelt)
```

The tests run `run_tool` against AIToolbelt's plugins when AIToolbelt is cloned next to this repository. The
Netmedia tools in the extension are a generated copy (`server/netmedia/SOURCE.txt` names the commit): change them
in AIToolbelt, never here.

`dist/server.js` is committed: the Claude Code plugin runs it from this repository. CI checks that it matches the sources.

## Release

1. Set the version in `desktop/package.json` (the build puts it in `.claude-plugin/plugin.json` and the manifest).
2. `npm test --prefix desktop` and commit (with `desktop/dist/` and `.claude-plugin/`).
3. Tag `v<version>` and push it. CI:
   - builds `lazyspec.mcpb` (with the Netmedia tools from AIToolbelt's `develop`, through `AITOOLBELT_TOKEN`) and
     `lazyspec.vsix` and creates the GitHub release;
   - opens a pull request in AIToolbelt that pins the `lazyspec` marketplace entry to this tag's commit
     (`desktop/scripts/pin-marketplace.js`). It merges by itself once AIToolbelt's checks pass, if auto-merge is on
     there, and the merge syncs the organization's marketplace (Claude Code, Cowork). This needs the
     `AITOOLBELT_TOKEN` secret; without it, CI warns, and you pin the entry yourself.
4. Claude Desktop Chat: an Owner chooses *Organization settings → Connectors → Desktop → ⋯ → Upload new version* with
   the release's `lazyspec.mcpb`. The name stays `lazyspec` and the version goes up; a new name would make a second
   extension.

Until the first release, the marketplace has no `lazyspec` entry: try the plugin with
`claude --plugin-dir <this repository>`.

Tool names are a contract with the skills that use them (`netmedia`: `conventions-pm` → `references/tools.md`). Only add tools and optional parameters. To
change one, add `<name>_v2`, move the skills over, and remove the old one a release or two later.

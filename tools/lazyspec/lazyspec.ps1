#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  lazyspec.ps1                                              |
#  |   The terminal UI of a project's OpenSpec specifications and changes     |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
LazySpec by Netmedia: the terminal UI of a project's OpenSpec specifications and changes (openspec/).

.AUTHOR
Netmedia  |  https://netmedia.agency  |  netmedia@netmedia.hr

.DESCRIPTION
Shows a project's specifications (openspec/specs/) and changes (openspec/changes/) in one screen: the
specs with their requirements, the changes with their stage, task progress, capabilities and tasks, and
reads any of them in full (proposal, design, tasks, delta specs). Runs the OpenSpec CLI for the rest
(validate, archive, new change) and shows its output in the same screen.

Reading needs nothing but the files; the actions need the OpenSpec CLI (npm i -g @fission-ai/openspec).
Self-contained: Windows PowerShell 5.1 or PowerShell 7, no modules. A terminal with ANSI colours and box
characters (Windows Terminal; the Windows console since Windows 10).

Keys (? shows them in the UI too)
  Home   up/down item, Tab specs <-> changes, right: into the details (up/down scroll them), left/Esc back,
         z zoom the details (whole width; z again: the lists back), Enter read it, PgUp/PgDn scroll the details,
         v validate all, a archive the change, n new change, e edit (open in the editor),
         s sort changes, h show/hide archived, / filter, r refresh, ? help, q quit
  Read   up/down/PgUp/PgDn/Home/End scroll, left/right document (proposal, design, tasks, specs),
         e edit, Esc back
  Run    PgUp/PgDn/Home/End scroll the output, Esc stop (asked first); when done: Enter or Esc back

.PARAMETER Help
Shows the usage guide (screens, keys, commands) and exits.

.PARAMETER Root
The project's root (the folder with openspec/). Default: the nearest one above the current folder, else
above this script.

.PARAMETER Install
Makes plain `lazyspec` work in PowerShell (as lazygit does), then exits. Profile: adds a lazyspec
function to your PowerShell profiles that starts the nearest project's own lazyspec.exe. Global: copies
LazySpec to %LOCALAPPDATA%\Programs\LazySpec and puts that folder on your user PATH. Both: the function
runs the project's copy when there is one, else the global one. Run from the LazySpec repository (its
install.exe does), Profile alone falls back to the repository's copy: nothing goes into the projects.

.PARAMETER Uninstall
Removes what -Install added (the profile function and the global copy with its PATH entry), then exits.

.PARAMETER Export
Exports the specification (every spec in openspec/specs, in the Scope order) as one document for the
client, then exits: Pdf (through Microsoft Edge or Google Chrome), Word (through Microsoft Word, else
pandoc) or Html. A cover page, the contents, a chapter per spec. The cover's texts: lazyspec.json "export".

.PARAMETER Out
-Export: the file to write. Default: export\<project>-specification-<date>.<pdf|docx|html> in the project.

.PARAMETER Item
-Export: only this spec or change (its folder's name): the spec, or the change with every document of its
workflow (proposal, delta specs, design, tasks ...). Default file: export\<project>-<item>-<date>.<ext>.

.PARAMETER IncludeChanges
-Export: adds the plan, the active changes (their proposal and delta specs), after the specs.

.PARAMETER ClientFriendly
-Export: for the client: a scenario's WHEN / THEN steps as one sentence ("When x, then y."), without the
normative keywords in brackets ("(MUST)"). The export's language (its texts and OpenSpec's English
headings): the workflow schema's "language:" (e.g. hr), else lazyspec.json export.language, else en.

.PARAMETER Language
-Export: the export in this language (en, hr, de, nl ...). Another than the documents' own: LazySpec's texts
in it (export-texts.json) and the documents translated by DeepL - "translation: provider: deepl" in
openspec/config.yaml, the key in DEEPL_AUTH_KEY (never in config.yaml). Translations are cached per user.
Into Croatian: checked by Hasek (ispravi.me) too, a report next to the document (translation: hasek).

.PARAMETER Beta
-Export -Language / -AddLanguage: yes to a DeepL beta language (an additional language such as Croatian:
no glossary, no formal/informal tone, often translated piece by piece). Without it LazySpec asks (a console)
or stops with the reason.

.PARAMETER AddLanguage
Adds a language to export-texts.json (LazySpec's texts and OpenSpec's English headings), translated from
English by DeepL, then exits. -Force replaces one that is there. Have it read by a native speaker; commit it.

.PARAMETER Force
-AddLanguage: replace the language's block when export-texts.json already has it.

.PARAMETER RefreshDiagrams
-Export: the diagrams ("lazyspec: diagrams:" in openspec/config.yaml, Figma links) the latest from Figma,
through its REST API with a personal access token ("lazyspec: figmaToken:" in config.yaml, or FIGMA_TOKEN).
With a token that is what an export does anyway; when a download fails, the saved image is used.

.PARAMETER KeepDiagrams
-Export: the saved diagrams only, even with a token: no Figma. A diagram without a saved image is left out.

.PARAMETER Template
-Export Word: the Word template (.docx) to build the document on, relative to the current folder; wins over
"lazyspec: documentTemplate:" in openspec/config.yaml (relative to the project's root). The template's
styles, page setup, headers and footers (with their logos) stay, its sample body goes; the content uses its
Title, Subtitle, Heading1..6, Normal, ListParagraph, TableGrid and TOCHeading styles. Set but missing or not
a .docx: an error, never the default look.

.PARAMETER Theme
-Export: the document theme (.yaml) for the look of PDF, Word and HTML, relative to the current folder; wins
over "lazyspec: documentTheme:" in openspec/config.yaml (relative to the project's root). Its fonts: the
files in fonts\ next to it (embedded in Word). Set but missing or broken: an error, never the default look.
See examples\document-theme\document-theme.yaml in the LazySpec repository.

.PARAMETER Markdown
-Export: a Markdown file (meeting notes, a summary, a letter ...) as the document, instead of the
specification: in the project's look (its theme or template), as PDF, Word or HTML; written next to it
(-Out: elsewhere). Its front matter: title, subtitle, client, author, date, language, toc (true: a contents
of its headings 1-2), cover (false: the title on the first page, no cover page). No title there: its first
"# " heading, else the file's name.

.PARAMETER Open
-Export: opens the document when it's written.

.PARAMETER Keys
Testing: keys to press instead of the keyboard, comma-separated (Up, Down, Left, Right, Enter, Esc, Tab,
PgUp, PgDn, Home, End, Back, Space, a single character, text:<chars>, wait:done, snap).
Nothing is drawn on the console; frames go to -Frames.

.PARAMETER Frames
Testing: a text file that gets the screen (without colours) at every 'snap' and at the end.

.PARAMETER Width
Testing: the screen's width (default 120).

.PARAMETER Height
Testing: the screen's height (default 36).

.EXAMPLE
.\lazyspec.exe

.EXAMPLE
.\tools\lazyspec\lazyspec.ps1 -Root D:\Development\Netmedia\MyProject

.EXAMPLE
.\lazyspec.exe -Install Profile

.EXAMPLE
.\lazyspec.exe -Export Pdf -IncludeChanges -Open

.EXAMPLE
lazyspec -Export Word -Markdown "openspec_meetings\2026-11-04 meeting.md"

.EXAMPLE
.\lazyspec.exe -Export Pdf -Item add-user-login -Open

.NOTES
LazySpec is a Netmedia product: https://netmedia.agency, netmedia@netmedia.hr,
https://github.com/netmedia/lazyspec.

.LINK
tools/lazyspec/LAZYSPEC.md
#>
[CmdletBinding()]
param(
    [Alias('h')]
    [switch]$Help,
    [string]$Root,
    [string[]]$Install,
    [switch]$Uninstall,
    [ValidateSet('Pdf', 'Word', 'Html')]
    [string]$Export,
    [string]$Out,
    [string[]]$Item,
    [string]$Title,
    [switch]$IncludeChanges,
    [switch]$ClientFriendly,
    [switch]$RefreshDiagrams,
    [switch]$KeepDiagrams,
    [string]$Template,
    [string]$Theme,
    [string]$Markdown,
    [string]$Language,
    [switch]$Beta,
    [string]$AddLanguage,
    [switch]$Force,
    [switch]$Open,
    [string]$Keys,
    [string]$Frames,
    [int]$Width = 0,
    [int]$Height = 0
)

$ErrorActionPreference = 'Stop'
$kitDir = $PSScriptRoot
$E = [char]27

# --- Netmedia: who made it, how to use it ---------------------------------------------------------------

$kitVersion = ''
if (Test-Path (Join-Path $kitDir 'kit.json')) { $kitVersion = (Get-Content (Join-Path $kitDir 'kit.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version }

function Show-Author {
    $width = 64
    $hLine = [string]::new([char]0x2500, $width)
    $v = [char]0x2502
    function Row([string]$display, [string]$measure = $display, [string]$color = 'White') {
        $pad = [Math]::Max(0, $width - $measure.Length)
        $left = [Math]::Floor($pad / 2)
        Write-Host "  $v" -NoNewline -ForegroundColor Cyan
        Write-Host "$(' ' * $left)$display$(' ' * ($pad - $left))" -NoNewline -ForegroundColor $color
        Write-Host $v -ForegroundColor Cyan
    }
    $title = 'LazySpec  -  lazyspec.ps1'
    Write-Host ''
    Write-Host "  $([char]0x256D)$hLine$([char]0x256E)" -ForegroundColor Cyan
    Row ''
    Row "$E[1m$title$E[0m" $title 'Cyan'
    Row 'The terminal UI of a project''s OpenSpec specs and changes' -color 'White'
    Row ''
    Row "by Netmedia$(if ($kitVersion) { "  |  LazySpec $kitVersion" })" -color 'DarkGray'
    Row 'https://netmedia.agency  |  netmedia@netmedia.hr' -color 'DarkGray'
    Row ''
    Write-Host "  $([char]0x2570)$hLine$([char]0x256F)" -ForegroundColor Cyan
    Write-Host ''
}

function Show-Usage {
    $hr = '  ' + [string]::new([char]0x2500, 66)
    $b = { param($t) Write-Host "  $t" -ForegroundColor White }
    $d = { param($t) Write-Host "  $t" -ForegroundColor DarkGray }
    $g = { param($t) Write-Host "  $t" -ForegroundColor Green }
    $y = { param($t) Write-Host "  $t" -ForegroundColor Yellow }
    & $b 'USAGE'
    & $g '  .\lazyspec.exe   or   .\tools\lazyspec\lazyspec.ps1  [-Root <project>]'
    & $d '  Run anywhere inside a project with an openspec\ folder, in Windows Terminal (or the'
    & $d '  Windows console), at least 70 x 20. Reading needs only the files; validate, archive'
    & $d '  and new change run the OpenSpec CLI (npm i -g @fission-ai/openspec).'
    Write-Host ''
    & $b 'SCREENS'
    & $y '  Home'
    & $d '    The specifications and the changes (stage, task progress), and the selected one''s'
    & $d '    details: a spec''s purpose and requirements; a change''s why, what changes,'
    & $d '    capabilities (added, modified, removed requirements) and tasks by group.'
    & $y '  Read'
    & $d '    A spec or a change in full: proposal, design, tasks and delta specs, formatted.'
    & $y '  Run'
    & $d '    The OpenSpec CLI''s output: validate, archive, new change.'
    & $y '  Help'
    & $d '    ? on Home or Read: keys, commands, who made it.'
    Write-Host ''
    & $b 'KEYS'
    & $y '  Home'
    & $d '    Up/Down item, Tab specs <-> changes, Right into the details (Up/Down scroll), Left back'
    & $d '    z zoom the details to the whole width (z again: the lists back)'
    & $d '    Enter read it, PgUp/PgDn/Home/End scroll the details'
    & $d '    v validate all   a archive the change   n new change   e edit   s sort changes'
    & $d '    m changes as one (mark them with Space, Enter: a title, then read them; x there: export)'
    & $d '    h show/hide archived   / filter   r refresh   ? help   q quit'
    & $y '  Read'
    & $d '    Up/Down PgUp/PgDn Home/End scroll   Left/Right document   e edit   Esc back'
    & $y '  Run'
    & $d '    PgUp/PgDn Home/End scroll   Esc stop (asked first); when done: Enter or Esc back'
    Write-Host ''
    & $b 'WHAT THE ACTIONS RUN'
    & $d '  v  openspec validate --all --strict --no-interactive'
    & $d '  a  openspec archive <change> --yes                  asked first'
    & $d '  n  openspec new change <name>                       the name is asked'
    & $d '  e  $env:VISUAL / $env:EDITOR, else VS Code (code), else the file''s default app'
    Write-Host ''
    & $b 'EXAMPLES'
    & $g '  # From the project''s root'
    & $g '  .\lazyspec.exe'
    Write-Host ''
    & $g '  # Another project'
    & $g '  .\tools\lazyspec\lazyspec.ps1 -Root D:\Development\Netmedia\MyProject'
    Write-Host ''
    & $b 'EXPORT FOR THE CLIENT (x in the UI)'
    & $g '  .\lazyspec.exe -Export Pdf                     # or Word, Html'
    & $g '  .\lazyspec.exe -Export Word -IncludeChanges -Open'
    & $g '  .\lazyspec.exe -Export Pdf -Item add-user-login   # one spec or change (x in Read)'
    & $g '  .\lazyspec.exe -Export Word -Item add-user-signup,add-online-payments -Title "Online payments"'
    & $d '  Several changes as one whole (m, or x: chosen changes): a chapter per kind of document, each'
    & $d '  change''s part under its title; -Title on the cover (else the changes'' titles). m saves it as a'
    & $d '  named whole (lazyspec: bundles: in openspec\config.yaml): then -Item <its key>.'
    & $d '  One document: a cover, the contents, a chapter per spec (in the Scope order); with'
    & $d '  -IncludeChanges the active changes too. Written to export\ in the project (-Out: elsewhere).'
    & $d '  PDF: Edge or Chrome. Word: Microsoft Word, else pandoc. The cover: lazyspec.json "export".'
    & $d '  -ClientFriendly: scenarios as sentences (When x, then y.). In the workflow schema''s language:'
    & $d '  "language: hr" in schema.yaml translates the export''s texts and OpenSpec''s English headings.'
    & $d '  Diagrams: lazyspec: diagrams: in openspec\config.yaml (FigJam links; -RefreshDiagrams, FIGMA_TOKEN).'
    & $d '  Word in the company layout: lazyspec: documentTemplate: <a .docx, from the project root> in'
    & $d '  openspec\config.yaml, or -Template <path> (wins). Missing or broken: an error, not the default look.'
    & $d '  One look in PDF, Word and HTML: lazyspec: documentTheme: <a .yaml>, or -Theme <path>; its fonts in'
    & $d '  fonts\ next to it (embedded in Word). A template and a theme: Word uses the template.'
    Write-Host ''
    & $b 'IN ANOTHER LANGUAGE (DeepL)'
    & $g '  lazyspec -Export Pdf -Language en                # the documents translated, the texts in English'
    & $g '  lazyspec -Export Word -Language hr -Beta         # a DeepL beta language: -Beta (else it asks)'
    & $g '  lazyspec -AddLanguage it                         # LazySpec''s texts for a new language'
    & $d '  openspec\config.yaml: translation: provider: deepl (keyEnv, english, formality, hasek); the key in'
    & $d '  DEEPL_AUTH_KEY, never in config.yaml. Into Croatian: a Hasek (ispravi.me) report next to the document.'
    Write-Host ''
    & $b 'ANY MARKDOWN AS A DOCUMENT (meeting notes, summaries ...)'
    & $g '  lazyspec -Export Word -Markdown "openspec_meetings\2026-11-04 summary.md"   # or Pdf, Html'
    & $d '  In the look of the project the file is in; written next to it. Front matter: title, subtitle,'
    & $d '  client, author, date, language, toc: true (a contents), cover: false (no cover page).'
    Write-Host ''
    & $b 'PLAIN lazyspec (WITHOUT .\)'
    & $g '  .\lazyspec.exe -Install Profile    # a function in your profile: the project''s own copy'
    & $g '  .\lazyspec.exe -Install Global     # a copy on your PATH, like lazygit'
    & $g '  .\lazyspec.exe -Install Both       # both: the project''s copy first, else the global one'
    & $g '  .\lazyspec.exe -Uninstall          # removes them'
    & $d '  Then open a new terminal. Without putting LazySpec into projects: install.exe in the LazySpec'
    & $d '  repository (Profile, Global, Both); the projects'' settings then go into <project>\lazyspec.json.'
    Write-Host ''
    & $b 'MORE'
    & $d '  tools\lazyspec\LAZYSPEC.md   the screens, the conventions (platform-* specs), the kit'
    Write-Host $hr -ForegroundColor Cyan
    Write-Host ''
}

if ($Help) {
    Show-Author
    Show-Usage
    exit 0
}

# --- -Install / -Uninstall: plain `lazyspec` in PowerShell ----------------------------------------------

# Per-user data: %LOCALAPPDATA% on Windows, ~/Library/Application Support on macOS (.NET's LocalApplicationData).
$localData = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { [Environment]::GetFolderPath('LocalApplicationData') }
$globalDir = Join-Path $localData 'Programs\LazySpec'
$profileBegin = '# >>> LazySpec (Netmedia) >>>'
$profileEnd = '# <<< LazySpec (Netmedia) <<<'
# The lazyspec function: the nearest project's own copy, else the installed one ($Installed: this
# repository's or the global copy's lazyspec.exe), else one on PATH.
function Get-ProfileBlock([string]$Installed) {
    $fallback = ''
    if ($Installed) {
        $fallback = @"

    # Installed LazySpec: for projects without their own copy.
    `$installed = '$($Installed.Replace("'", "''"))'
    if (Test-Path -LiteralPath `$installed) { & `$installed @args; return }
"@
    }
    return @"
$profileBegin
# lazyspec: the nearest project's own lazyspec.exe (this folder or above), else the installed one.
# Added by lazyspec -Install Profile (or install.exe in the LazySpec repository); -Uninstall removes it.
function lazyspec {
    `$d = (Get-Location).ProviderPath
    while (`$d) {
        foreach (`$p in 'lazyspec.exe', 'tools\lazyspec\lazyspec.exe') {
            `$exe = Join-Path `$d `$p
            if (Test-Path -LiteralPath `$exe) { & `$exe @args; return }
        }
        `$d = Split-Path `$d -Parent
    }$fallback
    `$onPath = Get-Command lazyspec.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (`$onPath) { & `$onPath.Source @args; return }
    Write-Error 'LazySpec: no lazyspec.exe in this folder or above, and none installed.'
}
$profileEnd
"@
}

# The current-user, all-hosts profiles: Windows PowerShell 5.1, and PowerShell 7 when it's there.
function Get-ProfilePaths {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $paths = @(Join-Path $docs 'WindowsPowerShell\profile.ps1')
    $ps7 = Join-Path $docs 'PowerShell'
    if ((Test-Path -LiteralPath $ps7) -or (Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        $paths += Join-Path $ps7 'profile.ps1'
    }
    return $paths
}

function Remove-ProfileBlock([string]$Text) {
    $pattern = '(?s)\r?\n?' + [regex]::Escape($profileBegin) + '.*?' + [regex]::Escape($profileEnd) + '\r?\n?'
    return [regex]::Replace($Text, $pattern, "`r`n").Trim()
}

# The user PATH, read and written raw (REG_EXPAND_SZ: %USERPROFILE% and the like stay as they are).
function Get-UserPath {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    try { return [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
    finally { $key.Close() }
}
function Set-UserPath([string]$Value) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    try { $key.SetValue('Path', $Value, [Microsoft.Win32.RegistryValueKind]::ExpandString) }
    finally { $key.Close() }
    # Tell Explorer (and the terminals it starts) that the environment changed.
    if (-not ('LazySpec.Env' -as [type])) {
        Add-Type -Namespace LazySpec -Name Env -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
    }
    $result = [UIntPtr]::Zero
    [void][LazySpec.Env]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}
function Test-SameDir([string]$A, [string]$B) {
    # A PATH can hold entries that aren't paths (":\Users\...", quotes): those are just text, never ours.
    $full = { param([string]$P) try { [IO.Path]::GetFullPath($P.Trim().Trim('"')).TrimEnd('\') } catch { $P.Trim().Trim('"').TrimEnd('\') } }
    if (-not $A.Trim() -or -not $B.Trim()) { return $false }
    return (& $full $A) -ieq (& $full $B)
}

function Install-Profile([string]$Installed) {
    $block = Get-ProfileBlock $Installed
    foreach ($path in Get-ProfilePaths) {
        $text = ''
        if (Test-Path -LiteralPath $path) { $text = Remove-ProfileBlock (Get-Content -LiteralPath $path -Raw -Encoding UTF8) }
        else { [void](New-Item -ItemType Directory -Force -Path (Split-Path $path -Parent)) }
        if ($text) { $text += "`r`n`r`n" }
        [IO.File]::WriteAllText($path, $text + $block.Replace("`r`n", "`n").Replace("`n", "`r`n") + "`r`n", (New-Object Text.UTF8Encoding $true))
        Write-Host "  + the lazyspec function in $path" -ForegroundColor Green
    }
    if ($Installed) { Write-Host "    it runs the project's own copy, else $Installed" -ForegroundColor DarkGray }
    else { Write-Host "    it runs the project's own copy (the nearest lazyspec.exe above the current folder)" -ForegroundColor DarkGray }
    # A profile only loads when the execution policy lets local scripts run (Windows PowerShell's default doesn't).
    $policy = 'Undefined'
    foreach ($scope in 'MachinePolicy', 'UserPolicy', 'CurrentUser', 'LocalMachine') {
        $p = [string](Get-ExecutionPolicy -Scope $scope)
        if ($p -ne 'Undefined') { $policy = $p; break }
    }
    if ($policy -in 'Undefined', 'Restricted', 'AllSigned') {
        Write-Host "  ! The execution policy ($policy) stops PowerShell from loading profiles. Allow local scripts once:" -ForegroundColor Yellow
        Write-Host '      Set-ExecutionPolicy -Scope CurrentUser RemoteSigned' -ForegroundColor Yellow
    }
}

# The kit's files (kit.json "files"), copied from here into the global folder.
function Copy-ToGlobal {
    $files = @()
    try { $files = @((Get-Content -LiteralPath (Join-Path $kitDir 'kit.json') -Raw -Encoding UTF8 | ConvertFrom-Json).files | Where-Object { $_ }) } catch { }
    if (-not $files.Count) { $files = @('lazyspec.exe', 'lazyspec.ps1', 'kit.json', 'LAZYSPEC.md', 'export-texts.json') }
    [void](New-Item -ItemType Directory -Force -Path $globalDir)
    foreach ($f in $files) {
        $src = Join-Path $kitDir $f
        if (-not (Test-Path -LiteralPath $src)) { continue }
        try { Copy-Item -LiteralPath $src -Destination (Join-Path $globalDir $f) -Force }
        catch { throw "$f in $globalDir`: $($_.Exception.Message) (is lazyspec running? close it and run this again)" }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $globalDir 'lazyspec.exe'))) { throw "lazyspec.exe is missing next to $PSCommandPath." }
}
function Get-GlobalVersion {
    try { return [string](Get-Content -LiteralPath (Join-Path $globalDir 'kit.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version } catch { return '' }
}

function Install-Global {
    if (-not (Test-SameDir $kitDir $globalDir)) {
        Copy-ToGlobal
        Write-Host "  + LazySpec$(if ($kitVersion) { " $kitVersion" }) copied to $globalDir" -ForegroundColor Green
    }
    Add-GlobalToPath
}
function Add-GlobalToPath {
    $entries = @((Get-UserPath) -split ';' | Where-Object { $_ })
    if (-not ($entries | Where-Object { Test-SameDir ([Environment]::ExpandEnvironmentVariables($_)) $globalDir })) {
        Set-UserPath (($entries + $globalDir) -join ';')
        Write-Host "  + $globalDir on your user PATH" -ForegroundColor Green
    }
    else { Write-Host "  = $globalDir is on your user PATH already" -ForegroundColor DarkGray }
}

# Update: the global copy from here (the LazySpec repository), and the profile function (keeping what it falls back to).
function Update-Installed {
    if (Test-SameDir $kitDir $globalDir) { throw 'Update from the LazySpec repository (install.exe Update): this is the global copy itself.' }
    $hasGlobal = Test-Path -LiteralPath (Join-Path $globalDir 'lazyspec.exe')
    $profiles = @(Get-ProfilePaths | Where-Object { (Test-Path -LiteralPath $_) -and ((Get-Content -LiteralPath $_ -Raw -Encoding UTF8) -match [regex]::Escape($profileBegin)) })
    if (-not $hasGlobal -and -not $profiles.Count) { throw 'LazySpec isn''t installed on this PC: install.exe Profile, Global or Both.' }
    if ($hasGlobal) {
        $before = Get-GlobalVersion
        Copy-ToGlobal
        $what = "LazySpec $kitVersion"
        if ($before -and $before -ne $kitVersion) { $what = "LazySpec $before -> $kitVersion" }
        elseif ($before) { $what = "LazySpec $kitVersion (the same version, its files refreshed)" }
        Write-Host "  + $what in $globalDir" -ForegroundColor Green
        Add-GlobalToPath
    }
    else { Write-Host "  = no global copy ($globalDir): install.exe Global puts one there" -ForegroundColor DarkGray }
    if ($profiles.Count) {
        # The function as this version writes it; what it falls back to stays.
        $m = [regex]::Match((Get-Content -LiteralPath $profiles[0] -Raw -Encoding UTF8), "(?m)^\s*\`$installed = '((?:[^']|'')*)'")
        $fallback = ''
        if ($m.Success) { $fallback = $m.Groups[1].Value.Replace("''", "'") }
        Install-Profile $fallback
    }
}

function Uninstall-All {
    foreach ($path in Get-ProfilePaths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $text = Get-Content -LiteralPath $path -Raw -Encoding UTF8
        if ($text -notmatch [regex]::Escape($profileBegin)) { continue }
        $left = Remove-ProfileBlock $text
        if ($left) { [IO.File]::WriteAllText($path, $left + "`r`n", (New-Object Text.UTF8Encoding $true)) }
        else { Remove-Item -LiteralPath $path -Force }
        Write-Host "  - the lazyspec function from $path" -ForegroundColor Green
    }
    $entries = @((Get-UserPath) -split ';' | Where-Object { $_ })
    $kept = @($entries | Where-Object { -not (Test-SameDir ([Environment]::ExpandEnvironmentVariables($_)) $globalDir) })
    if ($kept.Count -ne $entries.Count) {
        Set-UserPath ($kept -join ';')
        Write-Host "  - $globalDir from your user PATH" -ForegroundColor Green
    }
    if (Test-Path -LiteralPath $globalDir) {
        try {
            Remove-Item -LiteralPath $globalDir -Recurse -Force
            Write-Host "  - $globalDir" -ForegroundColor Green
        }
        catch {
            # Started from the global copy: its lazyspec.exe is still running. Delete the folder once it ends.
            Start-Process cmd.exe -ArgumentList "/c ping -n 3 127.0.0.1 >nul & rmdir /s /q `"$globalDir`"" -WindowStyle Hidden
            Write-Host "  - $globalDir (once this lazyspec ends)" -ForegroundColor Green
        }
    }
}

if ($Install -or $Uninstall) {
    Write-Host ''
    # The profile function and the global copy are Windows': lazyspec.exe, the user PATH in the registry.
    if ($env:OS -ne 'Windows_NT') {
        Write-Host '  -Install / -Uninstall (and install.ps1) are for Windows. On macOS: an alias in your shell, e.g. in ~/.zshrc' -ForegroundColor Yellow
        Write-Host "    alias lazyspec='pwsh -NoProfile -File $PSCommandPath'" -ForegroundColor Green
        Write-Host '  README.md, "Starting on macOS", has the rest.' -ForegroundColor DarkGray
        Write-Host ''
        exit 1
    }
    if ($Uninstall) { Uninstall-All }
    else {
        # "Profile,Global" arrives as one string through lazyspec.exe / install.exe (powershell -File).
        $modes = @($Install | ForEach-Object { $_ -split '[,\s]+' } | Where-Object { $_ })
        if ($modes -contains 'Both') { $modes = @('Profile', 'Global') }
        foreach ($m in $modes) { if ($m -notin 'Profile', 'Global', 'Update') { Write-Host "  -Install: Profile, Global, Both or Update, not '$m'." -ForegroundColor Red; exit 1 } }
        if ($modes -contains 'Update') {
            try { Update-Installed } catch { Write-Host "  $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
            Write-Host ''
            Write-Host '  Updated. A lazyspec that is open keeps the old version until it starts again.' -ForegroundColor White
            Write-Host ''
            exit 0
        }
        # The kit of a project is <project>\tools\lazyspec; else this is the repository's or the global copy.
        $inProject = Test-Path -LiteralPath (Join-Path (Split-Path (Split-Path $kitDir -Parent) -Parent) 'openspec') -PathType Container
        $installed = ''
        if ($modes -contains 'Global') { Install-Global; $installed = Join-Path $globalDir 'lazyspec.exe' }
        elseif (-not $inProject) { $installed = Join-Path $kitDir 'lazyspec.exe' }
        if ($modes -contains 'Profile') { Install-Profile $installed }
    }
    Write-Host ''
    Write-Host '  Open a new terminal for it to take effect.' -ForegroundColor White
    Write-Host ''
    exit 0
}

# --- the project ------------------------------------------------------------------------------------------

function Find-Root([string]$Start) {
    if (-not $Start) { return $null }
    $d = [IO.DirectoryInfo]$Start
    while ($d) {
        if (Test-Path -LiteralPath (Join-Path $d.FullName 'openspec') -PathType Container) { return $d.FullName }
        $d = $d.Parent
    }
    return $null
}
if ($Root) { $Root = [IO.Path]::GetFullPath($Root) }
else {
    # -Markdown: the project the file is in (its theme, template, settings), else the current folder's.
    if ($Markdown) { $md = $Markdown; if (-not [IO.Path]::IsPathRooted($md)) { $md = Join-Path (Get-Location).Path $md }; $Root = Find-Root (Split-Path ([IO.Path]::GetFullPath($md)) -Parent) }
    if (-not $Root) { $Root = Find-Root (Get-Location).Path }
    if (-not $Root) { $Root = Find-Root $kitDir }
}
$hasRoot = [bool]($Root -and (Test-Path -LiteralPath (Join-Path $Root 'openspec') -PathType Container))
$projectName = ''
if ($Root) { $projectName = Split-Path $Root -Leaf }
$osDir = ''
if ($hasRoot) { $osDir = Join-Path $Root 'openspec' }
$harness = [bool]($Keys -or $Frames)

# --- look -------------------------------------------------------------------------------------------

# Built from their code points: the file stays ASCII, which Windows PowerShell 5.1 reads right.
function C([int]$Code) { return [string][char]$Code }
$g = @{
    h = C 0x2500; v = C 0x2502; tl = C 0x256D; tr = C 0x256E; bl = C 0x2570; br = C 0x256F; lt = C 0x251C; rt = C 0x2524; tt = C 0x252C; bt = C 0x2534
    dot = C 0x25CF; ring = C 0x25CB; diamond = C 0x25C6; check = C 0x2713; cross = C 0x2717; arrow = C 0x2192; tri = C 0x25B8; ell = C 0x2026
    mid = C 0x00B7; bar = C 0x258C; caret = C 0x203A; cursor = C 0x2581; up = C 0x2191; down = C 0x2193; dash = C 0x2013; bullet = C 0x2022
    full = C 0x2588; light = C 0x2591; warn = C 0x26A0
}
$spinner = @(0x280B, 0x2819, 0x2839, 0x2838, 0x283C, 0x2834, 0x2826, 0x2827, 0x2807, 0x280F) | ForEach-Object { C $_ }
# SGR parameters (256 colours): the same palette as LazyBicep.
$st = @{
    text = ''; muted = '38;5;245'; faint = '38;5;240'; bold = '1'; accent = '38;5;75'; title = '1;38;5;117'; ok = '38;5;114'; warn = '38;5;221'
    err = '38;5;203'; shared = '38;5;141'; border = '38;5;239'; sel = '48;5;236'; key = '1;38;5;222'; danger = '1;38;5;203'; brand = '1;38;5;16;48;5;209'
    chip = '38;5;250;48;5;238'; chipOn = '1;38;5;16;48;5;75'; chipOk = '1;38;5;16;48;5;114'; chipFaint = '1;38;5;250;48;5;240'; chipShared = '1;38;5;16;48;5;141'
    chipDanger = '1;38;5;16;48;5;203'; head = '1;38;5;153'; code = '38;5;180'
    # Netmedia's signature: a coral bar and name, a teal underlined link.
    brandBar = '38;5;209'; brandName = '1;38;5;117'; netmedia = '1;38;5;209'; brandLink = '4;38;5;80'
}

# A piece of a line: text and style. A line is an array of them.
# A piece with a Link is a terminal hyperlink (OSC 8: Ctrl+click in Windows Terminal); it takes no columns.
function S([string]$T, [string]$Style = '', [string]$Link = '') { return [pscustomobject]@{ T = $T; S = $Style; Link = $Link } }
# A line cut or padded to exactly $W characters; $Bg (a background) under all of it.
function Fit($Segs, [int]$W, [string]$Bg = '') {
    $out = New-Object Collections.ArrayList
    $used = 0
    foreach ($s in @($Segs)) {
        if ($null -eq $s) { continue }
        $t = $s.T
        $style = $s.S
        if ($Bg) { if ($style) { $style = "$style;$Bg" } else { $style = $Bg } }
        $room = $W - $used
        if ($room -le 0) { break }
        if ($t.Length -gt $room) { $t = $t.Substring(0, $room - 1) + $g.ell }
        [void]$out.Add((S $t $style $s.Link))
        $used += $t.Length
    }
    if ($used -lt $W) { [void]$out.Add((S (' ' * ($W - $used)) $Bg)) }
    return , $out.ToArray()
}
function To-Ansi($Segs) {
    $sb = New-Object Text.StringBuilder
    foreach ($s in $Segs) {
        if ($s.Link) { [void]$sb.Append("$E]8;;$($s.Link)$E\") }
        if ($s.S) { [void]$sb.Append("$E[0;$($s.S)m").Append($s.T).Append("$E[0m") } else { [void]$sb.Append($s.T) }
        if ($s.Link) { [void]$sb.Append("$E]8;;$E\") }
    }
    return $sb.ToString()
}
function To-Plain($Segs) { return (-join @($Segs | ForEach-Object { $_.T })) }

# Words to lines of at most $Width.
function Wrap([string]$Text, [int]$Width) {
    if ($Width -lt 8) { $Width = 8 }
    $out = New-Object Collections.Generic.List[string]
    foreach ($para in ([string]$Text).Replace("`r", '').Split("`n")) {
        $lead = $para.Length - $para.TrimStart(' ').Length
        $indent = ' ' * [Math]::Min($lead, [int]($Width / 2))
        $room = $Width - $indent.Length
        $line = ''
        foreach ($word in $para.TrimStart(' ').Split(' ')) {
            if ($line.Length -eq 0) { $cand = $word } else { $cand = "$line $word" }
            if ($cand.Length -le $room) { $line = $cand; continue }
            if ($line.Length) { $out.Add($indent + $line) }
            while ($word.Length -gt $room) { $out.Add($indent + $word.Substring(0, $room)); $word = $word.Substring($room) }
            $line = $word
        }
        $out.Add($indent + $line)
    }
    return , $out.ToArray()
}
function Pad([string]$Text, [int]$Len) { if ($Text.Length -ge $Len) { return $Text } return $Text + (' ' * ($Len - $Text.Length)) }
function PadL([string]$Text, [int]$Len) { if ($Text.Length -ge $Len) { return $Text } return (' ' * ($Len - $Text.Length)) + $Text }
function Short([string]$Text, [int]$Len) { if ($Text.Length -le $Len) { return $Text } return $Text.Substring(0, [Math]::Max(1, $Len - 1)) + $g.ell }
function Ago($When) {
    if (-not $When) { return '-' }
    $s = [int]((Get-Date) - $When).TotalSeconds
    if ($s -lt 60) { return 'just now' }
    if ($s -lt 3600) { return "$([int][Math]::Floor($s / 60))m" }
    if ($s -lt 86400) { return "$([int][Math]::Floor($s / 3600))h" }
    return "$([int][Math]::Floor($s / 86400))d"
}
function Bar([int]$Done, [int]$Total, [int]$Width, [string]$Style) {
    if ($Total -le 0) { return @(S ($g.light * $Width) $st.faint) }
    $fill = [int][Math]::Round($Width * $Done / $Total)
    if ($Done -gt 0 -and $fill -eq 0) { $fill = 1 }
    return @((S ($g.full * $fill) $Style), (S ($g.light * ($Width - $fill)) $st.faint))
}

# --- the specs and changes (read from the files: fast, no CLI needed) ---------------------------------------

function Read-Text([string]$Path) {
    if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) { return [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) }
    return ''
}
$dashClass = "[-$(C 0x2013)$(C 0x2014)]"
# A document's title (its first "# " line) without the project's name in front ("Acme Portal - Costs" -> "Costs").
function Get-DocTitle([string]$Text, [string]$Name) {
    $m = [regex]::Match($Text, '(?m)^#\s+(.+?)\s*$')
    if (-not $m.Success) { return '' }
    $t = $m.Groups[1].Value
    if ($projectName) { $t = $t -replace ('^' + [regex]::Escape($projectName) + '\s*' + $dashClass + '\s*'), '' }
    if ($t -ieq $Name -or $t -ieq "$Name Specification") { return '' }
    return $t
}
# A markdown section's body: from "## <Heading>" to the next "## " (or the end).
function Get-Section([string]$Text, [string]$Heading) {
    $m = [regex]::Match($Text, '(?ms)^##\s+' + [regex]::Escape($Heading) + '\s*$(.*?)(?=^##\s|\z)')
    if ($m.Success) { return $m.Groups[1].Value.Trim("`r", "`n") }
    return ''
}
function Count([string]$Text, [string]$Pattern) { return ([regex]::Matches($Text, $Pattern)).Count }
function Last-Write([string]$Dir) {
    $files = @(Get-ChildItem -LiteralPath $Dir -Recurse -File -ErrorAction SilentlyContinue)
    $max = (Get-Item -LiteralPath $Dir).LastWriteTime
    # Not Measure-Object -Maximum: Windows PowerShell 5.1 only takes numbers there.
    foreach ($f in $files) { if ($f.LastWriteTime -gt $max) { $max = $f.LastWriteTime } }
    return $max
}
$platformPrefix = 'platform-'
# The project's own settings (tools/lazyspec/lazyspec.json; initintoproject -Update keeps it).
$specOrder = @()
$exportSettings = $null
# The project's settings: its kit's (tools\lazyspec\lazyspec.json), else lazyspec.json in its root (LazySpec
# installed, not in the project), else next to this script.
$settingsFile = Join-Path $kitDir 'lazyspec.json'
if ($hasRoot) {
    foreach ($f in @((Join-Path $Root 'tools\lazyspec\lazyspec.json'), (Join-Path $Root 'lazyspec.json'))) { if (Test-Path -LiteralPath $f) { $settingsFile = $f; break } }
}
if (Test-Path -LiteralPath $settingsFile) {
    try {
        $settings = Get-Content -LiteralPath $settingsFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $specOrder = @($settings.specOrder | Where-Object { $_ } | ForEach-Object { [string]$_ })
        $exportSettings = $settings.export
    } catch { }
}
$specOrder = [string[]]$specOrder

# --- the workflow (an OpenSpec schema): which documents a change has, in which order ----------------------
# As the CLI: the change's .openspec.yaml "schema:", else openspec/config.yaml "schema:", else spec-driven;
# found in openspec/schemas/<name>/, then the user's schemas (%LOCALAPPDATA%\openspec\schemas, or
# $env:XDG_DATA_HOME\openspec\schemas), then the CLI's built-in ones. Without any: spec-driven as built in here.
function New-Artifact([string]$Id, [string]$Generates) { return [pscustomobject]@{ Id = $Id; Generates = $Generates } }
$defaultWorkflow = [pscustomobject]@{
    Name = 'spec-driven'; Tracks = 'tasks.md'; Missing = ''; Language = ''
    Artifacts = @((New-Artifact 'proposal' 'proposal.md'), (New-Artifact 'specs' 'specs/**/*.md'), (New-Artifact 'design' 'design.md'), (New-Artifact 'tasks' 'tasks.md'))
}
$script:workflows = @{}
$script:projectSchema = $null
function Unquote([string]$Value) {
    $v = $Value.Trim()
    if ($v -match '^"(.*)"\s*(#.*)?$' -or $v -match "^'(.*)'\s*(#.*)?$") { return $Matches[1] }
    return ($v -replace '\s+#.*$', '').Trim()
}
# A top-level "key: value" of a YAML file.
function Get-YamlValue([string]$Text, [string]$Key) {
    $m = [regex]::Match($Text, '(?m)^' + [regex]::Escape($Key) + ':[ \t]*(.*?)[ \t]*\r?$')
    if ($m.Success) { return (Unquote $m.Groups[1].Value) }
    return ''
}
# Reads a schema.yaml: the artifacts (id, generates) and apply.tracks. Only what LazySpec needs: no YAML module.
function Read-Workflow([string]$File, [string]$Name) {
    $artifacts = @()
    $tracks = ''
    $language = ''
    $section = ''; $itemIndent = -1; $keyIndent = -1; $cur = $null
    foreach ($line in (Read-Text $File).Replace("`r", '').Split("`n")) {
        if (-not $line.Trim() -or $line.TrimStart().StartsWith('#')) { continue }
        if ($line -match '^([A-Za-z_][\w-]*):\s*(.*)$') {
            $section = $Matches[1]; $itemIndent = -1; $keyIndent = -1; $cur = $null
            # LazySpec's own key (the CLI ignores keys it doesn't know): the language the documents are written in.
            if ($section -eq 'language') { $language = (Unquote $Matches[2]).ToLower() }
            continue
        }
        $indent = $line.Length - $line.TrimStart().Length
        if ($section -eq 'artifacts') {
            if ($line -match '^(\s*)-\s+([\w-]+):\s*(.*)$' -and ($itemIndent -lt 0 -or $Matches[1].Length -eq $itemIndent)) {
                $itemIndent = $Matches[1].Length; $keyIndent = $line.IndexOf($Matches[2])
                $cur = New-Artifact '' ''; $artifacts += $cur
                $k = $Matches[2]; $v = $Matches[3]
            }
            elseif ($cur -and $indent -eq $keyIndent -and $line -match '^\s*([\w-]+):\s*(.*)$') { $k = $Matches[1]; $v = $Matches[2] }
            else { continue }
            if ($k -eq 'id') { $cur.Id = Unquote $v } elseif ($k -eq 'generates') { $cur.Generates = Unquote $v }
        }
        elseif ($section -eq 'apply') {
            if ($keyIndent -lt 0) { $keyIndent = $indent }
            if ($indent -eq $keyIndent -and $line -match '^\s*tracks:\s*(.*)$') { $tracks = Unquote $Matches[1] }
        }
    }
    $artifacts = @($artifacts | Where-Object { $_.Id -and $_.Generates })
    if (-not $artifacts.Count) { return $null }
    if (-not $tracks) { $t = @($artifacts | Where-Object { $_.Id -eq 'tasks' }); if ($t.Count) { $tracks = $t[0].Generates } }
    return [pscustomobject]@{ Name = $Name; Tracks = $tracks; Missing = ''; Language = $language; Artifacts = $artifacts }
}
function Get-SchemaDirs {
    $dirs = @()
    if ($hasRoot) { $dirs += (Join-Path $osDir 'schemas') }
    if ($env:XDG_DATA_HOME) { $dirs += (Join-Path $env:XDG_DATA_HOME 'openspec\schemas') }
    elseif ($localData) { $dirs += (Join-Path $localData 'openspec\schemas') }
    # The CLI's built-in schemas: next to the openspec command (npm, nvm), or in lib/node_modules.
    $cmd = Get-Command openspec -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source) {
        $bin = Split-Path $cmd.Source
        foreach ($d in @((Join-Path $bin 'node_modules\@fission-ai\openspec\schemas'), (Join-Path $bin '..\lib\node_modules\@fission-ai\openspec\schemas'))) { if (Test-Path -LiteralPath $d) { $dirs += $d; break } }
    }
    return $dirs
}
$script:schemaDirs = $null
function Get-Workflow([string]$ChangeDir) {
    $name = Get-YamlValue (Read-Text (Join-Path $ChangeDir '.openspec.yaml')) 'schema'
    if (-not $name) {
        if ($null -eq $script:projectSchema) { $script:projectSchema = ''; if ($hasRoot) { $script:projectSchema = Get-YamlValue (Read-Text (Join-Path $osDir 'config.yaml')) 'schema' } }
        $name = $script:projectSchema
    }
    if (-not $name) { $name = 'spec-driven' }
    if ($script:workflows.ContainsKey($name)) { return $script:workflows[$name] }
    if ($null -eq $script:schemaDirs) { $script:schemaDirs = @(Get-SchemaDirs) }
    $wf = $null
    if ($name -notmatch '[\\/:]|^\.\.?$') {
        foreach ($d in $script:schemaDirs) {
            $f = Join-Path (Join-Path $d $name) 'schema.yaml'
            if (Test-Path -LiteralPath $f -PathType Leaf) { $wf = Read-Workflow $f $name; if ($wf) { break } }
        }
    }
    if (-not $wf) {
        $wf = $defaultWorkflow
        if ($name -ne 'spec-driven') { $wf = [pscustomobject]@{ Name = $defaultWorkflow.Name; Tracks = $defaultWorkflow.Tracks; Missing = $name; Language = ''; Artifacts = $defaultWorkflow.Artifacts } }
    }
    $script:workflows[$name] = $wf
    return $wf
}
# A schema's "generates" (a file, or a glob: * ** ? {a,b}) as the change's files, sorted.
function Get-GlobRegex([string]$Pattern) {
    $sb = New-Object Text.StringBuilder '^'
    $braces = 0
    for ($i = 0; $i -lt $Pattern.Length; $i++) {
        $c = $Pattern[$i]
        if ($c -eq '*' -and $i + 1 -lt $Pattern.Length -and $Pattern[$i + 1] -eq '*') {
            if ($i + 2 -lt $Pattern.Length -and $Pattern[$i + 2] -eq '/') { [void]$sb.Append('(?:.*/)?'); $i += 2 } else { [void]$sb.Append('.*'); $i++ }
        }
        elseif ($c -eq '*') { [void]$sb.Append('[^/]*') }
        elseif ($c -eq '?') { [void]$sb.Append('[^/]') }
        elseif ($c -eq '{') { [void]$sb.Append('(?:'); $braces++ }
        elseif ($c -eq '}' -and $braces) { [void]$sb.Append(')'); $braces-- }
        elseif ($c -eq ',' -and $braces) { [void]$sb.Append('|') }
        else { [void]$sb.Append([regex]::Escape([string]$c)) }
    }
    return $sb.Append('$').ToString()
}
function Get-ArtifactFiles([string]$Dir, [string]$Generates) {
    $pattern = $Generates.Replace('\', '/').TrimStart('.', '/')
    if ($pattern -notmatch '[*?{]') {
        $p = Join-Path $Dir $pattern
        if (Test-Path -LiteralPath $p -PathType Leaf) { return @($p) }
        return @()
    }
    $rx = Get-GlobRegex $pattern
    $base = $Dir.TrimEnd('\', '/')
    return @(Get-ChildItem -LiteralPath $Dir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName.Substring($base.Length + 1).Replace('\', '/') -match $rx } | Sort-Object FullName | ForEach-Object { $_.FullName })
}
# "open-questions" -> "Open questions".
function Get-ArtifactTitle([string]$Id) {
    $t = $Id.Replace('-', ' ').Replace('_', ' ')
    if (-not $t) { return $t }
    return $t.Substring(0, 1).ToUpper() + $t.Substring(1)
}
function Load-Specs {
    $list = @()
    if (-not $hasRoot) { return $list }
    $dir = Join-Path $osDir 'specs'
    if (-not (Test-Path -LiteralPath $dir)) { return $list }
    foreach ($d in @(Get-ChildItem -LiteralPath $dir -Directory | Sort-Object Name)) {
        $file = Join-Path $d.FullName 'spec.md'
        if (-not (Test-Path -LiteralPath $file)) { continue }
        $text = Read-Text $file
        $name = $d.Name
        $platform = $name.StartsWith($platformPrefix)
        $short = $name
        if ($platform) { $short = $name.Substring($platformPrefix.Length) }
        $list += [pscustomobject]@{
            Type = 'spec'; Name = $name; Short = $short; Platform = $platform; Title = (Get-DocTitle $text $name)
            Reqs = (Count $text '(?m)^###\s+Requirement:'); Scenarios = (Count $text '(?m)^####\s+Scenario:')
            Modified = (Get-Item -LiteralPath $file).LastWriteTime; Path = $file; Dir = $d.FullName; Text = $text
        }
    }
    # The project's order (lazyspec.json: "specOrder"), then the overview, the other platform pages, the capabilities.
    return @($list | Sort-Object @{ Expression = {
                $i = [array]::IndexOf($specOrder, $_.Name)
                if ($i -ge 0) { $i } elseif ($_.Short -eq 'overview') { 1000 } elseif ($_.Platform) { 1001 } else { 1002 } } }, Name)
}
function Get-ChangeInfo($Dir, [bool]$Archived) {
    $wf = Get-Workflow $Dir.FullName
    # The documents, in the workflow's order; the delta specs (specs/...) are read below, as capabilities.
    $docs = @()
    $claimed = @{}
    foreach ($a in $wf.Artifacts) {
        $files = @(Get-ArtifactFiles $Dir.FullName $a.Generates)
        foreach ($f in $files) { $claimed[$f.ToLower()] = $true }
        $docs += [pscustomobject]@{ Id = $a.Id; Title = (Get-ArtifactTitle $a.Id); Generates = $a.Generates; Files = $files; IsSpecs = $a.Generates.Replace('\', '/').TrimStart('.', '/').StartsWith('specs/') }
    }
    # Other documents in the change's folder that the workflow doesn't name: shown after its own.
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir.FullName -File -Filter '*.md' -ErrorAction SilentlyContinue | Sort-Object Name)) {
        if (-not $claimed.ContainsKey($f.FullName.ToLower())) { $docs += [pscustomobject]@{ Id = $f.BaseName; Title = (Get-ArtifactTitle $f.BaseName); Generates = $f.Name; Files = @($f.FullName); IsSpecs = $false; Extra = $true } }
    }
    # The tasks: the artifact the workflow's apply.tracks names (tasks.md by default).
    $tracked = @($docs | Where-Object { $wf.Tracks -and $_.Generates -eq $wf.Tracks })
    if (-not $tracked.Count) { $tracked = @($docs | Where-Object { $_.Id -eq 'tasks' }) }
    $tasks = ''
    if ($tracked.Count) { $tasks = (@($tracked[0].Files | ForEach-Object { Read-Text $_ }) -join "`n") }
    $done = Count $tasks '(?mi)^\s*[-*]\s+\[x\]'
    $open = Count $tasks '(?m)^\s*[-*]\s+\[ \]'
    $total = $done + $open
    $stage = 'In Progress'
    if ($Archived) { $stage = 'Archived' }
    elseif ($total -eq 0) { $stage = 'Draft' }
    elseif ($done -eq $total) { $stage = 'Completed' }
    $caps = @()
    $specsDir = Join-Path $Dir.FullName 'specs'
    if (Test-Path -LiteralPath $specsDir) {
        foreach ($c in @(Get-ChildItem -LiteralPath $specsDir -Directory | Sort-Object Name)) {
            $t = Read-Text (Join-Path $c.FullName 'spec.md')
            $counts = @{}
            foreach ($op in @('ADDED', 'MODIFIED', 'REMOVED', 'RENAMED')) { $counts[$op] = Count (Get-Section $t "$op Requirements") '(?m)^###\s+Requirement:' }
            $caps += [pscustomobject]@{ Name = $c.Name; Added = $counts.ADDED; Modified = $counts.MODIFIED; Removed = $counts.REMOVED; Renamed = $counts.RENAMED; Path = (Join-Path $c.FullName 'spec.md') }
        }
    }
    # The title and the file to edit: the proposal, else the workflow's first document there is.
    $main = Join-Path $Dir.FullName 'proposal.md'
    if (-not (Test-Path -LiteralPath $main)) { $first = @($docs | Where-Object { -not $_.IsSpecs -and $_.Files.Count } | Select-Object -First 1); if ($first.Count) { $main = $first[0].Files[0] } }
    $title = ''
    $m = [regex]::Match((Read-Text $main), '(?m)^#\s+(.+?)\s*$')
    if ($m.Success) { $title = $m.Groups[1].Value -replace '^(Change|Proposal)\s*:\s*', '' }
    return [pscustomobject]@{
        Type = 'change'; Name = $Dir.Name; Title = $title; Stage = $stage; Archived = $Archived; Done = $done; Total = $total
        Modified = (Last-Write $Dir.FullName); Dir = $Dir.FullName; Path = $main; Caps = $caps; Tasks = $tasks
        Workflow = $wf; Docs = $docs
    }
}
function Load-Changes {
    $list = @()
    if (-not $hasRoot) { return $list }
    $dir = Join-Path $osDir 'changes'
    if (-not (Test-Path -LiteralPath $dir)) { return $list }
    foreach ($d in @(Get-ChildItem -LiteralPath $dir -Directory | Where-Object { $_.Name -ne 'archive' })) { $list += Get-ChangeInfo $d $false }
    $arch = Join-Path $dir 'archive'
    if (Test-Path -LiteralPath $arch) { foreach ($d in @(Get-ChildItem -LiteralPath $arch -Directory)) { $list += Get-ChangeInfo $d $true } }
    return $list
}
$stageLook = @{
    'Draft' = @($g.ring, $st.muted, $st.chipFaint); 'In Progress' = @($g.diamond, $st.accent, $st.chipOn)
    'Completed' = @($g.dot, $st.ok, $st.chipOk); 'Archived' = @($g.mid, $st.faint, $st.chipFaint)
}
$sortModes = @('name', 'name-desc', 'recent')
$sortLabels = @{ 'name' = 'name A-Z'; 'name-desc' = 'name Z-A'; 'recent' = 'recently modified' }

# --- state ---------------------------------------------------------------------------------------------

$script:specs = @()
$script:changes = @()
$script:specIndex = 0
$script:changeIndex = 0
$script:focus = 'specs'
$script:screen = 'home'
if (-not $hasRoot) { $script:screen = 'none' }
$script:sort = 'name'
$script:showArchived = $false
$script:filter = ''
$script:filtering = $false
$script:message = ''
$script:detailScroll = 0
$script:pane = 'list'
$script:zoom = $false
$script:readTab = 0
$script:readScroll = 0
$script:readCache = @{}
$script:confirm = $null
$script:choose = $null
$script:input = $null
$script:pick = $null
$script:lastPick = @()
$script:lastPickTitle = ''
$script:run = $null
$script:quit = $false
$script:tick = 0
$script:signature = ''

function Get-Signature {
    if (-not $hasRoot) { return '' }
    $files = @(Get-ChildItem -LiteralPath $osDir -Recurse -File -ErrorAction SilentlyContinue)
    $max = 0
    foreach ($f in $files) { if ($f.LastWriteTimeUtc.Ticks -gt $max) { $max = $f.LastWriteTimeUtc.Ticks } }
    return "$($files.Count)/$max"
}
function Reload {
    $keepSpec = $null; $keepChange = $null
    $vs = @(Get-VisibleSpecs); $vc = @(Get-VisibleChanges)
    if ($vs.Count -gt $script:specIndex) { $keepSpec = $vs[$script:specIndex].Name }
    if ($vc.Count -gt $script:changeIndex) { $keepChange = $vc[$script:changeIndex].Name }
    $script:workflows = @{}
    $script:projectSchema = $null
    $script:projectConfig = $null
    $script:specs = @(Load-Specs)
    $script:changes = @(Load-Changes)
    $script:readCache = @{}
    $script:signature = Get-Signature
    Select-ByName $keepSpec $keepChange
    if (-not $script:specs.Count -and $script:changes.Count) { $script:focus = 'changes' }
}
function Select-ByName([string]$Spec, [string]$Change) {
    $vs = @(Get-VisibleSpecs); $vc = @(Get-VisibleChanges)
    $script:specIndex = [Math]::Max(0, [Math]::Min($script:specIndex, $vs.Count - 1))
    $script:changeIndex = [Math]::Max(0, [Math]::Min($script:changeIndex, $vc.Count - 1))
    for ($i = 0; $i -lt $vs.Count; $i++) { if ($Spec -and $vs[$i].Name -eq $Spec) { $script:specIndex = $i } }
    for ($i = 0; $i -lt $vc.Count; $i++) { if ($Change -and $vc[$i].Name -eq $Change) { $script:changeIndex = $i } }
}
function Matches-Filter($Item) { return (-not $script:filter) -or ($Item.Name.ToLower().Contains($script:filter.ToLower())) -or ($Item.Title -and $Item.Title.ToLower().Contains($script:filter.ToLower())) }
function Get-VisibleSpecs { return @($script:specs | Where-Object { Matches-Filter $_ }) }
function Get-VisibleChanges {
    $list = @($script:changes | Where-Object { (Matches-Filter $_) -and ($script:showArchived -or -not $_.Archived) })
    $active = @($list | Where-Object { -not $_.Archived })
    $arch = @($list | Where-Object { $_.Archived } | Sort-Object Name)
    switch ($script:sort) {
        'name-desc' { $active = @($active | Sort-Object Name -Descending) }
        'recent' { $active = @($active | Sort-Object Modified -Descending) }
        default { $active = @($active | Sort-Object Name) }
    }
    return @($active) + @($arch)
}
# What the lists and headers show: a spec's title (else its name), a change's number and title (else its name).
function Get-ItemTitle($Item) {
    if ($Item.Type -eq 'spec') { if ($Item.Title) { return (Get-TranslatedText $Item.Title) }; return $Item.Short }
    if ($Item.Type -eq 'bundle') { return (Get-TranslatedText $Item.Title) }
    if ($Item.Title) {
        $m = [regex]::Match($Item.Name, '^(\d+)-')
        if ($m.Success) { return "$($m.Groups[1].Value) $(Get-TranslatedText $Item.Title)" }
        return (Get-TranslatedText $Item.Title)
    }
    return $Item.Name
}
# Several changes as one whole (m on Home, x: chosen changes, -Item a,b,c): their documents by kind, in
# their workflows' order (the documents no workflow names last); read and exported as one.
function Get-ChangeGroup([string[]]$Names) {
    $all = @(Load-Changes)
    $list = @()
    foreach ($n in $Names) {
        $c = Find-Change $n $all
        if (-not $c) { throw "No change named '$n' in openspec/changes (several -Item: changes only)." }
        if (@($list | Where-Object { $_.Name -eq $c.Name }).Count) { continue }
        $list += $c
    }
    return $list
}
# A change by its name: an active one, else an archived one (its folder: <date>-<name>).
function Find-Change([string]$Name, $All) {
    $c = @($All | Where-Object { $_.Name -eq $Name -and -not $_.Archived }) + @($All | Where-Object { $_.Archived -and ($_.Name -eq $Name -or $_.Name -match ('^\d{4}-\d{2}-\d{2}-' + [regex]::Escape($Name) + '$')) } | Sort-Object Name -Descending)
    if ($c.Count) { return $c[0] }
    return $null
}
# Named wholes: "lazyspec: bundles:" in openspec/config.yaml, an entry each (saved from the m screen):
#   online-payments:
#     title: "Online payments"
#     changes: add-user-signup, add-online-payments
function Get-Bundles {
    $list = @()
    $m = (Get-ProjectConfig).Maps['bundles']
    foreach ($id in @($m.Groups.Keys)) {
        $e = $m.Groups[$id]
        $names = @(([string]$e['changes']).Trim().TrimStart('[').TrimEnd(']').Split(',') | ForEach-Object { Unquote $_ } | Where-Object { $_ })
        if (-not $names.Count) { continue }
        $list += [pscustomobject]@{ Id = $id; Title = [string]$e['title']; Changes = $names }
    }
    return $list
}
# A name for a file or a key: lowercase, without accents, words joined by hyphens.
function Get-Slug([string]$Text) {
    $t = ([regex]::Replace($Text.ToLower().Normalize([Text.NormalizationForm]::FormD), '\p{Mn}', '')).Replace([string][char]0x111, 'd')
    return ($t -replace '[^a-z0-9]+', '-').Trim('-')
}
# Saves a named whole in openspec/config.yaml (its entry replaced when it's there); no changes: removes it.
# The rest of the file stays as it is.
function Set-ConfigBundle([string]$Id, [string]$Title, [string[]]$Names) {
    $Names = @($Names | Where-Object { $_ })
    $path = Join-Path $osDir 'config.yaml'
    $bytes = [byte[]]@()
    if (Test-Path -LiteralPath $path) { $bytes = [IO.File]::ReadAllBytes($path) }
    $bom = $bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $raw = (New-Object Text.UTF8Encoding $false).GetString($bytes)
    if ($bom) { $raw = $raw.Substring(1) }
    $nl = "`n"
    if ($raw.Contains("`r`n")) { $nl = "`r`n" }
    $lines = New-Object Collections.Generic.List[string]
    if ($raw) { $lines.AddRange([string[]]($raw.Replace("`r", '').Split("`n"))) }
    $endsNl = $lines.Count -and $lines[$lines.Count - 1] -eq ''
    if ($endsNl) { $lines.RemoveAt($lines.Count - 1) }
    $indentOf = { param($l) $l.Length - $l.TrimStart().Length }
    # The lazyspec: block (to the next key at the margin).
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^lazyspec:\s*(#.*)?$') { $start = $i; break } }
    if ($start -lt 0) {
        if (-not $Names.Count) { return }
        while ($lines.Count -and -not $lines[$lines.Count - 1].Trim()) { $lines.RemoveAt($lines.Count - 1) }
        if ($lines.Count) { $lines.Add('') }
        $lines.Add('lazyspec:'); $start = $lines.Count - 1
    }
    $end = $lines.Count
    for ($i = $start + 1; $i -lt $lines.Count; $i++) { $l = $lines[$i]; if ($l.Trim() -and -not $l.TrimStart().StartsWith('#') -and (& $indentOf $l) -eq 0) { $end = $i; break } }
    $ki = 2
    for ($i = $start + 1; $i -lt $end; $i++) { if ($lines[$i].Trim() -and (& $indentOf $lines[$i]) -gt 0) { $ki = & $indentOf $lines[$i]; break } }
    $last = $start
    for ($i = $start + 1; $i -lt $end; $i++) { if ($lines[$i].Trim() -and (& $indentOf $lines[$i]) -gt 0) { $last = $i } }
    # Its bundles: block.
    $b = -1
    for ($i = $start + 1; $i -le $last; $i++) { if ($lines[$i] -match ('^' + (' ' * $ki) + 'bundles:\s*(#.*)?$')) { $b = $i; break } }
    if ($b -lt 0) {
        if (-not $Names.Count) { return }
        $lines.Insert($last + 1, (' ' * $ki) + 'bundles:'); $b = $last + 1; $bEnd = $b + 1
    }
    else {
        $bEnd = $b + 1
        for ($i = $b + 1; $i -lt $end; $i++) { $l = $lines[$i]; if (-not $l.Trim()) { continue }; if ((& $indentOf $l) -le $ki) { break }; $bEnd = $i + 1 }
        # The entry, when it's there: out (it's written again below).
        for ($i = $b + 1; $i -lt $bEnd; $i++) {
            if ($lines[$i] -notmatch '^(\s+)("[^"]*"|''[^'']*''|[^:#]+?):\s*(#.*)?$' -or (Unquote $Matches[2]) -ne $Id) { continue }
            $ei = $Matches[1].Length
            $j = $i + 1
            while ($j -lt $bEnd -and (-not $lines[$j].Trim() -or (& $indentOf $lines[$j]) -gt $ei)) { $j++ }
            $lines.RemoveRange($i, $j - $i); $bEnd -= ($j - $i)
            break
        }
    }
    if ($Names.Count) {
        $u = ' ' * $ki
        $lines.InsertRange($bEnd, [string[]]@("$u$u${Id}:", "$u$u${u}title: `"$($Title.Replace('"', "'"))`"", "$u$u${u}changes: $($Names -join ', ')"))
    }
    else {
        # No wholes left: no bundles: either.
        $any = $false
        for ($i = $b + 1; $i -lt $bEnd; $i++) { if ($lines[$i].Trim()) { $any = $true } }
        if (-not $any) { $lines.RemoveAt($b) }
    }
    $text = ($lines -join $nl)
    if ($endsNl) { $text += $nl }
    $out = (New-Object Text.UTF8Encoding $false).GetBytes($text)
    if ($bom) { $out = [byte[]](@(0xEF, 0xBB, 0xBF) + $out) }
    [IO.File]::WriteAllBytes($path, $out)
    $script:projectConfig = $null
}
function Get-ChangeBundle($Changes, [string]$Title, [string]$Id) {
    $Changes = @($Changes)
    if (-not $Title) { $Title = (@($Changes | ForEach-Object { if ($_.Title) { $_.Title } else { $_.Name } }) -join ', ') }
    $docs = New-Object Collections.ArrayList
    $seen = @{}
    foreach ($extra in @($false, $true)) {
        foreach ($c in $Changes) {
            foreach ($d in $c.Docs) {
                if ([bool]$d.PSObject.Properties['Extra'] -ne $extra -or $seen.ContainsKey($d.Id)) { continue }
                $seen[$d.Id] = $true; [void]$docs.Add($d)
            }
        }
    }
    $done = 0; $total = 0; $modified = [datetime]::MinValue
    foreach ($c in $Changes) { $done += $c.Done; $total += $c.Total; if ($c.Modified -gt $modified) { $modified = $c.Modified } }
    return [pscustomobject]@{
        Type = 'bundle'; Id = $Id; Name = (@($Changes | ForEach-Object { $_.Name }) -join ','); Title = $Title; Members = $Changes; Docs = @($docs)
        Caps = @(foreach ($c in $Changes) { $c.Caps }); Done = $done; Total = $total; Modified = $modified
        Workflow = $Changes[0].Workflow; Dir = $Changes[0].Dir; Path = $Changes[0].Path
    }
}
function Get-Selected {
    if ($script:focus -eq 'specs') { $vs = @(Get-VisibleSpecs); if ($vs.Count) { return $vs[$script:specIndex] } }
    else { $vc = @(Get-VisibleChanges); if ($vc.Count) { return $vc[$script:changeIndex] } }
    return $null
}

# --- markdown, readable in a terminal -------------------------------------------------------------------

# A Markdown table row's cells: split at the pipes, not at an escaped one (\|, a pipe inside a cell).
function Split-TableRow([string]$Row) {
    $r = $Row.Trim()
    if ($r.StartsWith('|')) { $r = $r.Substring(1) }
    if ($r.EndsWith('|') -and -not $r.EndsWith('\|')) { $r = $r.Substring(0, $r.Length - 1) }
    return @([regex]::Split($r, '(?<!\\)\|') | ForEach-Object { $_.Trim().Replace('\|', '|') })
}
# Inline markup off (**bold**, `code`, [text](link)): the line keeps its words.
function Plain-Inline([string]$T) {
    $T = [regex]::Replace($T, '\[([^\]]+)\]\(([^)]+)\)', '$1')
    $T = $T.Replace('**', '').Replace('`', '')
    return $T
}
# A wrapped paragraph: the first line after $First, the rest after as many spaces.
function Add-Wrapped($Lines, [string]$First, [string]$FirstStyle, [string]$Text, [string]$Style, [int]$Width) {
    $rest = ' ' * $First.Length
    $isFirst = $true
    foreach ($l in (Wrap $Text ([Math]::Max(10, $Width - $First.Length)))) {
        if ($isFirst) { [void]$Lines.Add(@((S $First $FirstStyle), (S $l $Style))) } else { [void]$Lines.Add(@((S $rest ''), (S $l $Style))) }
        $isFirst = $false
    }
}
function Render-Table($Lines, $Rows, [int]$Width) {
    $cells = @()
    foreach ($r in $Rows) {
        $t = $r.Trim()
        if ($t -match '^\|?\s*:?-{2,}') { $cells += , $null; continue }
        $parts = @(Split-TableRow $t | ForEach-Object { Plain-Inline $_ })
        $cells += , $parts
    }
    # A table without a header row ("| | |"): no empty first line.
    $first = $true
    if ($cells.Count -ge 2 -and $cells[0] -and -not (@($cells[0] | Where-Object { $_ }).Count) -and -not $cells[1]) { $rest = New-Object Collections.ArrayList; for ($i = 2; $i -lt $cells.Count; $i++) { [void]$rest.Add($cells[$i]) }; $cells = $rest.ToArray(); $first = $false }
    $cols = 0
    foreach ($c in $cells) { if ($c -and $c.Count -gt $cols) { $cols = $c.Count } }
    $w = @(0) * $cols
    foreach ($c in $cells) { if ($c) { for ($i = 0; $i -lt $c.Count; $i++) { if ($c[$i].Length -gt $w[$i]) { $w[$i] = $c[$i].Length } } } }
    # Too wide: the widest columns give way first.
    $room = $Width - 2 - 3 * ($cols - 1)
    while (($w | Measure-Object -Sum).Sum -gt $room) {
        $maxI = 0
        for ($i = 1; $i -lt $cols; $i++) { if ($w[$i] -gt $w[$maxI]) { $maxI = $i } }
        if ($w[$maxI] -le 6) { break }
        $w[$maxI]--
    }
    foreach ($c in $cells) {
        if (-not $c) {
            $line = @((S '  ' ''))
            for ($i = 0; $i -lt $cols; $i++) { $line += (S ($g.h * $w[$i]) $st.faint); if ($i -lt $cols - 1) { $line += (S ($g.h + (C 0x253C) + $g.h) $st.faint) } }
            [void]$Lines.Add($line); $first = $false; continue
        }
        $line = @((S '  ' ''))
        for ($i = 0; $i -lt $cols; $i++) {
            $v = ''
            if ($i -lt $c.Count) { $v = $c[$i] }
            $style = $st.text
            if ($first) { $style = $st.head }
            $line += (S (Pad (Short $v $w[$i]) $w[$i]) $style)
            if ($i -lt $cols - 1) { $line += (S " $($g.v) " $st.faint) }
        }
        [void]$Lines.Add($line)
    }
}
function Render-Markdown([string]$Text, [int]$Width) {
    $lines = New-Object Collections.ArrayList
    $src = $Text.Replace("`r", '').Split("`n")
    $inCode = $false
    $table = @()
    $blank = $true
    for ($n = 0; $n -le $src.Count; $n++) {
        $raw = ''
        if ($n -lt $src.Count) { $raw = $src[$n] }
        if ($table.Count -and ($n -ge $src.Count -or -not $raw.Trim().StartsWith('|'))) {
            Render-Table $lines $table $Width; $table = @()
            # Room after a table (the next line isn't glued to its last row; a blank line after it adds no more).
            if ($n -lt $src.Count) { [void]$lines.Add(@()); $blank = $true }
        }
        if ($n -ge $src.Count) { break }
        if ($raw.Trim().StartsWith('```')) {
            $inCode = -not $inCode
            if ($inCode) { [void]$lines.Add(@(S ('  ' + $g.h * [Math]::Min(40, $Width - 4)) $st.faint)) } else { [void]$lines.Add(@(S ('  ' + $g.h * [Math]::Min(40, $Width - 4)) $st.faint)) }
            continue
        }
        if ($inCode) { [void]$lines.Add(@((S '  '), (S $raw $st.code))); continue }
        $t = $raw.TrimEnd()
        if ($t.Trim().StartsWith('|')) { $table += $t; continue }
        if (-not $t.Trim()) { if (-not $blank) { [void]$lines.Add(@()) }; $blank = $true; continue }
        $blank = $false
        if ($t -match '^###\s+Requirement:\s*(.*)$') { Add-Wrapped $lines "$($g.diamond) " $st.accent (Plain-Inline $Matches[1]) $st.bold $Width; continue }
        if ($t -match '^####\s+Scenario:\s*(.*)$') { Add-Wrapped $lines "  $($g.tri) " $st.shared (Plain-Inline $Matches[1]) $st.shared $Width; continue }
        if ($t -match '^(#{1,6})\s+(.*)$') {
            $level = $Matches[1].Length
            $h = Plain-Inline $Matches[2]
            if ($level -eq 1) { Add-Wrapped $lines '' '' $h.ToUpper() $st.title $Width }
            elseif ($level -eq 2) { Add-Wrapped $lines "$($g.bar) " $st.accent $h $st.head $Width }
            else { Add-Wrapped $lines '' '' $h "1;$($st.accent)" $Width }
            continue
        }
        if ($t -match '^(\s*)[-*]\s+\[([ xX])\]\s+(.*)$') {
            $ind = ' ' * [Math]::Min(8, $Matches[1].Length)
            if ($Matches[2] -eq ' ') { Add-Wrapped $lines "$ind$($g.ring) " $st.faint (Plain-Inline $Matches[3]) $st.text $Width }
            else { Add-Wrapped $lines "$ind$($g.check) " $st.ok (Plain-Inline $Matches[3]) $st.muted $Width }
            continue
        }
        if ($t -match '^(\s*)[-*]\s+\*\*(WHEN|THEN|AND|GIVEN|BUT)\*\*\s*(.*)$') {
            $ind = ' ' * [Math]::Min(8, $Matches[1].Length)
            Add-Wrapped $lines ("    $ind" + (Pad $Matches[2] 5) + ' ') $st.key (Plain-Inline $Matches[3]) $st.text $Width
            continue
        }
        if ($t -match '^(\s*)([-*+]|\d+\.)\s+(.*)$') {
            $ind = ' ' * [Math]::Min(8, $Matches[1].Length)
            $item = $Matches[3]
            $mark = $g.bullet
            if ($Matches[2] -ne '-' -and $Matches[2] -ne '*' -and $Matches[2] -ne '+') { $mark = $Matches[2] }
            Add-Wrapped $lines "  $ind$mark " $st.accent (Plain-Inline $item) $st.text $Width
            continue
        }
        if ($t -match '^>\s?(.*)$') { Add-Wrapped $lines "  $($g.v) " $st.faint (Plain-Inline $Matches[1]) $st.muted $Width; continue }
        if ($t -match '^(-{3,}|\*{3,})$') { [void]$lines.Add(@(S ($g.h * [Math]::Min(60, $Width)) $st.faint)); continue }
        if ($t -match '^!\[([^\]]*)\]\(([^)\s]+)\)$') { [void]$lines.Add(@(S "  [picture: $($Matches[1])]" $st.faint)); continue }
        # Relations, transitions ... (several, ;-separated): the label, then one item a line.
        $ll = Get-LabelledList $t
        if ($ll) {
            Add-Wrapped $lines '' '' "$($ll.Label):" $st.bold $Width
            foreach ($it in $ll.Items) { Add-Wrapped $lines "  $($g.bullet) " $st.accent (Plain-Inline $it) $st.text $Width }
            [void]$lines.Add(@()); $blank = $true
            continue
        }
        Add-Wrapped $lines '' '' (Plain-Inline $t.Trim()) $st.text $Width
    }
    while ($lines.Count -and @($lines[$lines.Count - 1]).Count -eq 0) { $lines.RemoveAt($lines.Count - 1) }
    return , $lines
}

# --- export: the specification as one document for the client (PDF, Word, HTML) -------------------------

function Html([string]$T) { return [Net.WebUtility]::HtmlEncode($T) }
# Inline markdown as HTML: `code`, **bold**, *italic*, [text](link).
function ConvertTo-HtmlInline([string]$T) {
    $codes = New-Object Collections.Generic.List[string]
    $t = [regex]::Replace($T, '`([^`]+)`', { param($m) $codes.Add($m.Groups[1].Value); "$([char]1)$($codes.Count - 1)$([char]1)" })
    $t = Html $t
    # A link to another document of the same export ("open-questions.md"): to its chapter.
    $t = [regex]::Replace($t, '\[([^\]]+)\]\(([^)\s]+)\)', { param($m)
            $href = $m.Groups[2].Value
            $leaf = ($href -replace '#.*$', '' -replace '^\./', '')
            if ($script:docAnchors.ContainsKey($leaf)) { $href = '#' + $script:docAnchors[$leaf] }
            "<a href=`"$href`">$($m.Groups[1].Value)</a>" })
    $t = [regex]::Replace($t, '\*\*(.+?)\*\*', '<strong>$1</strong>')
    $t = [regex]::Replace($t, '(?<![\w*])\*(?![\s*])(.+?)(?<![\s*])\*(?![\w*])', '<em>$1</em>')
    $t = [regex]::Replace($t, "$([char]1)(\d+)$([char]1)", { param($m) '<code>' + (Html $codes[[int]$m.Groups[1].Value]) + '</code>' })
    return $t
}
$script:docAnchors = @{}
# A Markdown document's folder (-Markdown): its pictures' paths are relative to it.
$script:mdBaseDir = ''
# A code block. A drawing (box lines, ASCII arrows) is never wrapped, so it keeps its shape: long lines get
# a smaller font to fit the page. Anything else (commands, JSON) wraps at the page's width, readable.
function ConvertTo-HtmlPre($Lines) {
    $text = @($Lines) -join "`n"
    if ($text -notmatch "[$([char]0x2500)-$([char]0x259F)]|[+|]-{2,}|-{2,}[+>|]|(?m)^\s*[|+]\s") {
        return "<pre class=`"wrap`"><code>" + (Html $text) + "</code></pre>`n"
    }
    $max = 0
    foreach ($l in @($Lines)) { if ($l.Length -gt $max) { $max = $l.Length } }
    $style = ''
    if ($max -gt 95) { $style = " style=`"font-size: $([Math]::Max(5, [Math]::Round(800 / $max, 1)).ToString([Globalization.CultureInfo]::InvariantCulture))pt`"" }
    return "<pre$style><code$style>" + (Html $text) + "</code></pre>`n"
}
# A paragraph that is a proposal ("**Prijedlog:** ..."): set apart, its label underlined.
$proposalLabels = @('Prijedlog', 'Proposal', 'Vorschlag', 'Trenutna pretpostavka', 'Current assumption', 'Preporuka', 'Recommendation', 'Empfehlung')
function Test-Proposal([string]$Text) {
    $m = [regex]::Match($Text.Trim(), '^\*\*([^*:]+?)\s*:\s*\*\*')
    return ($m.Success -and $proposalLabels -contains $m.Groups[1].Value.Trim())
}
# The steps of a scenario (en, hr, de) and the ones that join without a comma ("when x and y, then z").
$stepWords = @('GIVEN', 'WHEN', 'THEN', 'AND', 'BUT', 'OR', 'AKO', 'ZADANO', 'KADA', 'TADA', 'I', 'TE', 'ALI', 'ILI', 'GEGEBEN', 'WENN', 'DANN', 'UND', 'ABER', 'ODER')
$stepJoin = @('and', 'or', 'i', 'te', 'ili', 'und', 'oder')
# "**Veze:** a; b; c" (a models.md's relations, transitions ...): the label and its items, or $null.
function Get-LabelledList([string]$Line) {
    $m = [regex]::Match($Line.Trim(), '^\*\*([^*]{2,40}?)(:\*\*|\*\*:)\s*(.+)$')
    if (-not $m.Success -or $m.Groups[1].Value -notmatch '^(?i)(veze|relations|beziehungen|prijelazi|transitions|.berg.nge|jedinstvenost i indeksi|unique and indexes|eindeutigkeit und indizes)$') { return $null }
    $items = @($m.Groups[3].Value -split ';\s+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($items.Count -lt 2) { return $null }
    return [pscustomobject]@{ Label = $m.Groups[1].Value; Items = $items }
}

# A chapter's number before its title ("3. "), unless the theme says numbering: false.
function Get-ChapterNumber([int]$N) {
    if ($script:docTheme -and -not $script:docTheme.Numbering) { return '' }
    return "$N. "
}

# A markdown document as HTML. $Shift: added to every heading's level (a document inside a chapter).
$script:docSeq = 0
# A table's column widths (percent), for PDF, HTML and Word alike: each column at least its longest word or
# identifier (up to a limit: longer ones break), the rest of the width to the columns with more text
# ("Description"), as far as they need it. Estimated in ems of the table's font: a letter about 0.6 (a
# header's, bold, 0.75), code's 0.56 and its box 0.3, a cell's padding and borders 1.7; a page's text about 45 ems wide.
function Get-TableWidths($Head, $Rows) {
    $all = @()
    if ($Head) { $all += , @($Head) }
    foreach ($r in $Rows) { $all += , @($r) }
    $first = 0
    if ($Head) { $first = 1 }
    $cols = 0
    foreach ($r in $all) { if (@($r).Count -gt $cols) { $cols = @($r).Count } }
    if ($cols -lt 2) { return $null }
    $need = New-Object double[] $cols
    $want = New-Object double[] $cols
    for ($ri = 0; $ri -lt $all.Count; $ri++) {
        $r = $all[$ri]
        for ($i = 0; $i -lt @($r).Count; $i++) {
            $cell = [string]@($r)[$i]
            $longest = 0.0; $total = 0.0
            foreach ($m in [regex]::Matches($cell, '`([^`]*)`|\[([^\]]*)\]\([^)]*\)|([^`\[]+)')) {
                $code = $m.Groups[1].Success
                $txt = $m.Value
                if ($code) { $txt = $m.Groups[1].Value } elseif ($m.Groups[2].Success) { $txt = $m.Groups[2].Value }
                $txt = $txt.Replace('**', '').Replace('__', '')
                $per = 0.6
                if ($ri -lt $first) { $per = 0.75 }
                if ($code) { $per = 0.56 }
                foreach ($w in ($txt -split '\s+')) { if ($w) { $longest = [Math]::Max($longest, $w.Length * $per + $(if ($code) { 0.3 } else { 0 })) } }
                $total += $txt.Length * $per
            }
            $need[$i] = [Math]::Max($need[$i], [Math]::Min(14.0, $longest + 1.7))
            $want[$i] = [Math]::Max($want[$i], [Math]::Min(60.0, $total + 1.7))
        }
    }
    $page = 45.0
    $w = New-Object double[] $cols
    $sumNeed = 0.0; $sumGrow = 0.0; $sumWant = 0.0
    for ($i = 0; $i -lt $cols; $i++) { $want[$i] = [Math]::Max($want[$i], $need[$i]); $sumNeed += $need[$i]; $sumGrow += $want[$i] - $need[$i]; $sumWant += $want[$i] }
    for ($i = 0; $i -lt $cols; $i++) {
        if ($sumNeed -ge $page) { $w[$i] = $need[$i] }
        elseif ($page - $sumNeed -le $sumGrow) { $w[$i] = $need[$i] + ($page - $sumNeed) * ($want[$i] - $need[$i]) / [Math]::Max(0.001, $sumGrow) }
        else { $w[$i] = $want[$i] + ($page - $sumWant) * $want[$i] / $sumWant }
    }
    $sum = 0.0
    foreach ($x in $w) { $sum += $x }
    return @($w | ForEach-Object { [Math]::Round(100 * $_ / $sum, 1) })
}
# A heading with nothing under it (a template's section left with "<!-- none -->") isn't shown: up to the
# next heading of its level or above there's no text, nor a deeper heading that has some.
function Remove-EmptySections([string]$Text) {
    $lines = $Text.Replace("`r", '').Split("`n")
    $level = New-Object int[] $lines.Count
    $fence = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim().StartsWith('```')) { $fence = -not $fence; continue }
        if (-not $fence -and $lines[$i] -match '^(#{1,6})\s+\S') { $level[$i] = $Matches[1].Length }
    }
    # From the end: a deeper heading dropped first makes its parent empty too.
    $drop = New-Object bool[] $lines.Count
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if (-not $level[$i]) { continue }
        $empty = $true
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            if ($drop[$j]) { continue }
            if ($level[$j]) { $empty = $level[$j] -le $level[$i]; break }
            if ($lines[$j].Trim()) { $empty = $false; break }
        }
        $drop[$i] = $empty
    }
    if ($drop -notcontains $true) { return $Text }
    return (@(for ($i = 0; $i -lt $lines.Count; $i++) { if (-not $drop[$i]) { $lines[$i] } }) -join "`n")
}
function ConvertTo-HtmlBody([string]$Text, [int]$Shift = 0) {
    # HTML comments (a template's guidance, <!-- ... -->) aren't shown; nor headings left with nothing under them.
    $Text = [regex]::Replace($Text, '(?s)<!--.*?-->[ \t]*(\r?\n)?', '')
    $Text = Remove-EmptySections $Text
    $out = New-Object Text.StringBuilder
    $src = $Text.Replace("`r", '').Split("`n")
    $para = New-Object Collections.Generic.List[string]
    $table = New-Object Collections.Generic.List[string]
    $quote = New-Object Collections.Generic.List[string]
    $lists = New-Object Collections.ArrayList
    $code = $null
    $gap = $false
    $inScenario = $false
    $liBreak = $false
    # The headings first (outside code), for their ids and the small contents: a section's requirements
    # (## ADDED Requirements: a list of links), a requirement's scenarios (one line, comma-separated).
    $script:docSeq++
    $heads = New-Object Collections.ArrayList
    $fence = $false
    foreach ($l in $src) {
        if ($l.Trim().StartsWith('```')) { $fence = -not $fence; continue }
        if ($fence -or $l.TrimEnd() -notmatch '^(#{1,6})\s+(.*?)\s*#*$') { continue }
        $kind = 'sub'; $txt = $Matches[2]; $lvl = $Matches[1].Length
        if ($txt -match '^(Requirement|Zahtjev|Anforderung):\s*(.*)$') { $kind = 'req'; $txt = $Matches[2] }
        elseif ($txt -match '^(Scenario|Scenarij|Szenario):\s*(.*)$') { $kind = 'scn'; $txt = $Matches[2] }
        elseif ($lvl -le 2) { $kind = 'sec' }
        [void]$heads.Add([pscustomobject]@{ Kind = $kind; Text = $txt; Id = "d$($script:docSeq)-$($heads.Count)"; Children = (New-Object Collections.ArrayList) })
    }
    $sec = $null; $req = $null
    foreach ($hd in $heads) {
        if ($hd.Kind -eq 'sec') { $sec = $hd; $req = $null }
        elseif ($hd.Kind -eq 'req') { if ($sec) { [void]$sec.Children.Add($hd) }; $req = $hd }
        elseif ($hd.Kind -eq 'scn') { if ($req) { [void]$req.Children.Add($hd) } }
    }
    $headIndex = 0
    # Client-friendly: a scenario's WHEN / THEN ... steps as one sentence ("When x, then y.").
    $steps = New-Object Collections.ArrayList
    $flushSteps = {
        if (-not $steps.Count) { return }
        $sentence = ''
        for ($i = 0; $i -lt $steps.Count; $i++) {
            $w = $steps[$i][0].ToLower()
            $txt = $steps[$i][1].Trim().TrimEnd('.', ';', ',')
            if ($i -eq 0) { $sentence = $w.Substring(0, 1).ToUpper() + $w.Substring(1) + ' ' + $txt }
            elseif ($stepJoin -contains $w) { $sentence += " $w $txt" }
            else { $sentence += ", $w $txt" }
        }
        [void]$out.Append('<p class="steps">' + (ConvertTo-HtmlInline "$sentence.") + "</p>`n")
        $steps.Clear()
    }
    $flushPara = {
        if (-not $para.Count) { return }
        $pc = ''
        if (Test-Proposal $para[0]) { $pc = ' class="proposal"' }
        [void]$out.Append("<p$pc>" + ((ConvertTo-HtmlInline ($para -join ' ')) -replace '(\x1F|&#31;)\s*$', '' -replace "(\x1F|&#31;) ?", '<br>') + "</p>`n"); $para.Clear()
    }
    $flushQuote = { if ($quote.Count) { [void]$out.Append('<blockquote><p>' + (ConvertTo-HtmlInline ($quote -join ' ')) + "</p></blockquote>`n"); $quote.Clear() } }
    $closeLists = { param([int]$Indent)
        while ($lists.Count -and $lists[$lists.Count - 1].Indent -gt $Indent) { [void]$out.Append("</li></$($lists[$lists.Count - 1].Tag)>`n"); $lists.RemoveAt($lists.Count - 1) }
    }
    $flushTable = {
        if (-not $table.Count) { return }
        $rows = @(); $head = $null
        foreach ($r in $table) {
            if ($r.Trim() -match '^\|?\s*:?-{2,}') { if ($rows.Count -eq 1 -and $null -eq $head) { $head = $rows[0]; $rows = @() }; continue }
            $rows += , @(Split-TableRow $r)
        }
        $widths = Get-TableWidths $head $rows
        if ($widths) { [void]$out.Append("<table class=`"sized`">`n") } else { [void]$out.Append("<table>`n") }
        if ($widths) { [void]$out.Append('<colgroup>' + (-join @($widths | ForEach-Object { "<col style=`"width: $($_.ToString([Globalization.CultureInfo]::InvariantCulture))%`">" })) + "</colgroup>`n") }
        $cellHtml = { param([string]$T) ConvertTo-HtmlInline $T }
        if ($head -and @($head | Where-Object { $_ }).Count) { [void]$out.Append('<thead><tr>' + (-join @($head | ForEach-Object { '<th>' + (& $cellHtml $_) + '</th>' })) + "</tr></thead>`n") }
        [void]$out.Append('<tbody>')
        # A table of changes (its first column "Change" / "Promjena" / "Aenderung": models.md): a row's + added,
        # ~ changed, - removed, coloured (the colour on the cells too: Word takes it from there).
        $changes = $head -and @($head).Count -and (@($head)[0] -replace '[*`]', '').Trim() -match '^(?i)(change|promjena|.nderung)$'
        foreach ($r in $rows) {
            $tr = '<tr>'; $td = '<td>'
            if ($changes) {
                $mark = (@($r)[0] -replace '[*`]', '').Trim()
                $look = @{ '+' = @('chg-add', '#E6F4EA'); '~' = @('chg-mod', '#FFF4D6'); '-' = @('chg-del', '#FCE8E6'); ([string][char]0x2212) = @('chg-del', '#FCE8E6') }[$mark]
                if ($look) { $tr = "<tr class=`"$($look[0])`">"; $td = "<td style=`"background: $($look[1])`">" }
            }
            [void]$out.Append($tr + (-join @($r | ForEach-Object { $td + (& $cellHtml $_) + '</td>' })) + "</tr>`n")
        }
        [void]$out.Append("</tbody></table>`n")
        $table.Clear()
    }
    foreach ($raw in $src) {
        if ($null -ne $code) {
            if ($raw.Trim().StartsWith('```')) { [void]$out.Append((ConvertTo-HtmlPre $code)); $code = $null }
            else { $code += $raw }
            continue
        }
        if ($script:exportFriendly) {
            # "MORA (MUST)": the normative keyword in brackets is for OpenSpec, not for the client.
            $raw = $raw -replace '\s*\((?:MUST|SHALL|SHOULD|MAY|REQUIRED)(?: NOT)?\)', ''
            $sm = [regex]::Match($raw, '^\s*[-*+]\s+\*\*([^*\s]+)\*\*:?\s+(.*)$')
            if ($sm.Success -and $stepWords -contains $sm.Groups[1].Value.ToUpper()) {
                & $flushPara; & $flushQuote; & $closeLists -1
                [void]$steps.Add(@($sm.Groups[1].Value, $sm.Groups[2].Value)); continue
            }
            if ($steps.Count) { & $flushSteps }
        }
        $t = $raw.TrimEnd()
        if ($table.Count -and -not $t.Trim().StartsWith('|')) { & $flushTable }
        if (-not $t.Trim()) { & $flushPara; & $flushQuote; $gap = $true; continue }
        $item = [regex]::Match($t, '^(\s*)([-*+]|\d+[.)])\s+(.*)$')
        # Text indented under a list item, after a blank line too, is more of that item (a paragraph of its own);
        # anything else after a blank line, or not indented, ends the lists.
        $lead = $raw.Length - $raw.TrimStart().Length
        $inItem = $lists.Count -and -not $item.Success -and $lead -gt $lists[0].Indent -and -not $t.Trim().StartsWith('#')
        if ($lists.Count -and -not $item.Success -and -not $inItem -and ($gap -or -not $raw.StartsWith(' '))) { & $closeLists -1 }
        $wasGap = $gap
        $gap = $false
        if ($t.Trim().StartsWith('```')) { & $flushPara; & $flushQuote; $code = @(); continue }
        if ($t.Trim().StartsWith('|')) { & $flushPara; & $flushQuote; $table.Add($t); continue }
        if ($t -match '^(#{1,6})\s+(.*?)\s*#*$') {
            & $flushPara; & $flushQuote
            $mdLevel = $Matches[1].Length
            $level = [Math]::Min(6, $mdLevel + $Shift)
            $h = $Matches[2]
            if ($inScenario) { [void]$out.Append("</div>`n"); $inScenario = $false }
            # Its id (and a bookmark for Word), from the first pass.
            $hd = $null
            if ($headIndex -lt $heads.Count) { $hd = $heads[$headIndex] }
            $headIndex++
            $id = ''; $mark = ''
            if ($hd) { $id = " id=`"$($hd.Id)`""; $mark = "<a name=`"$($hd.Id)`"></a>" }
            # The classes make the levels clear whatever the document's depth: a section (## Purpose,
            # ## ADDED Requirements ...), a requirement, a scenario (its text in a block of its own), a subheading.
            if ($h -match '^(Requirement|Zahtjev|Anforderung):\s*(.*)$') {
                [void]$out.Append("<h$level class=`"req`"$id>$mark<span class=`"tag`">$(Html (Get-ExportText 'requirement'))</span> $(ConvertTo-HtmlInline $Matches[2])</h$level>`n")
                if ($hd -and $hd.Children.Count) {
                    $links = @($hd.Children | ForEach-Object { "<a href=`"#$($_.Id)`">$(ConvertTo-HtmlInline $_.Text)</a>" }) -join ', '
                    [void]$out.Append("<p class=`"toc-scn`"><span class=`"lbl`">$(Html (Get-ExportText 'scenarios')):</span> $links</p>`n")
                }
            }
            elseif ($h -match '^(Scenario|Scenarij|Szenario):\s*(.*)$') {
                [void]$out.Append("<h$level class=`"scn`"$id>$mark<span class=`"tag`">$(Html (Get-ExportText 'scenario'))</span> $(ConvertTo-HtmlInline $Matches[2])</h$level>`n<div class=`"scenario`">`n")
                $inScenario = $true
            }
            else {
                $cls = 'sub'
                if ($mdLevel -le 2) { $cls = 'sec' }
                # The theme's numbering: false - a document's own headings 1-2 without their numbers ("1. Kostur").
                if ($mdLevel -le 2 -and $script:docTheme -and -not $script:docTheme.Numbering) { $h = $h -replace '^\d+(\.\d+)*\.?\s+', '' }
                [void]$out.Append("<h$level class=`"$cls`"$id>$mark$(ConvertTo-HtmlInline (Get-ExportHeading $h))</h$level>`n")
                if ($hd -and $hd.Children.Count) { [void]$out.Append((Get-TocHtml $hd.Children)) }
            }
            continue
        }
        # A picture on a line of its own (![alt](path); the path relative to the Markdown file): the picture,
        # the page's width at most, its alt text under it.
        if ($t -match '^!\[([^\]]*)\]\(([^)\s]+)\)$') {
            & $flushPara; & $flushQuote
            $alt = $Matches[1]; $src = [Uri]::UnescapeDataString($Matches[2])
            $file = $src
            if (-not [IO.Path]::IsPathRooted($file) -and $script:mdBaseDir) { $file = Join-Path $script:mdBaseDir $file }
            if ($src -notmatch '^[a-z]+://' -and (Test-Path -LiteralPath $file -PathType Leaf)) { [void]$out.Append((Get-DiagramHtml (Resolve-Path -LiteralPath $file).Path $alt 1 $true)) }
            else { Write-Host "  ! picture not found: $src"; [void]$out.Append("<p>$(Html $alt)</p>`n") }
            continue
        }
        if ($t -match '^(-{3,}|\*{3,}|_{3,})$') { & $flushPara; & $flushQuote; [void]$out.Append("<hr>`n"); continue }
        if ($t -match '^>\s?(.*)$') { & $flushPara; $quote.Add($Matches[1]); continue }
        if ($item.Success) {
            & $flushPara; & $flushQuote
            $indent = $item.Groups[1].Value.Length
            $tag = 'ul'
            if ($item.Groups[2].Value -match '^\d') { $tag = 'ol' }
            $body = $item.Groups[3].Value
            # A hard line break at the item's end ("\" or two spaces): its next line on a line of its own.
            $liBreak = $raw -match '(\\|\S {2,})$'
            $body = $body -replace '\\$', ''
            $cls = ''
            # A task: a bullet like any other (done ones with a check mark).
            if ($body -match '^\[([ xX])\]\s+(.*)$') {
                if ($Matches[1] -eq ' ') { $body = ConvertTo-HtmlInline $Matches[2] } else { $body = '<span class="done">&#10003;</span> ' + (ConvertTo-HtmlInline $Matches[2]); $cls = ' class="task-done"' }
            }
            else {
                if ($body -match '^\*\*([^*\s]+)\*\*' -and $stepWords -contains $Matches[1].ToUpper()) { $cls = ' class="step"' }
                $body = ConvertTo-HtmlInline $body
            }
            & $closeLists $indent
            $top = $null
            if ($lists.Count) { $top = $lists[$lists.Count - 1] }
            # A numbered list keeps the document's numbers (start=), a top-level one starts at the margin, and a
            # bulleted list right under a top-level numbered item (a question's answers) is lettered: a, b, c.
            $open = $tag
            if ($tag -eq 'ol') {
                $num = [int]($item.Groups[2].Value -replace '\D', '')
                $open = 'ol'
                if (-not $lists.Count) { $open += ' class="top"' }
                if ($num -ne 1) { $open += " start=`"$num`"" }
            }
            $html = $tag
            if ($tag -eq 'ul' -and $lists.Count -eq 1 -and $lists[0].Md -eq 'ol' -and $indent -gt $lists[0].Indent) { $html = 'ol'; $open = 'ol type="a" class="options"' }
            if ($top -and $top.Indent -eq $indent) {
                if ($top.Md -ne $tag) { [void]$out.Append("</li></$($top.Tag)>`n<$open>"); $top.Tag = $html; $top.Md = $tag } else { [void]$out.Append("</li>`n") }
            }
            else { [void]$out.Append("<$open>"); [void]$lists.Add([pscustomobject]@{ Indent = $indent; Tag = $html; Md = $tag }) }
            [void]$out.Append("<li$cls>$body")
            continue
        }
        # Indented text under a list item: more of that item (of the item it is indented under). After a blank
        # line, or a proposal ("**Prijedlog:** ..."), a paragraph of its own.
        if ($lists.Count) {
            & $closeLists ($lead - 1)
            $text = $t.Trim()
            if ($wasGap -or (Test-Proposal $text)) {
                $pc = ''
                if (Test-Proposal $text) { $pc = ' class="proposal"' }
                [void]$out.Append("<p$pc>" + (ConvertTo-HtmlInline $text) + '</p>')
            }
            else {
                $sep = ' '
                if ($liBreak) { $sep = '<br>' }
                [void]$out.Append($sep + (ConvertTo-HtmlInline ($text -replace '\\$', '')))
            }
            $liBreak = $raw -match '(\\|\S {2,})$'
            continue
        }
        & $flushQuote
        # Relations, transitions ... (several, ;-separated): the label, then a list.
        $ll = Get-LabelledList $t
        if ($ll) {
            & $flushPara
            [void]$out.Append("<p class=`"labelled`"><strong>$(Html $ll.Label):</strong></p>`n<ul class=`"labelled`">" + (-join @($ll.Items | ForEach-Object { '<li>' + (ConvertTo-HtmlInline $_) + '</li>' })) + "</ul>`n")
            continue
        }
        # A hard line break ("\" or two spaces at the line's end): kept as one.
        if ($raw -match '(\\|\S {2,})$') { $para.Add(($t.Trim() -replace '\\$', '') + [char]0x1F) } else { $para.Add($t.Trim()) }
    }
    if ($null -ne $code) { [void]$out.Append((ConvertTo-HtmlPre $code)) }
    & $flushSteps
    & $flushTable; & $flushPara; & $flushQuote; & $closeLists -1
    if ($inScenario) { [void]$out.Append("</div>`n") }
    # -Language another than the documents': the chapter in that language (DeepL).
    return (Convert-TranslatedHtml $out.ToString())
}
# A document's text without its first "# " title (the chapter has its own).
function Remove-DocTitle([string]$Text) { return [regex]::Replace($Text, '\A\s*#\s+[^\r\n]*\r?\n?', '') }
# The project's export settings in openspec/config.yaml, under "lazyspec:" (the OpenSpec CLI ignores keys it
# doesn't know): name (the project's name on the cover), subtitle, client, author, language, and titles
# (a capability's or spec's name -> its title in the export): for every change, or in a group per change
# (the change's folder name, then its capabilities). Read once; only what LazySpec needs: no YAML module.
$script:projectConfig = $null
function Get-ProjectConfig {
    if ($null -ne $script:projectConfig) { return $script:projectConfig }
    # Maps: titles and diagrams, each with the entries for every change (All) and a group per change (Groups).
    $cfg = @{ Values = @{}; Translation = @{}; Maps = @{ titles = @{ All = @{}; Groups = @{} }; diagrams = @{ All = @{}; Groups = @{} }; bundles = @{ All = @{}; Groups = [ordered]@{} } } }
    $script:projectConfig = $cfg
    if (-not $hasRoot) { return $cfg }
    $in = $false; $inT = $false; $keyIndent = -1; $sub = ''; $titleIndent = -1; $group = ''
    foreach ($line in (Read-Text (Join-Path $osDir 'config.yaml')).Replace("`r", '').Split("`n")) {
        if (-not $line.Trim() -or $line.TrimStart().StartsWith('#')) { continue }
        $indent = $line.Length - $line.TrimStart().Length
        if ($indent -eq 0) { $in = $line -match '^lazyspec:\s*$'; $inT = $line -match '^translation:\s*$'; $keyIndent = -1; $sub = ''; continue }
        # translation: (DeepL, Hasek; shared with the netmedia plugin): flat "key: value" lines.
        if ($inT) { if ($line -match '^\s+([A-Za-z]+):\s*(.*?)\s*(#.*)?$') { $cfg.Translation[$Matches[1]] = Unquote $Matches[2] }; continue }
        if (-not $in) { continue }
        if ($keyIndent -lt 0) { $keyIndent = $indent }
        if ($line -notmatch '^\s*("[^"]*"|''[^'']*''|[^:#]+?):(?:\s+(.*))?$') { continue }
        $k = Unquote $Matches[1]
        $v = ''
        if ($Matches[2]) { $v = Unquote $Matches[2] }
        if ($indent -eq $keyIndent) { $sub = ''; $titleIndent = -1; $group = ''; if ($v) { $cfg.Values[$k] = $v } else { $sub = $k } }
        elseif ($cfg.Maps.ContainsKey($sub)) {
            $map = $cfg.Maps[$sub]
            if ($titleIndent -lt 0) { $titleIndent = $indent }
            # "name: value" for every change; "change:" then its own "name: value" lines, deeper.
            if ($indent -eq $titleIndent) {
                $group = ''
                if ($v) { $map.All[$k] = $v } else { $group = $k; $map.Groups[$k] = @{} }
            }
            elseif ($group -and $v) { $map.Groups[$group][$k] = $v }
        }
    }
    return $cfg
}
# An export setting: openspec/config.yaml "lazyspec:" (title: its "name"), else lazyspec.json "export", else $Default.
function Get-ExportSetting([string]$Name, [string]$Default) {
    $values = (Get-ProjectConfig).Values
    if ($Name -eq 'title' -and $values['name']) { return [string]$values['name'] }
    if ($values[$Name]) { return [string]$values[$Name] }
    if ($exportSettings -and $exportSettings.$Name) { return [string]$exportSettings.$Name }
    return $Default
}
# A capability's or spec's title in the export: "lazyspec: titles:" in config.yaml (the change's own group
# first, then the ones for every change), else lazyspec.json export.titles.
# A "titles:" or "diagrams:" entry: the change's group first, then the ones for every change.
function Get-ConfigEntry([string]$Map, [string]$Name, [string]$Change) {
    $m = (Get-ProjectConfig).Maps[$Map]
    if ($Change -and $m.Groups[$Change] -and $m.Groups[$Change][$Name]) { return [string]$m.Groups[$Change][$Name] }
    if ($m.All[$Name]) { return [string]$m.All[$Name] }
    return ''
}
function Get-FriendlyTitle([string]$Name, [string]$Default, [string]$Change) {
    $t = Get-ConfigEntry 'titles' $Name $Change
    if ($t) { return (Get-TranslatedText $t) }
    if ($exportSettings -and $exportSettings.titles -and $exportSettings.titles.$Name) { return (Get-TranslatedText ([string]$exportSettings.titles.$Name)) }
    return $Default
}

# --- diagrams: a FigJam (or Figma) section, or an image file, at the top of a chapter or a capability ------
# "lazyspec: diagrams:" in config.yaml, as titles: a group per change ("change" there: the whole change's
# diagram), entries straight under diagrams for every change and for specs. A Figma link is saved as PNG in
# the change's diagrams\ folder (openspec\diagrams\ for specs), its white margins cut (a FigJam section's
# background and frame; shown at the scale of the change's whole diagram, Get-FigmaScale): commit it, and the
# export works without Figma. Downloaded (again with -RefreshDiagrams) through the Figma REST API with a
# personal access token in FIGMA_TOKEN.
$script:diagramsRefresh = $false
$script:diagramsOffline = $false
$script:figmaRefused = $false
$script:exportFormat = 'Pdf'
$script:imageTool = $false
function Initialize-ImageTool {
    if ($script:imageTool) { return }
    # No GDI+ (Windows only on PowerShell 7): the pictures' headers, PNG decoded and encoded here.
    $refs = @()
    if ($PSVersionTable.PSEdition -eq 'Core') { $refs = @('System.IO.Compression') }
    $code = @'
using System;
using System.IO;
using System.IO.Compression;
using System.Text;
public static class LazySpecImage {
    // A picture's width and height from its header: PNG, JPEG, GIF, BMP, an SVG's width and height.
    public static int[] Size(string path) { return SizeOf(File.ReadAllBytes(path)); }
    public static int[] SizeOf(byte[] b) {
        if (b.Length >= 24 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) { return new int[] { (int)U32(b, 16), (int)U32(b, 20) }; }
        if (b.Length >= 10 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) { return new int[] { b[6] | (b[7] << 8), b[8] | (b[9] << 8) }; }
        if (b.Length >= 26 && b[0] == 0x42 && b[1] == 0x4D) { return new int[] { Math.Abs(BitConverter.ToInt32(b, 18)), Math.Abs(BitConverter.ToInt32(b, 22)) }; }
        if (b.Length >= 4 && b[0] == 0xFF && b[1] == 0xD8) {
            // The frame's header (SOF0..SOF15, not DHT / JPG / DAC): its height, then its width.
            int i = 2;
            while (i + 9 < b.Length) {
                if (b[i] != 0xFF) { i++; continue; }
                int m = b[i + 1];
                if (m == 0xFF) { i++; continue; }
                if (m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) { i += 2; continue; }
                if (m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC) { return new int[] { (b[i + 7] << 8) | b[i + 8], (b[i + 5] << 8) | b[i + 6] }; }
                i += 2 + ((b[i + 2] << 8) | b[i + 3]);
            }
            throw new Exception("a JPEG without a frame header");
        }
        string head = Encoding.UTF8.GetString(b, 0, Math.Min(b.Length, 4096));
        int at = head.IndexOf("<svg");
        if (at >= 0) {
            int end = head.IndexOf('>', at);
            string tag = end > at ? head.Substring(at, end - at) : head.Substring(at);
            double w = SvgLength(tag, "width"), h = SvgLength(tag, "height");
            if (w > 0 && h > 0) { return new int[] { (int)Math.Round(w), (int)Math.Round(h) }; }
            throw new Exception("an SVG without its width and height");
        }
        throw new Exception("not a PNG, JPEG, GIF, BMP or SVG picture");
    }
    static double SvgLength(string tag, string name) {
        int at = tag.IndexOf(" " + name + "=\"");
        if (at < 0) { return 0; }
        at += name.Length + 3;
        int end = tag.IndexOf('"', at);
        string v = tag.Substring(at, end - at).Trim();
        if (v.EndsWith("px")) { v = v.Substring(0, v.Length - 2); }
        double d;
        return double.TryParse(v, System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out d) ? d : 0;
    }
    static long U32(byte[] b, int o) { return ((long)b[o] << 24) | ((long)b[o + 1] << 16) | ((long)b[o + 2] << 8) | b[o + 3]; }

    // Cuts an image's margins off (transparent, white, or light grey without colour: a FigJam section's
    // background and its frame), keeping a border; transparency becomes white. An 8-bit PNG, not interlaced.
    public static void Trim(string path, int border) {
        int w, h;
        int[] px = DecodePng(File.ReadAllBytes(path), out w, out h);
        int minX = w, minY = h, maxX = -1, maxY = -1;
        for (int y = 0; y < h; y++) {
            int row = y * w;
            for (int x = 0; x < w; x++) {
                int c = px[row + x];
                int a = (c >> 24) & 255, r = (c >> 16) & 255, g = (c >> 8) & 255, bl = c & 255;
                int hi = Math.Max(r, Math.Max(g, bl)), lo = Math.Min(r, Math.Min(g, bl));
                if (a < 16 || (lo > 215 && hi - lo < 12)) { continue; }
                if (x < minX) { minX = x; }
                if (x > maxX) { maxX = x; }
                if (y < minY) { minY = y; }
                if (y > maxY) { maxY = y; }
            }
        }
        if (maxX < 0) { return; }
        int x0 = Math.Max(0, minX - border), y0 = Math.Max(0, minY - border);
        int x1 = Math.Min(w - 1, maxX + border), y1 = Math.Min(h - 1, maxY + border);
        File.WriteAllBytes(path, EncodePng(px, w, x0, y0, x1 - x0 + 1, y1 - y0 + 1));
    }

    // PNG -> ARGB pixels (8-bit grey, RGB, palette, grey + alpha, RGBA; tRNS too).
    static int[] DecodePng(byte[] b, out int w, out int h) {
        if (b.Length < 33 || b[0] != 0x89 || b[1] != 0x50 || b[2] != 0x4E || b[3] != 0x47) { throw new Exception("not a PNG"); }
        w = 0; h = 0;
        int depth = 0, type = 0, interlace = 0;
        byte[] palette = null, trns = null;
        MemoryStream idat = new MemoryStream();
        int i = 8;
        while (i + 8 <= b.Length) {
            int len = (int)U32(b, i);
            string tag = Encoding.ASCII.GetString(b, i + 4, 4);
            int d = i + 8;
            if (tag == "IHDR") { w = (int)U32(b, d); h = (int)U32(b, d + 4); depth = b[d + 8]; type = b[d + 9]; interlace = b[d + 12]; }
            else if (tag == "PLTE") { palette = new byte[len]; Array.Copy(b, d, palette, 0, len); }
            else if (tag == "tRNS") { trns = new byte[len]; Array.Copy(b, d, trns, 0, len); }
            else if (tag == "IDAT") { idat.Write(b, d, len); }
            else if (tag == "IEND") { break; }
            i = d + len + 4;
        }
        if (depth != 8) { throw new Exception("a " + depth + "-bit PNG (8-bit only)"); }
        if (interlace != 0) { throw new Exception("an interlaced PNG"); }
        int ch;
        if (type == 0) { ch = 1; } else if (type == 2) { ch = 3; } else if (type == 3) { ch = 1; } else if (type == 4) { ch = 2; } else if (type == 6) { ch = 4; }
        else { throw new Exception("PNG colour type " + type); }
        if (type == 3 && palette == null) { throw new Exception("a palette PNG without its palette"); }
        // zlib: its 2-byte header off, the rest is deflate.
        byte[] z = idat.ToArray();
        MemoryStream raw = new MemoryStream();
        using (DeflateStream ds = new DeflateStream(new MemoryStream(z, 2, z.Length - 2), CompressionMode.Decompress)) {
            byte[] buf = new byte[65536];
            int n;
            while ((n = ds.Read(buf, 0, buf.Length)) > 0) { raw.Write(buf, 0, n); }
        }
        byte[] data = raw.ToArray();
        int stride = w * ch;
        if (data.Length < (stride + 1) * h) { throw new Exception("a PNG cut short"); }
        byte[] prev = new byte[stride], cur = new byte[stride];
        int[] px = new int[w * h];
        for (int y = 0; y < h; y++) {
            int f = data[y * (stride + 1)];
            Array.Copy(data, y * (stride + 1) + 1, cur, 0, stride);
            for (int x = 0; x < stride; x++) {
                int a = x >= ch ? cur[x - ch] : 0, up = prev[x], c = x >= ch ? prev[x - ch] : 0;
                int v = cur[x];
                if (f == 1) { v += a; }
                else if (f == 2) { v += up; }
                else if (f == 3) { v += (a + up) >> 1; }
                else if (f == 4) {
                    int p = a + up - c, pa = Math.Abs(p - a), pb = Math.Abs(p - up), pc = Math.Abs(p - c);
                    v += (pa <= pb && pa <= pc) ? a : (pb <= pc ? up : c);
                }
                else if (f != 0) { throw new Exception("PNG filter " + f); }
                cur[x] = (byte)v;
            }
            for (int x = 0; x < w; x++) {
                int r, g, bl, al = 255, o = x * ch;
                if (type == 0) { r = g = bl = cur[o]; if (trns != null && trns.Length >= 2 && cur[o] == trns[1]) { al = 0; } }
                else if (type == 2) { r = cur[o]; g = cur[o + 1]; bl = cur[o + 2]; if (trns != null && trns.Length >= 6 && r == trns[1] && g == trns[3] && bl == trns[5]) { al = 0; } }
                else if (type == 3) { int k = cur[o]; r = palette[k * 3]; g = palette[k * 3 + 1]; bl = palette[k * 3 + 2]; if (trns != null && k < trns.Length) { al = trns[k]; } }
                else if (type == 4) { r = g = bl = cur[o]; al = cur[o + 1]; }
                else { r = cur[o]; g = cur[o + 1]; bl = cur[o + 2]; al = cur[o + 3]; }
                px[y * w + x] = (al << 24) | (r << 16) | (g << 8) | bl;
            }
            byte[] t = prev; prev = cur; cur = t;
        }
        return px;
    }

    // A part of ARGB pixels -> an RGB PNG (on white), filter 0, zlib (header + Adler-32).
    static byte[] EncodePng(int[] px, int srcW, int x0, int y0, int w, int h) {
        byte[] rows = new byte[(w * 3 + 1) * h];
        int o = 0;
        for (int y = 0; y < h; y++) {
            rows[o++] = 0;
            for (int x = 0; x < w; x++) {
                int c = px[(y0 + y) * srcW + x0 + x];
                int a = (c >> 24) & 255;
                rows[o++] = OnWhite((c >> 16) & 255, a);
                rows[o++] = OnWhite((c >> 8) & 255, a);
                rows[o++] = OnWhite(c & 255, a);
            }
        }
        MemoryStream z = new MemoryStream();
        z.WriteByte(0x78); z.WriteByte(0x9C);
        using (DeflateStream ds = new DeflateStream(z, CompressionMode.Compress, true)) { ds.Write(rows, 0, rows.Length); }
        uint s1 = 1, s2 = 0;
        foreach (byte v in rows) { s1 = (s1 + v) % 65521; s2 = (s2 + s1) % 65521; }
        WriteU32(z, (s2 << 16) | s1);
        MemoryStream png = new MemoryStream();
        png.Write(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }, 0, 8);
        MemoryStream ihdr = new MemoryStream();
        WriteU32(ihdr, (uint)w); WriteU32(ihdr, (uint)h);
        ihdr.Write(new byte[] { 8, 2, 0, 0, 0 }, 0, 5);
        Chunk(png, "IHDR", ihdr.ToArray());
        Chunk(png, "IDAT", z.ToArray());
        Chunk(png, "IEND", new byte[0]);
        return png.ToArray();
    }
    static byte OnWhite(int v, int a) { return (byte)((v * a + 255 * (255 - a) + 127) / 255); }
    static void WriteU32(Stream s, uint v) { s.WriteByte((byte)(v >> 24)); s.WriteByte((byte)(v >> 16)); s.WriteByte((byte)(v >> 8)); s.WriteByte((byte)v); }
    static uint[] crcTable;
    static void Chunk(Stream s, string tag, byte[] data) {
        if (crcTable == null) {
            uint[] t = new uint[256];
            for (uint n = 0; n < 256; n++) { uint c = n; for (int k = 0; k < 8; k++) { c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1; } t[n] = c; }
            crcTable = t;
        }
        byte[] tb = Encoding.ASCII.GetBytes(tag);
        WriteU32(s, (uint)data.Length);
        s.Write(tb, 0, 4); s.Write(data, 0, data.Length);
        uint crc = 0xFFFFFFFFu;
        foreach (byte v in tb) { crc = crcTable[(crc ^ v) & 0xFF] ^ (crc >> 8); }
        foreach (byte v in data) { crc = crcTable[(crc ^ v) & 0xFF] ^ (crc >> 8); }
        WriteU32(s, crc ^ 0xFFFFFFFFu);
    }
}
'@
    if ($refs.Count) { Add-Type -ReferencedAssemblies $refs -TypeDefinition $code } else { Add-Type -TypeDefinition $code }
    $script:imageTool = $true
}
# A Figma link's file and node (".../board/<file>/<name>?node-id=35-2839").
function Get-FigmaNode([string]$Url) {
    $m = [regex]::Match($Url, 'figma\.com/(?:board|design|file|proto|slides)/([0-9A-Za-z]+)[^?]*\?(?:[^#]*&)?node-id=(\d+)(?:-|:|%3A)(\d+)')
    if (-not $m.Success) { return $null }
    return [pscustomobject]@{ File = $m.Groups[1].Value; Node = "$($m.Groups[2].Value):$($m.Groups[3].Value)"; Slug = "$($m.Groups[2].Value)-$($m.Groups[3].Value)" }
}
# The Figma personal access token: "lazyspec: figmaToken:" in config.yaml (in git: everyone with the
# repository has it), else FIGMA_TOKEN (the process's, else the user's).
function Get-FigmaToken {
    $t = (Get-ProjectConfig).Values['figmaToken']
    if (-not $t) { $t = $env:FIGMA_TOKEN }
    if (-not $t) { $t = [Environment]::GetEnvironmentVariable('FIGMA_TOKEN', 'User') }
    return [string]$t
}
# Any diagrams in the project's config?
function Test-Diagrams {
    $m = (Get-ProjectConfig).Maps['diagrams']
    return [bool]($m.All.Count -or @($m.Groups.Values | Where-Object { $_.Count }).Count)
}
function Save-FigmaImage($Node, [string]$Target) {
    $token = Get-FigmaToken
    if (-not $token) { throw 'no Figma token (lazyspec: figmaToken: in openspec/config.yaml, or FIGMA_TOKEN) to download it' }
    if ($script:figmaRefused) { throw 'Figma refused the token' }
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    $api = "https://api.figma.com/v1/images/$($Node.File)?ids=$([Uri]::EscapeDataString($Node.Node))&format=png&scale=2"
    try { $r = Invoke-RestMethod -Uri $api -Headers @{ 'X-Figma-Token' = $token } -UseBasicParsing }
    catch {
        # 401 / 403: the token is wrong, expired or can't read the file: not again for the other diagrams.
        if ("$($_.Exception.Message)" -match '\((401|403)\)') { $script:figmaRefused = $true; throw "Figma refused the token ($($Matches[1])): check it in Figma (Settings, Security)" }
        throw
    }
    $url = $r.images.($Node.Node)
    if (-not $url) { throw "Figma rendered no image for node $($Node.Node) $($r.err)" }
    [void](New-Item -ItemType Directory -Force -Path (Split-Path $Target))
    # Next to it first: the saved one stays when the download or the cut fails.
    $part = "$Target.download"
    try {
        Invoke-WebRequest -Uri $url -OutFile $part -UseBasicParsing
        try { Initialize-ImageTool; [LazySpecImage]::Trim($part, 24) } catch { Write-Host "  ! $(Split-Path $Target -Leaf): margins not cut ($($_.Exception.Message))" }
        Move-Item -LiteralPath $part -Destination $Target -Force
    }
    finally { if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue } }
}
# The pictures from Figma (downloaded at scale 2, their margins cut): a path's change and Figma file
# (Get-FigmaScale); the ones downloaded in this export (each once).
$script:figmaFiles = @{}
$script:figmaFetched = @{}
# A diagram's image file, or '' (with a note in the output why not).
function Get-Diagram([string]$Key, [string]$Change, [string]$BaseDir) {
    $v = Get-ConfigEntry 'diagrams' $Key $Change
    if (-not $v) { return '' }
    $node = Get-FigmaNode $v
    if (-not $node) {
        # An image file: relative to the change's folder, else to the project's root.
        foreach ($p in @((Join-Path $BaseDir $v), (Join-Path $Root $v), $v)) { if (Test-Path -LiteralPath $p -PathType Leaf -ErrorAction SilentlyContinue) { return (Resolve-Path -LiteralPath $p).Path } }
        Write-Host "  ! diagram $($Key): $v not found"
        return ''
    }
    $file = Join-Path (Join-Path $BaseDir 'diagrams') "$Key.$($node.Slug).png"
    $script:figmaFiles[$file] = [pscustomobject]@{ Key = $Key; Change = $Change; BaseDir = $BaseDir; File = $node.File }
    if ((Test-Path -LiteralPath $file) -and (-not $script:diagramsRefresh -or $script:figmaFetched.ContainsKey($file))) { return $file }
    # The saved ones only (-KeepDiagrams): no Figma; none saved, no diagram.
    if ($script:diagramsOffline) {
        if (Test-Path -LiteralPath $file) { return $file }
        Write-Host "  ! diagram $($Key): none saved yet"
        return ''
    }
    $script:figmaFetched[$file] = $true
    try { Save-FigmaImage $node $file; Write-Host "  $($g.caret) diagram $($Key): downloaded from Figma ($($node.Node))"; return $file }
    catch {
        if (Test-Path -LiteralPath $file) {
            # After a refused token once, the saved ones without a word each.
            if ($script:figmaRefused -and $_.Exception.Message -eq 'Figma refused the token') { return $file }
            Write-Host "  ! diagram $($Key): not refreshed ($($_.Exception.Message)); the saved one is used"; return $file
        }
        Write-Host "  ! diagram $($Key): $($_.Exception.Message)"
        return ''
    }
}
# A Figma picture's scale on the page (page pixels per its pixels): the one at which its change's whole
# diagram (diagrams: change, from the same Figma file) fits the page, so that every part of the process has
# its boxes as large as there; without one, two thirds of its size on the board (scale 2 / 3).
function Get-FigmaScale([string]$Path) {
    $info = $script:figmaFiles[$Path]
    $k = 1.0 / 3
    if (-not $info -or -not $info.Change) { return $k }
    $main = $Path
    if ($info.Key -ne 'change') { $main = Get-Diagram 'change' $info.Change $info.BaseDir }
    if (-not $main -or -not $script:figmaFiles.ContainsKey($main) -or $script:figmaFiles[$main].File -ne $info.File) { return $k }
    try { Initialize-ImageTool; $size = [LazySpecImage]::Size($main) } catch { return $k }
    return [Math]::Min(640.0 / $size[0], 737.0 / $size[1])
}
# A diagram in the document, the page's width and 195 mm high at most (room for its chapter's heading above it
# on the same page): Word gets the file (and embeds it), the others the image itself.
# $Density: the picture's pixels per pixel of the page (the models' diagram: an SVG at 1.5x its design size,
# its text about as large as the document's; for Word a PNG of it at 2x).
# $Picture: a Markdown document's picture: its caption as it is (no "Diagram: ").
function Get-DiagramHtml([string]$Path, [string]$Caption, [double]$Density = 1, [bool]$Picture = $false) {
    if (-not $Path) { return '' }
    if ($script:figmaFiles.ContainsKey($Path)) { $Density = 1.0 / (Get-FigmaScale $Path) }
    $attr = ''
    try {
        Initialize-ImageTool
        $size = [LazySpecImage]::Size($Path)
        $k = [Math]::Min(1.0 / $Density, [Math]::Min(640.0 / $size[0], 737.0 / $size[1]))
        $attr = " width=`"$([int]($size[0] * $k))`" height=`"$([int]($size[1] * $k))`""
    } catch { }
    if ($script:exportFormat -eq 'Word') { $src = Get-FileUri $Path }
    else {
        $mime = @{ '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'; '.svg' = 'image/svg+xml'; '.webp' = 'image/webp' }[[IO.Path]::GetExtension($Path).ToLower()]
        if (-not $mime) { $mime = 'image/png' }
        $src = "data:$mime;base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
    }
    $cap = "$(Get-ExportText 'diagram'): $Caption"
    if ($Picture) { $cap = $Caption }
    $capHtml = ''
    if ($cap) { $capHtml = "<p class=`"caption`">$(Html $cap)</p>" }
    return "<div class=`"diagram`"><img src=`"$src`"$attr alt=`"$(Html $Caption)`">$capHtml</div>`n"
}
# A small contents: links, one a line.
function Get-TocHtml($Entries) {
    if (-not @($Entries).Count) { return '' }
    return '<ul class="toc-list">' + (-join @($Entries | ForEach-Object { "<li><a href=`"#$($_.Id)`">$(ConvertTo-HtmlInline $_.Text)</a></li>" })) + "</ul>`n"
}
# A change's capabilities: a small contents, then each one: its title, its diagram, its delta spec.
# Several changes as one: one contents of all their capabilities.
function Get-CapabilitiesHtml($Changes) {
    $Changes = @($Changes)
    $sb = New-Object Text.StringBuilder
    $caps = @(foreach ($ch in $Changes) { foreach ($cap in $ch.Caps) {
                [pscustomobject]@{ Cap = $cap; Change = $ch; Id = "cap-$($ch.Name)-$($cap.Name)"; Text = (Get-FriendlyTitle $cap.Name $cap.Name $ch.Name) } } })
    # Their contents, under a heading ("Capabilities"), after the change's diagram.
    if ($caps.Count) { [void]$sb.Append("<h3>$(Html (Get-ExportHeading 'Capabilities'))</h3>`n") }
    [void]$sb.Append((Get-TocHtml $caps))
    foreach ($c in $caps) {
        [void]$sb.Append("<h2 class=`"cap`" id=`"$($c.Id)`"><a name=`"$($c.Id)`"></a>$(Html (Get-ExportText 'capability')): $(Html $c.Text)</h2>`n")
        [void]$sb.Append((Get-DiagramHtml (Get-Diagram $c.Cap.Name $c.Change.Name $c.Change.Dir) $c.Text))
        [void]$sb.Append((ConvertTo-HtmlBody (Remove-DocTitle (Read-Text $c.Cap.Path)) 1))
    }
    return $sb.ToString()
}
# The export's language: the workflow schema's "language:" (LazySpec's own key), else lazyspec.json
# export.language, else en. Its texts and OpenSpec's fixed English headings: export-texts.json (UTF-8).
$script:exportLang = 'en'
$script:exportFriendly = $false
$script:exportTexts = $null
function Load-ExportTexts {
    if ($null -ne $script:exportTexts) { return }
    $script:exportTexts = @{}
    try { $j = (Read-Text (Join-Path $kitDir 'export-texts.json')) | ConvertFrom-Json } catch { return }
    if (-not $j) { return }
    foreach ($p in $j.PSObject.Properties) { if (-not $p.Name.StartsWith('$')) { $script:exportTexts[$p.Name] = $p.Value } }
}
function Get-ExportLanguage($Item) {
    $wf = $null
    if ($Item -and $Item.Type -ne 'spec') { $wf = $Item.Workflow } elseif ($hasRoot) { $wf = Get-Workflow (Join-Path $osDir 'changes\-') }
    $l = ''
    if ($wf -and $wf.Language) { $l = $wf.Language } else { $l = Get-ExportSetting 'language' '' }
    $l = ($l.ToLower() -split '[-_]')[0]
    if (-not $l) { $l = 'en' }
    return $l
}
# A count with its word, in the language's form: "1 task", "2 zadatka", "5 zadataka". export-texts.json:
# "<key>" (many), "<key>.one", "<key>.few" (hr: 2-4, not 12-14); a missing form: "<key>".
function Get-CountText([int]$N, [string]$Key) {
    $form = 'many'
    if ($script:exportLang -eq 'hr') {
        if ($N % 10 -eq 1 -and $N % 100 -ne 11) { $form = 'one' }
        elseif ($N % 10 -ge 2 -and $N % 10 -le 4 -and ($N % 100 -lt 12 -or $N % 100 -gt 14)) { $form = 'few' }
    }
    elseif ($N -eq 1) { $form = 'one' }
    $word = Get-ExportText $Key
    if ($form -ne 'many') { $word = Get-ExportText "$Key.$form" $word }
    return "$N $word"
}
# A text of the export in its language (else English, else $Default).
function Get-ExportText([string]$Key, [string]$Default) {
    foreach ($l in @($script:exportLang, 'en')) {
        $t = $script:exportTexts[$l]
        if ($t -and $t.labels -and $t.labels.$Key) { return [string]$t.labels.$Key }
    }
    if ($Default) { return $Default }
    return $Key
}
# OpenSpec's English headings (## Why, ## ADDED Requirements ...) in the export's language; others as written.
function Get-ExportHeading([string]$Heading) {
    $t = $script:exportTexts[$script:exportLang]
    if (-not $t -or -not $t.headings) { return $Heading }
    $v = $t.headings.(($Heading -replace '\s+', ' ').Trim().ToLower())
    if ($v) { return [string]$v }
    return $Heading
}

# --- translation: DeepL (an export in another language, -AddLanguage) and Hasek (ispravi.me) for Croatian ---
# Settings: the "translation:" block of openspec/config.yaml (shared with the netmedia plugin's translate
# skill): provider (deepl), keyEnv (the environment variable with the key, default DEEPL_AUTH_KEY), english
# (en-GB), formality, hasek (ask | always | never). The key only in that environment variable - never in
# config.yaml (it is in git). Tests: LAZYSPEC_DEEPL_FAKE=1 / LAZYSPEC_HASEK_FAKE=1 (no network).
$script:exportTranslate = $false
$script:exportSourceLang = ''
$script:deeplLangs = $null
$script:deeplSupport = $null
$script:translationCache = $null
$script:translationCachePath = ''
$script:translatedTexts = $null
function Get-TranslationSetting([string]$Name, [string]$Default) {
    $v = (Get-ProjectConfig).Translation[$Name]
    if ($v) { return [string]$v }
    return $Default
}
function Get-DeepLKey {
    foreach ($k in @('authKey', 'apiKey', 'key')) {
        if ((Get-ProjectConfig).Translation[$k]) { throw "openspec/config.yaml has a DeepL key (translation: $k) - config.yaml is in git. Remove it, rotate the key and set the $(Get-TranslationSetting 'keyEnv' 'DEEPL_AUTH_KEY') environment variable instead." }
    }
    if ($env:LAZYSPEC_DEEPL_FAKE) { return 'fake:fx' }
    $name = Get-TranslationSetting 'keyEnv' 'DEEPL_AUTH_KEY'
    foreach ($n in @($name, 'DEEPL_AUTH_KEY')) {
        $v = [Environment]::GetEnvironmentVariable($n)
        if (-not $v) { $v = [Environment]::GetEnvironmentVariable($n, 'User') }
        if ($v) { return [string]$v }
    }
    return ''
}
function Test-DeepLReady { return ((Get-TranslationSetting 'provider' '') -eq 'deepl') -and [bool](Get-DeepLKey) }
# DeepL's code: en -> en-GB (translation: english), pt -> pt-PT; others as they are.
function Get-DeepLCode([string]$Lang) {
    $l = $Lang.ToLower()
    if ($l -eq 'en') { return (Get-TranslationSetting 'english' 'en-GB') }
    if ($l -eq 'pt') { return 'pt-PT' }
    return $l
}
function Invoke-DeepL([string]$Method, [string]$Path, $Body) {
    $key = Get-DeepLKey
    if ($env:LAZYSPEC_DEEPL_FAKE) {
        # Fake DeepL for the tests: en/de stable with markup handling, hr beta without; "[XX] " + the text.
        if ($Path -like '/v3/languages*') {
            return @(
                [pscustomobject]@{ lang = 'en'; name = 'English'; status = 'stable'; usable_as_source = $true; usable_as_target = $false; features = [pscustomobject]@{ tag_handling = @{} } },
                [pscustomobject]@{ lang = 'en-gb'; name = 'English (British)'; status = 'stable'; usable_as_source = $false; usable_as_target = $true; features = [pscustomobject]@{ tag_handling = @{} } },
                [pscustomobject]@{ lang = 'de'; name = 'German'; status = 'stable'; usable_as_source = $true; usable_as_target = $true; features = [pscustomobject]@{ tag_handling = @{}; formality = @{} } },
                [pscustomobject]@{ lang = 'it'; name = 'Italian'; status = 'stable'; usable_as_source = $true; usable_as_target = $true; features = [pscustomobject]@{ tag_handling = @{} } },
                [pscustomobject]@{ lang = 'hr'; name = 'Croatian'; status = 'beta'; usable_as_source = $true; usable_as_target = $true; features = [pscustomobject]@{} })
        }
        $script:deeplFakeCalls++
        $tag = '[' + ([string]$Body.target_lang).Split('-')[0] + '] '
        return [pscustomobject]@{ translations = @(foreach ($t in $Body.text) {
                    if ($Body.tag_handling) { [pscustomobject]@{ text = [regex]::Replace($t, '(<[^>]*>)([^<]*\p{L}[^<]*)(?=<)', { param($m) if ($m.Groups[1].Value -match 'translate="no"') { $m.Value } else { $m.Groups[1].Value + $tag + $m.Groups[2].Value } }) } }
                    else { [pscustomobject]@{ text = $tag + $t } } }) }
    }
    if (-not $key) { throw "No DeepL key: set the $(Get-TranslationSetting 'keyEnv' 'DEEPL_AUTH_KEY') environment variable (setx $(Get-TranslationSetting 'keyEnv' 'DEEPL_AUTH_KEY') `"<key>`", then a new terminal)." }
    $base = 'https://api.deepl.com'
    if ($key.EndsWith(':fx')) { $base = 'https://api-free.deepl.com' }
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    $p = @{ Uri = $base + $Path; Method = $Method; Headers = @{ Authorization = "DeepL-Auth-Key $key" }; UseBasicParsing = $true }
    if ($null -ne $Body) { $p.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 5 -Compress)); $p.ContentType = 'application/json; charset=utf-8' }
    try { return Invoke-RestMethod @p }
    catch {
        $code = 0
        try { $code = [int]$_.Exception.Response.StatusCode } catch { }
        $why = @{ 403 = 'the key is wrong or for the other plan (free keys end with :fx)'; 456 = 'the character quota is used up'; 429 = 'too many requests, try again later' }[$code]
        if (-not $why) { $why = $_.Exception.Message }
        throw "DeepL $Method $Path`: $why"
    }
}
function Get-DeepLLanguages {
    if ($null -eq $script:deeplLangs) {
        $j = Invoke-DeepL 'GET' '/v3/languages?resource=translate_text&include=beta' $null
        if ($j -isnot [array] -and $j -and $j.PSObject.Properties.Name -contains 'languages') { $j = $j.languages }
        $script:deeplLangs = @($j)
    }
    return $script:deeplLangs
}
# How DeepL translates From -> To: Status stable | beta (an additional language: DeepL's next-generation
# model, Croatian is one) | unsupported; Tags: markup handling on both sides; Note: what beta lacks.
function Get-DeepLSupport([string]$To, [string]$From) {
    $langs = Get-DeepLLanguages
    $find = {
        param([string]$Code, [string]$Role)
        $c = $Code.ToLower()
        $hit = @($langs | Where-Object { $_.lang.ToLower() -eq $c -and $_."usable_as_$Role" -ne $false })
        if (-not $hit.Count) { $hit = @($langs | Where-Object { $_.lang.ToLower().Split('-')[0] -eq $c.Split('-')[0] -and $_."usable_as_$Role" -ne $false }) }
        if ($hit.Count) { return $hit[0] }
        return $null
    }
    $t = & $find (Get-DeepLCode $To) 'target'
    $f = $null
    if ($From) { $f = & $find $From 'source' }
    if (-not $t -or ($From -and -not $f)) { return [pscustomobject]@{ Status = 'unsupported'; Tags = $false; Note = "DeepL does not translate $(if (-not $t) { "into $To" } else { "from $From" })" } }
    $has = { param($L, [string]$K) (-not $L) -or ($L.features -and ($L.features.PSObject.Properties.Name -contains $K)) }
    $beta = ($t.status -ne 'stable') -or ($f -and $f.status -ne 'stable')
    $tags = (& $has $t 'tag_handling') -and (& $has $f 'tag_handling')
    $note = ''
    if ($beta) {
        $missing = @()
        if (-not ((& $has $t 'glossary') -and (& $has $f 'glossary'))) { $missing += 'glossaries' }
        if (-not (& $has $t 'formality')) { $missing += 'formal/informal tone' }
        if (-not $tags) { $missing += 'markup handling (translated piece by piece)' }
        $names = @(@($f, $t) | Where-Object { $_ -and $_.status -ne 'stable' } | ForEach-Object { $_.name })
        $note = "$($names -join ' / '): DeepL beta (an additional language, its next-generation model) - quality may vary"
        if ($missing.Count) { $note += "; no $($missing -join ', no ')" }
    }
    return [pscustomobject]@{ Status = $(if ($beta) { 'beta' } else { 'stable' }); Tags = [bool]$tags; Formality = [bool](& $has $t 'formality'); Note = $note }
}
# A beta language needs the user's yes: -Beta, else asked here (a console), else an error saying so.
function Confirm-DeepLBeta($Support) {
    if ($Support.Status -ne 'beta' -or $Beta.IsPresent) { return }
    $interactive = $false
    try { $interactive = -not [Console]::IsInputRedirected -and [Environment]::UserInteractive } catch { }
    if ($interactive -and -not $env:LAZYSPEC_DEEPL_FAKE) {
        Write-Host "  ! $($Support.Note)" -ForegroundColor Yellow
        $a = Read-Host '  Translate with DeepL anyway? [y/N]'
        if ($a -match '^(?i)(y|yes|d|da)$') { return }
        throw 'Not translated: DeepL beta language declined.'
    }
    throw "$($Support.Note). Add -Beta to translate anyway."
}
# The cache: the same text, the same pair, translated once (DeepL counts characters). Per user, outside the project.
function Get-TranslationCacheKey([string]$Text, [bool]$Html) {
    $sha = [Security.Cryptography.SHA1]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("$([int]$Html)|$Text"))).Replace('-', '') } finally { $sha.Dispose() }
}
function Open-TranslationCache([string]$From, [string]$To) {
    $dir = Join-Path $(if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { $localData }) 'LazySpec\translations'
    [void](New-Item -ItemType Directory -Force -Path $dir)
    $script:translationCachePath = Join-Path $dir "$From-$To.json"
    $script:translationCache = @{}
    if (Test-Path -LiteralPath $script:translationCachePath) {
        try { foreach ($p in ((Read-Text $script:translationCachePath) | ConvertFrom-Json).PSObject.Properties) { $script:translationCache[$p.Name] = [string]$p.Value } } catch { }
    }
}
function Save-TranslationCache {
    if (-not $script:translationCachePath -or $null -eq $script:translationCache) { return }
    [IO.File]::WriteAllText($script:translationCachePath, ($script:translationCache | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding $false))
}
# Texts from the export's source language into its language: the cache first, then DeepL (50 texts, ~100 KB a request).
function Invoke-Translation([string[]]$Texts, [bool]$Html) {
    $out = New-Object string[] $Texts.Count
    $todo = New-Object Collections.Generic.List[int]
    for ($i = 0; $i -lt $Texts.Count; $i++) {
        $k = Get-TranslationCacheKey $Texts[$i] $Html
        if ($script:translationCache.ContainsKey($k)) { $out[$i] = $script:translationCache[$k] } else { $todo.Add($i) }
    }
    $at = 0
    while ($at -lt $todo.Count) {
        $batch = New-Object Collections.Generic.List[int]
        $size = 0
        while ($at -lt $todo.Count -and $batch.Count -lt 50 -and ($batch.Count -eq 0 -or $size + $Texts[$todo[$at]].Length * 3 -lt 100000)) { $size += $Texts[$todo[$at]].Length * 3; $batch.Add($todo[$at]); $at++ }
        $body = [ordered]@{ text = @($batch | ForEach-Object { $Texts[$_] }); target_lang = (Get-DeepLCode $script:exportLang).ToUpper(); source_lang = $script:exportSourceLang.ToUpper() }
        if ($script:deeplSupport.Status -eq 'beta') { $body.enable_beta_languages = $true }
        if ($Html) { $body.tag_handling = 'html' }
        $f = Get-TranslationSetting 'formality' ''
        if ($f -and $script:deeplSupport.Formality) { $body.formality = $f }
        $r = Invoke-DeepL 'POST' '/v2/translate' $body
        for ($j = 0; $j -lt $batch.Count; $j++) {
            $t = [string]@($r.translations)[$j].text
            $out[$batch[$j]] = $t
            $script:translationCache[(Get-TranslationCacheKey $Texts[$batch[$j]] $Html)] = $t
        }
    }
    if ($null -ne $script:translatedTexts) { foreach ($t in $out) { if (-not $Html) { $script:translatedTexts.Add($t) } } }
    return , $out
}
# A title or a short value in the export's language (as it is when the export isn't translated).
function Get-TranslatedText([string]$Text) {
    if (-not $script:exportTranslate -or -not $Text -or $Text -notmatch '\p{L}') { return $Text }
    return (Invoke-Translation @($Text) $false)[0]
}
# A chapter's HTML in the export's language. Code, pre and LazySpec's own labels are kept. With markup
# handling: the HTML as it is (DeepL keeps the tags); without (beta languages): each text node alone.
function Convert-TranslatedHtml([string]$Html) {
    if (-not $script:exportTranslate -or $Html -notmatch '\p{L}') { return $Html }
    if ($script:deeplSupport.Tags) {
        $marked = [regex]::Replace($Html, '<(code|pre)\b', '<$1 translate="no"')
        $marked = $marked.Replace('<span class="tag">', '<span class="tag" translate="no">')
        # Pieces under ~100 KB, cut between top-level elements.
        $pieces = New-Object Collections.Generic.List[string]
        $cur = New-Object Text.StringBuilder
        foreach ($part in [regex]::Split($marked, '(?=\n<(?:h[1-6]|p|ul|ol|table|div|pre)\b)')) {
            if ($cur.Length -and $cur.Length + $part.Length -gt 90000) { $pieces.Add($cur.ToString()); [void]$cur.Clear() }
            [void]$cur.Append($part)
        }
        if ($cur.Length) { $pieces.Add($cur.ToString()) }
        $res = Invoke-Translation $pieces.ToArray() $true
        if ($null -ne $script:translatedTexts) { foreach ($r in $res) { $script:translatedTexts.Add([regex]::Replace([regex]::Replace($r, '(?s)<(code|pre)\b.*?</\1>', ' '), '<[^>]+>', ' ')) } }
        return ((-join $res) -replace ' translate="no"', '')
    }
    $tokens = [regex]::Split($Html, '(<[^>]+>)')
    $skip = New-Object Collections.Generic.Stack[string]
    $idx = New-Object Collections.Generic.List[int]
    $texts = New-Object Collections.Generic.List[string]
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        $t = $tokens[$i]
        if ($t.StartsWith('<')) {
            $m = [regex]::Match($t, '^<(/?)([a-zA-Z0-9]+)')
            if (-not $m.Success -or $t.EndsWith('/>')) { continue }
            $name = $m.Groups[2].Value.ToLower()
            if ($m.Groups[1].Value) { if ($skip.Count -and $skip.Peek() -eq $name) { [void]$skip.Pop() } }
            elseif ($skip.Count -or $name -in @('code', 'pre', 'script', 'style') -or $t -match 'class="tag"') {
                if ($name -notin @('br', 'img', 'hr', 'col', 'meta', 'link', 'input')) { $skip.Push($name) }
            }
            continue
        }
        if ($skip.Count -or $t -notmatch '\p{L}') { continue }
        $idx.Add($i)
        $texts.Add([Net.WebUtility]::HtmlDecode($t).Trim())
    }
    if (-not $texts.Count) { return $Html }
    $res = Invoke-Translation $texts.ToArray() $false
    for ($k = 0; $k -lt $idx.Count; $k++) {
        $orig = $tokens[$idx[$k]]
        $lead = [regex]::Match($orig, '^\s*').Value
        $trail = [regex]::Match($orig, '\s*$').Value
        $tokens[$idx[$k]] = $lead + (Html $res[$k]) + $trail
    }
    return (-join $tokens)
}
# Starts translating the export: From (the documents' language) -> $script:exportLang. Needs DeepL set up.
function Start-ExportTranslation([string]$From) {
    $script:exportTranslate = $false
    if ((Get-TranslationSetting 'provider' '') -ne 'deepl') { throw "The export is in $From and -Language $($script:exportLang) asks for another language: set up DeepL first (translation: provider: deepl in openspec/config.yaml, the key in DEEPL_AUTH_KEY)." }
    if (-not (Get-DeepLKey)) { throw "No DeepL key: set the $(Get-TranslationSetting 'keyEnv' 'DEEPL_AUTH_KEY') environment variable (setx $(Get-TranslationSetting 'keyEnv' 'DEEPL_AUTH_KEY') `"<key>`", then a new terminal)." }
    $script:exportSourceLang = $From
    $script:deeplSupport = Get-DeepLSupport $script:exportLang $From
    if ($script:deeplSupport.Status -eq 'unsupported') { throw "$($script:deeplSupport.Note): the export can't be translated." }
    Confirm-DeepLBeta $script:deeplSupport
    Open-TranslationCache $From $script:exportLang
    $script:translatedTexts = New-Object Collections.Generic.List[string]
    $script:exportTranslate = $true
    $how = 'DeepL'
    if ($script:deeplSupport.Status -eq 'beta') { $how += ' beta' }
    if (-not $script:deeplSupport.Tags) { $how += ', piece by piece' }
    Write-Host "  $($g.caret) translated $From -> $($script:exportLang) ($how)"
}

# Hasek (ispravi.me): the Croatian check of a translation into Croatian. A report next to the document; it
# changes nothing (translation: hasek: ask | always | never; never: not run).
function Get-HasekName { return "Ha$([char]0x0161)ek" }
function Invoke-HasekCheck([string]$Text) {
    if ($env:LAZYSPEC_HASEK_FAKE) {
        $errs = @()
        $at = $Text.IndexOf('greska')
        if ($at -ge 0) { $errs += [pscustomobject]@{ class = 'spelling'; suspicious = 'greska'; suggestions = @("gre$([char]0x0161)ka"); position = @($at); message = '' } }
        return [pscustomobject]@{ status = [pscustomobject]@{ code = 200 }; response = [pscustomobject]@{ error = $errs } }
    }
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    $body = @{ text = $Text; context = $true; punctuation = $true; showinfo = $true; app = 'HasekLazySpec' } | ConvertTo-Json -Compress
    try { return Invoke-RestMethod -Uri 'https://ispravi.me/api/ispravi' -Method Post -Body ([Text.Encoding]::UTF8.GetBytes($body)) -ContentType 'application/json; charset=utf-8' -UseBasicParsing }
    catch {
        $code = 0
        try { $code = [int]$_.Exception.Response.StatusCode } catch { }
        $why = @{ 402 = 'ispravi.me limits this network for texts over 50 letters (ask ispravi@ispravi.me to approve it)'; 413 = 'the text is too long (350,000 characters at most)'; 429 = 'the usage limit is reached, try again later' }[$code]
        if (-not $why) { $why = $_.Exception.Message }
        throw "ispravi.me: $why"
    }
}
function Invoke-ExportHasek([string]$Target) {
    if ($script:exportLang -ne 'hr' -or -not $script:exportTranslate -or -not $script:translatedTexts -or -not $script:translatedTexts.Count) { return }
    $mode = (Get-TranslationSetting 'hasek' 'ask').ToLower()
    $name = Get-HasekName
    if ($mode -eq 'never') { return }
    if ($mode -ne 'always') {
        $interactive = $false
        try { $interactive = -not [Console]::IsInputRedirected -and [Environment]::UserInteractive } catch { }
        if (-not $interactive -or $env:LAZYSPEC_HASEK_FAKE) {
            if (-not $env:LAZYSPEC_HASEK_FAKE) { Write-Host "  ! $name check skipped (translation: hasek: ask; set it to always, or export in a console)"; return }
        }
        elseif ((Read-Host "  Check the Croatian translation with $name (ispravi.me)? [Y/n]") -match '^(?i)(n|no|ne)$') { return }
    }
    $text = ($script:translatedTexts | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ -match '\p{L}' } | Select-Object -Unique) -join "`n"
    if ($text.Length -gt 350000) { $text = $text.Substring(0, 350000) }
    try { $r = Invoke-HasekCheck $text } catch { Write-Host "  ! $name`: $($_.Exception.Message)" -ForegroundColor Yellow; return }
    $lines = $text.Split("`n")
    $found = @()
    foreach ($e in @($r.response.error)) {
        if (-not $e -or -not $e.suspicious) { continue }
        foreach ($p in @($e.position)) {
            # The position counts code points; the text's line around it is the context.
            $cp = [int]$p; $acc = 0; $ctx = ''
            foreach ($l in $lines) { $len = [Globalization.StringInfo]::new($l).LengthInTextElements + 1; if ($cp -lt $acc + $len) { $ctx = $l; break }; $acc += $len }
            $found += "- **$($e.suspicious)** $([char]0x2192) $(@($e.suggestions | Select-Object -First 3) -join ' | ')$(if ($e.message) { " - $($e.message)" })  `n  _$($ctx)_"
        }
    }
    $report = [IO.Path]::ChangeExtension($Target, '.hasek.md')
    $md = "# $name`: $(Split-Path $Target -Leaf)`n`nThe Croatian translation (DeepL) checked by ispravi.me: spelling, punctuation, grammar. Fix the documents' source or accept; nothing was changed.`n`n"
    if ($found.Count) { $md += ($found -join "`n") + "`n" } else { $md += "No findings.`n" }
    [IO.File]::WriteAllText($report, $md, (New-Object Text.UTF8Encoding $false))
    Write-Host "  $($g.caret) $name`: $($found.Count) finding(s) - $report"
}

# -AddLanguage <xx>: export-texts.json gets a block for that language, translated from English by DeepL
# (the labels, and OpenSpec's English headings). The kit's file: commit it (or -Update the projects).
function Add-ExportLanguage([string]$Lang) {
    $Lang = $Lang.ToLower()
    if ($Lang -notmatch '^[a-z]{2}$') { throw "-AddLanguage: a two-letter code (it, sl, fr ...)" }
    $path = Join-Path $kitDir 'export-texts.json'
    $raw = Read-Text $path
    $j = $raw | ConvertFrom-Json
    if ($j.PSObject.Properties.Name -contains $Lang -and -not $Force.IsPresent) { throw "export-texts.json already has '$Lang' (-Force replaces it)." }
    if ((Get-TranslationSetting 'provider' '') -ne 'deepl' -or -not (Get-DeepLKey)) { throw 'DeepL is not set up: translation: provider: deepl in openspec/config.yaml and the key in DEEPL_AUTH_KEY.' }
    $script:exportLang = $Lang
    $script:exportSourceLang = 'en'
    $script:deeplSupport = Get-DeepLSupport $Lang 'en'
    if ($script:deeplSupport.Status -eq 'unsupported') { throw $script:deeplSupport.Note }
    Confirm-DeepLBeta $script:deeplSupport
    Open-TranslationCache 'en' $Lang
    $labelKeys = @($j.en.labels.PSObject.Properties | Where-Object { $_.Name -ne 'dateFormat' } | ForEach-Object { $_.Name })
    $labelTexts = @($labelKeys | ForEach-Object { [string]$j.en.labels.$_ })
    # The headings: the keys other languages translate (lower case English headings), sent capitalized.
    $headKeys = @()
    foreach ($p in $j.PSObject.Properties) { if (-not $p.Name.StartsWith('$') -and $p.Value.headings) { $headKeys += @($p.Value.headings.PSObject.Properties | ForEach-Object { $_.Name }) } }
    $headKeys = @($headKeys | Select-Object -Unique)
    $headTexts = @($headKeys | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) })
    $res = Invoke-Translation (@($labelTexts) + @($headTexts)) $false
    Save-TranslationCache
    $labels = [ordered]@{}
    for ($i = 0; $i -lt $labelKeys.Count; $i++) { $labels[$labelKeys[$i]] = $res[$i] }
    $labels['dateFormat'] = [string]$j.en.labels.dateFormat
    $heads = [ordered]@{}
    for ($i = 0; $i -lt $headKeys.Count; $i++) { $heads[$headKeys[$i]] = $res[$labelKeys.Count + $i] }
    $block = "  `"$Lang`": {`n    `"labels`": $(([pscustomobject]$labels | ConvertTo-Json -Compress))," + "`n    `"headings`": $(([pscustomobject]$heads | ConvertTo-Json -Compress))`n  }"
    if ($j.PSObject.Properties.Name -contains $Lang) {
        # -Force: the old block out (from its key to the next language's key, or the end).
        $raw = [regex]::Replace($raw, "(?s),?\s*`"$Lang`"\s*:\s*\{.*?(?=,\s*`"[a-z]{2}`"\s*:\s*\{|\s*\}\s*$)", '')
    }
    $raw = [regex]::Replace($raw.TrimEnd(), '\}\s*$', ",`n$block`n}`n")
    [void]($raw | ConvertFrom-Json)
    [IO.File]::WriteAllText($path, $raw, (New-Object Text.UTF8Encoding $false))
    $how = $script:deeplSupport.Status
    Write-Host "$($g.check) export-texts.json: '$Lang' added ($($labelKeys.Count) labels, $($headKeys.Count) headings; DeepL $how). Have a native speaker read it, then commit it."
    if ($script:deeplSupport.Status -eq 'beta' -or $Lang -eq 'hr') { Write-Host "  ! Plural forms other than one/many are only built in for hr (Get-CountText)." }
}

# --- the models' diagram: drawn from models.md (its sections, field tables and relations lines) ---------
# Boxes: new models (green), changed models (yellow; only their changed fields), lookup lists (grey; their
# values); lines: the relations ("**Veze:**" / "**Relations:**" / "**Beziehungen:**" lines, and fields whose
# type is another model or list), their cardinality at the ends, new ones green, removed ones red.
$script:modelTool = $false
function Initialize-ModelDiagramTool {
    if ($script:modelTool) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
public static class LazySpecModelDiagram {
    class Box { public double X, Y, Width, Height; public double Right { get { return X + Width; } } public double CX { get { return X + Width / 2; } } public double CY { get { return Y + Height / 2; } } }
    class Node { public string Name, Kind, Status; public List<string[]> Lines = new List<string[]>(); public Box Box = new Box(); }
    class Edge { public string From, To, Card, Mark; }
    const string Sans = "'Segoe UI', -apple-system, Helvetica, Arial, sans-serif", Mono = "Consolas, Menlo, monospace";
    // Arial / Helvetica Bold's widths (1/1000 em) of ' ' .. '~': the bold texts' widths, 5 % more for Segoe UI.
    static readonly int[] Bold = {
        278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278, 556, 556, 556, 556, 556, 556, 556, 556,
        556, 556, 333, 333, 584, 584, 584, 611, 975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778,
        667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556, 333, 556, 611, 556, 611, 556, 333, 611,
        611, 278, 278, 556, 278, 889, 611, 611, 611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584 };
    // A text's width as drawn (GDI+ added a sixth of the size on either side; the boxes keep that room).
    static double BoldWidth(string t, double size) {
        double u = 0;
        foreach (char c in t) { u += c >= ' ' && c <= '~' ? Bold[c - ' '] : 611; }
        return u / 1000 * size * 1.05 + size / 3;
    }
    static double MonoWidth(string t, double size) { return t.Length * 0.6 * size + size / 3; }
    static string N(double v) { return v.ToString("0.##", CultureInfo.InvariantCulture); }
    static string X(string t) { return t.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("\"", "&quot;"); }
    // Lines: "M|name|model|new" (or lookup / modified), "F|mark|text" (a field or value of the last M),
    // "R|from|to|1:N|mark". Writes an SVG (its units the design's, shown at 1.5x).
    public static void Draw(string path, string[] lines) {
        var nodes = new List<Node>(); var byName = new Dictionary<string, Node>(); var edges = new List<Edge>();
        Node cur = null;
        foreach (string l in lines) {
            string[] p = l.Split('|');
            if (p[0] == "M") { cur = new Node { Name = p[1], Kind = p[2], Status = p[3] }; if (!byName.ContainsKey(p[1])) { nodes.Add(cur); byName[p[1]] = cur; } else { cur = byName[p[1]]; } }
            else if (p[0] == "F" && cur != null) { cur.Lines.Add(new string[] { p[1], p[2] }); }
            else if (p[0] == "R") { edges.Add(new Edge { From = p[1], To = p[2], Card = p[3], Mark = p[4] }); }
        }
        // Relations to models the document only names: small boxes of their own (existing models).
        foreach (Edge e in edges) foreach (string n in new string[] { e.From, e.To })
            if (!byName.ContainsKey(n)) { Node x = new Node { Name = n, Kind = "model", Status = "existing" }; nodes.Add(x); byName[n] = x; }
        if (nodes.Count == 0) { return; }
        double fHead = 10, fText = 8.5, fCard = 8;
        double pad = 6, lineH = 13, headH = 20, gapX = 46, gapY = 40;
        foreach (Node n in nodes) {
            double w = BoldWidth(n.Name, fHead) + 2 * pad;
            foreach (string[] ln in n.Lines) w = Math.Max(w, MonoWidth(ln[0] + " " + ln[1], fText) + 2 * pad);
            w = Math.Max(w, 110);
            double h = headH + n.Lines.Count * lineH + pad;
            if (n.Lines.Count == 0) h = headH;
            n.Box.Width = w; n.Box.Height = h;
        }
        // The order: the most connected first, then its neighbours (related boxes next to each other).
        var degree = new Dictionary<string, int>();
        foreach (Node n in nodes) degree[n.Name] = 0;
        foreach (Edge e in edges) { degree[e.From]++; degree[e.To]++; }
        var order = new List<Node>(); var seen = new Dictionary<string, bool>();
        var rest = new List<Node>(nodes);
        rest.Sort((a, b) => degree[b.Name].CompareTo(degree[a.Name]));
        foreach (Node start in rest) {
            if (seen.ContainsKey(start.Name)) continue;
            var queue = new Queue<Node>(); queue.Enqueue(start); seen[start.Name] = true;
            while (queue.Count > 0) {
                Node n = queue.Dequeue(); order.Add(n);
                var next = new List<Node>();
                foreach (Edge e in edges) {
                    string o = e.From == n.Name ? e.To : (e.To == n.Name ? e.From : null);
                    if (o != null && !seen.ContainsKey(o)) { seen[o] = true; next.Add(byName[o]); }
                }
                next.Sort((a, b) => degree[b.Name].CompareTo(degree[a.Name]));
                foreach (Node x in next) queue.Enqueue(x);
            }
        }
        // A grid: columns by count, each column as wide as its widest box, rows as high as their highest.
        int cols = order.Count <= 2 ? order.Count : (order.Count <= 6 ? 3 : 4);
        int rows = (order.Count + cols - 1) / cols;
        // The cells: the order's, then swapped (empty cells too) while that makes the lines shorter and keeps
        // them off the other boxes.
        int slots = cols * rows;
        Node[] cell = new Node[slots];
        for (int i = 0; i < order.Count; i++) cell[i] = order[i];
        Func<double> cost = () => {
            var at = new Dictionary<string, int>();
            for (int i = 0; i < slots; i++) if (cell[i] != null) at[cell[i].Name] = i;
            double total = 0;
            foreach (Edge e in edges) {
                if (e.From == e.To) continue;
                int a = at[e.From], b = at[e.To];
                double ax = a % cols, ay = a / cols, bx = b % cols, by = b / cols;
                total += Math.Sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by) * 1.4);
                for (int k = 0; k < slots; k++) {
                    if (cell[k] == null || k == a || k == b) continue;
                    if (Crosses(ax, ay, bx, by, k % cols, k / cols)) total += 6;
                }
            }
            return total;
        };
        Node[] bestCells = null; double bestAll = double.MaxValue;
        var rnd = new Random(7);
        for (int start = 0; start < 8; start++) {
            if (start > 0) for (int i = slots - 1; i > 0; i--) { int j = rnd.Next(i + 1); Node t0 = cell[i]; cell[i] = cell[j]; cell[j] = t0; }
            double best = cost();
            for (int round = 0; round < 12; round++) {
                bool better = false;
                for (int i = 0; i < slots; i++) for (int j = i + 1; j < slots; j++) {
                    if (cell[i] == null && cell[j] == null) continue;
                    Node t = cell[i]; cell[i] = cell[j]; cell[j] = t;
                    double c = cost();
                    if (c < best - 1e-9) { best = c; better = true; } else { t = cell[i]; cell[i] = cell[j]; cell[j] = t; }
                }
                if (!better) break;
            }
            if (best < bestAll - 1e-9) { bestAll = best; bestCells = (Node[])cell.Clone(); }
        }
        cell = bestCells;
        // Empty rows and columns out.
        var usedCols = new List<int>(); var usedRows = new List<int>();
        for (int i = 0; i < slots; i++) if (cell[i] != null) { if (!usedCols.Contains(i % cols)) usedCols.Add(i % cols); if (!usedRows.Contains(i / cols)) usedRows.Add(i / cols); }
        usedCols.Sort(); usedRows.Sort();
        order = new List<Node>();
        var colOf = new Dictionary<string, int>(); var rowOf = new Dictionary<string, int>();
        for (int i = 0; i < slots; i++) if (cell[i] != null) { order.Add(cell[i]); colOf[cell[i].Name] = usedCols.IndexOf(i % cols); rowOf[cell[i].Name] = usedRows.IndexOf(i / cols); }
        cols = usedCols.Count; rows = usedRows.Count;
        double[] colW = new double[cols]; double[] rowH = new double[rows];
        foreach (Node n in order) { colW[colOf[n.Name]] = Math.Max(colW[colOf[n.Name]], n.Box.Width); rowH[rowOf[n.Name]] = Math.Max(rowH[rowOf[n.Name]], n.Box.Height); }
        double margin = 20;
        foreach (Node n in order) {
            double x = margin, y = margin;
            for (int c = 0; c < colOf[n.Name]; c++) x += colW[c] + gapX;
            for (int r = 0; r < rowOf[n.Name]; r++) y += rowH[r] + gapY;
            n.Box.X = x + (colW[colOf[n.Name]] - n.Box.Width) / 2; n.Box.Y = y;
        }
        double W = margin * 2 - gapX, H = margin * 2 - gapY;
        foreach (double c in colW) W += c + gapX;
        foreach (double r in rowH) H += r + gapY;
        W = Math.Ceiling(W); H = Math.Ceiling(H);
        var sb = new StringBuilder();
        sb.Append("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" + N(W * 1.5) + "\" height=\"" + N(H * 1.5) + "\" viewBox=\"0 0 " + N(W) + " " + N(H) + "\" xml:space=\"preserve\">\n");
        sb.Append("<rect width=\"100%\" height=\"100%\" fill=\"#FFFFFF\"/>\n");
        // The relations first: the boxes over their ends.
        foreach (Edge e in edges) {
            if (e.From == e.To) continue;
            Box a = byName[e.From].Box, b = byName[e.To].Box;
            double[] pa = BoxEdge(a, b.CX, b.CY), pb = BoxEdge(b, a.CX, a.CY);
            string c = e.Mark == "+" ? "#2E7D32" : (e.Mark == "-" ? "#C62828" : "#78828C");
            string dash = e.Mark == "-" ? " stroke-dasharray=\"4.2 1.4\"" : (e.Mark == "~" ? " stroke-dasharray=\"1.4 1.4\"" : "");
            sb.Append("<line x1=\"" + N(pa[0]) + "\" y1=\"" + N(pa[1]) + "\" x2=\"" + N(pb[0]) + "\" y2=\"" + N(pb[1]) + "\" stroke=\"" + c + "\" stroke-width=\"1.4\"" + dash + "/>\n");
            string[] card = e.Card.Split(':');
            if (card.Length == 2) {
                Card(sb, card[0], pa, pb, fCard, c);
                Card(sb, card[1], pb, pa, fCard, c);
            }
        }
        foreach (Node n in nodes) {
            string border, head;
            if (n.Kind == "lookup") { border = "#5B6B7F"; head = n.Status == "new" ? "#E6F4EA" : "#EEF2F7"; }
            else if (n.Status == "new") { border = "#2E7D32"; head = "#E6F4EA"; }
            else if (n.Status == "modified") { border = "#B7791F"; head = "#FFF4D6"; }
            else { border = "#969EA8"; head = "#F5F6F8"; }
            Box r = n.Box;
            string dash = n.Kind == "lookup" ? " stroke-dasharray=\"4.5 1.5\"" : "";
            sb.Append("<rect x=\"" + N(r.X) + "\" y=\"" + N(r.Y) + "\" width=\"" + N(r.Width) + "\" height=\"" + N(r.Height) + "\" fill=\"#FFFFFF\"/>\n");
            sb.Append("<rect x=\"" + N(r.X) + "\" y=\"" + N(r.Y) + "\" width=\"" + N(r.Width) + "\" height=\"" + N(headH) + "\" fill=\"" + head + "\"/>\n");
            sb.Append("<rect x=\"" + N(r.X) + "\" y=\"" + N(r.Y) + "\" width=\"" + N(r.Width) + "\" height=\"" + N(r.Height) + "\" fill=\"none\" stroke=\"" + border + "\" stroke-width=\"1.5\"" + dash + "/>\n");
            if (n.Lines.Count > 0) sb.Append("<line x1=\"" + N(r.X) + "\" y1=\"" + N(r.Y + headH) + "\" x2=\"" + N(r.Right) + "\" y2=\"" + N(r.Y + headH) + "\" stroke=\"" + border + "\" stroke-width=\"1.5\"" + dash + "/>\n");
            // The texts on their baselines (GDI+ drew them from their top).
            sb.Append("<text x=\"" + N(r.X + pad + fHead / 6) + "\" y=\"" + N(r.Y + 3 + fHead * 1.08) + "\" font-family=\"" + Sans + "\" font-size=\"" + N(fHead) + "\" font-weight=\"bold\" fill=\"#1F2933\">" + X(n.Name) + "</text>\n");
            double y = r.Y + headH + 2;
            foreach (string[] ln in n.Lines) {
                string tc = ln[0] == "+" ? "#2E7D32" : (ln[0] == "~" ? "#A0640A" : (ln[0] == "-" ? "#C62828" : "#3E4C59"));
                string strike = ln[0] == "-" ? " text-decoration=\"line-through\"" : "";
                sb.Append("<text x=\"" + N(r.X + pad + fText / 6) + "\" y=\"" + N(y + fText * 0.95) + "\" font-family=\"" + Mono + "\" font-size=\"" + N(fText) + "\" fill=\"" + tc + "\"" + strike + ">" + X((ln[0] == "" ? "  " : ln[0] + " ") + ln[1]) + "</text>\n");
                y += lineH;
            }
        }
        sb.Append("</svg>\n");
        File.WriteAllText(path, sb.ToString(), new UTF8Encoding(false));
    }
    // Does the line between two cells' centres pass through another cell (its middle 80 %)?
    static bool Crosses(double ax, double ay, double bx, double by, double cx, double cy) {
        double x0 = cx - 0.4, x1 = cx + 0.4, y0 = cy - 0.4, y1 = cy + 0.4, t0 = 0, t1 = 1, dx = bx - ax, dy = by - ay;
        double[] p = { -dx, dx, -dy, dy }, q = { ax - x0, x1 - ax, ay - y0, y1 - ay };
        for (int i = 0; i < 4; i++) {
            if (p[i] == 0) { if (q[i] < 0) return false; continue; }
            double t = q[i] / p[i];
            if (p[i] < 0) { if (t > t1) return false; if (t > t0) t0 = t; } else { if (t < t0) return false; if (t < t1) t1 = t; }
        }
        return true;
    }
    // Where the line from the box's centre towards (px, py) leaves the box.
    static double[] BoxEdge(Box r, double px, double py) {
        double dx = px - r.CX, dy = py - r.CY;
        if (dx == 0 && dy == 0) return new double[] { r.CX, r.CY };
        double tx = dx == 0 ? double.MaxValue : (r.Width / 2) / Math.Abs(dx);
        double ty = dy == 0 ? double.MaxValue : (r.Height / 2) / Math.Abs(dy);
        double t = Math.Min(tx, ty);
        return new double[] { r.CX + dx * t, r.CY + dy * t };
    }
    // A cardinality next to a line's end, on white.
    static void Card(StringBuilder sb, string text, double[] at, double[] towards, double f, string color) {
        double dx = towards[0] - at[0], dy = towards[1] - at[1], len = Math.Sqrt(dx * dx + dy * dy);
        if (len < 1) return;
        double ux = dx / len, uy = dy / len;
        double w = BoldWidth(text, f), h = f * 1.33;
        double x = at[0] + ux * 12 - uy * 8 - w / 2, y = at[1] + uy * 12 + ux * 8 - h / 2;
        sb.Append("<rect x=\"" + N(x) + "\" y=\"" + N(y) + "\" width=\"" + N(w) + "\" height=\"" + N(h) + "\" fill=\"#FFFFFF\"/>\n");
        sb.Append("<text x=\"" + N(x + f / 6) + "\" y=\"" + N(y + f * 1.08) + "\" font-family=\"" + Sans + "\" font-size=\"" + N(f) + "\" font-weight=\"bold\" fill=\"" + color + "\">" + X(text) + "</text>\n");
    }
}
'@
    $script:modelTool = $true
}

# models.md -> the diagram's lines (M / F / R) for LazySpecModelDiagram; none when it has no models.
function Get-ModelDiagramData([string]$Text) {
    $out = New-Object Collections.Generic.List[string]
    $section = ''
    $model = $null
    $names = @{}
    $fieldTypes = New-Object Collections.ArrayList
    $relations = @{}
    $lines = $Text.Replace("`r", '').Split("`n")
    # The models and lists first (their names: a field of that type is a relation).
    foreach ($l in $lines) { if ($l -match '^###\s+`([A-Za-z_][\w.]*)`\s*$') { $names[$Matches[1]] = $true } }
    $tableRows = 0; $hasMark = $false; $shown = 0
    # What a box doesn't show: a changed model's unchanged fields ("... 9 unchanged"), the rest past 10 ("... 26 more").
    $hide = @{ Same = 0; More = 0 }
    $flushHidden = {
        if ($model -and $hide.Same) { $out.Add("F||$([char]0x2026) $($hide.Same) $(Get-ExportText 'unchanged' 'unchanged')") }
        if ($model -and $hide.More) { $out.Add("F||$([char]0x2026) $((Get-ExportText 'moreFields' '{n} more').Replace('{n}', [string]$hide.More))") }
        $hide.Same = 0; $hide.More = 0
    }
    $statusOf = @{}
    foreach ($l in $lines) {
        if ($l -match '^##\s+(.*)$' -and $l -notmatch '^###') {
            & $flushHidden
            $model = $null
            $h = $Matches[1].ToLower()
            $kind = 'model'; if ($h -match 'lookup') { $kind = 'lookup' }
            $status = ''
            if ($h -match '^(nov|new|neu)') { $status = 'new' } elseif ($h -match '^(izmijenjen|modified|changed|ge.ndert)') { $status = 'modified' }
            $section = if ($status) { "$kind|$status" } else { '' }
            continue
        }
        if ($l -match '^###\s+`([A-Za-z_][\w.]*)`\s*$') {
            & $flushHidden
            $model = $null
            if (-not $section) { continue }
            $model = $Matches[1]
            $statusOf[$model] = $section
            $out.Add("M|$model|$section")
            $tableRows = 0; $hasMark = $false; $shown = 0
            continue
        }
        if (-not $model) { continue }
        # A table row: the field (or value) and its type; changed models: only the changed rows.
        if ($l -match '^\s*\|') {
            $cells = @(Split-TableRow $l)
            $tableRows++
            if ($tableRows -eq 1) { $hasMark = ($cells[0] -replace '[*`]', '') -match '^(?i)(change|promjena|.nderung)$'; continue }
            if ($cells[0] -match '^:?-{2,}') { continue }
            $mark = ''
            if ($hasMark) { $mark = ($cells[0] -replace '[*`]', '').Trim(); if ($mark -eq [string][char]0x2212) { $mark = '-' }; $cells = @($cells | Select-Object -Skip 1) }
            $name = ($cells[0] -replace '[`*]', '').Trim()
            if (-not $name) { continue }
            $type = ''
            $isLookup = $section -like 'lookup*'
            if (-not $isLookup -and $cells.Count -gt 1) { $type = ($cells[1] -replace '[`*]', '').Trim() }
            # A field whose type is a model or list of the document: a relation (unless a Veze line names it).
            $bare = ($type -replace '[?\[\]]|<.*>', '').Trim()
            if ($bare -and $names.ContainsKey($bare) -and $bare -ne $model) { [void]$fieldTypes.Add(@($model, $bare, $mark)) }
            $isChanged = $section -like '*|modified'
            if ($isChanged -and -not $mark) { $hide.Same++; continue }
            if ($shown -ge 10) { $hide.More++; continue }
            $text = $name
            if ($type) { $text += ": $type" }
            $out.Add("F|$mark|$($text.Replace('|', '/'))")
            $shown++
            continue
        }
        # The relations line: `A` N:1 `B` (`BId`); + `C` 1:N `A` ...
        if ($l -match '^\s*\*\*(Veze|Relations|Beziehungen)(:\*\*|\*\*:)\s*(.*)$') {
            foreach ($item in ($Matches[3] -split ';')) {
                $m = [regex]::Match($item.Trim(), '^([+~\u2212-])?\s*`([^`]+)`\s+(1|N|0\.\.1|\*)\s*:\s*(1|N|0\.\.1|\*)\s+`([^`]+)`')
                if (-not $m.Success) { continue }
                $mk = $m.Groups[1].Value; if ($mk -eq [string][char]0x2212) { $mk = '-' }
                $key = (@($m.Groups[2].Value, $m.Groups[5].Value) | Sort-Object) -join '|'
                # Simple: a relation that changes, any of a new model, or one between models of this document;
                # a changed model's unchanged relations to other models stay in its table, not in the picture.
                $a = $m.Groups[2].Value; $b = $m.Groups[5].Value
                $keep = $mk -or ($statusOf[$a] -like '*|new') -or ($statusOf[$b] -like '*|new') -or ($names.ContainsKey($a) -and $names.ContainsKey($b))
                if ($keep -and -not $relations.ContainsKey($key)) { $relations[$key] = "R|$a|$b|$($m.Groups[3].Value):$($m.Groups[4].Value)|$mk" }
            }
        }
    }
    & $flushHidden
    foreach ($ft in $fieldTypes) {
        $key = (@($ft[0], $ft[1]) | Sort-Object) -join '|'
        if (-not $relations.ContainsKey($key)) { $relations[$key] = "R|$($ft[0])|$($ft[1])|N:1|$($ft[2])" }
    }
    foreach ($r in $relations.Values) { $out.Add($r) }
    if (-not @($out | Where-Object { $_.StartsWith('M|') }).Count) { return @() }
    return , $out.ToArray()
}
# The diagram of a models.md as an SVG file (for the export); '' when there is nothing to draw.
$script:exportTempFiles = New-Object Collections.ArrayList
function New-ModelDiagram([string]$Text) {
    $data = Get-ModelDiagramData $Text
    if (-not @($data).Count) { return '' }
    try {
        Initialize-ModelDiagramTool
        $f = Join-Path ([IO.Path]::GetTempPath()) ('lazyspec-models-' + [guid]::NewGuid().ToString('N') + '.svg')
        [LazySpecModelDiagram]::Draw($f, [string[]]$data)
        if (-not (Test-Path -LiteralPath $f)) { return '' }
        [void]$script:exportTempFiles.Add($f)
        return $f
    } catch { Write-Host "  ! the models' diagram not drawn: $($_.Exception.Message)"; return '' }
}

# A Markdown file as a document (-Markdown): its front matter (title, subtitle, client, author, date, language,
# toc, cover), its title (the front matter's, else its first "# " heading, else the file's name), its text.
function Read-MarkdownDocument([string]$Path) {
    $text = Read-Text $Path
    $fm = [ordered]@{}
    $m = [regex]::Match($text, '(?s)\A\uFEFF?---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\z)')
    if ($m.Success) {
        try { $fm = ConvertFrom-ThemeYaml $m.Groups[1].Value "$Path (front matter)" } catch { throw "The Markdown file's front matter can't be read: $($_.Exception.Message)" }
        if ($fm -isnot [Collections.IDictionary]) { $fm = [ordered]@{} }
        $text = $text.Substring($m.Length)
    }
    $value = { param([string]$K) if ($fm.Contains($K)) { return [string]$fm[$K] } return '' }
    $flag = { param([string]$K, [bool]$Default) $v = & $value $K; if (-not $v) { return $Default }; return $v -match '^(?i)(true|yes|on|1)$' }
    $title = & $value 'title'
    # The first "# " heading: the title (when the front matter has none, or it is the same).
    $h1 = [regex]::Match($text, '\A\s*#[ \t]+(.+?)[ \t]*#*[ \t]*(?:\r?\n|\z)')
    if ($h1.Success -and (-not $title -or $h1.Groups[1].Value.Trim() -eq $title)) {
        if (-not $title) { $title = $h1.Groups[1].Value.Trim() }
        $text = $text.Substring($h1.Length)
    }
    if (-not $title) { $title = [IO.Path]::GetFileNameWithoutExtension($Path) }
    return [pscustomobject]@{
        Path = $Path; Title = $title; Subtitle = (& $value 'subtitle'); Client = (& $value 'client'); Author = (& $value 'author')
        Date = (& $value 'date'); Language = (& $value 'language'); Toc = (& $flag 'toc' $false); Cover = (& $flag 'cover' $true); Text = $text
    }
}

# The whole document as HTML. Word: a [[TOC]] mark where Word puts its own table of contents.
# $Doc: a Markdown document (-Markdown) instead of the specification.
# An entry of the contents. PDF: the title, dots and its page (0 until Export-Pdf knows it).
function Get-TocEntryHtml([string]$Id, [string]$TitleHtml, [string]$Class, [string]$Format) {
    $cls = ''
    if ($Class) { $cls = " class=`"$Class`"" }
    if ($Format -ne 'Pdf') { return "<p$cls><a href=`"#$Id`">$TitleHtml</a></p>`n" }
    return "<p$cls><a class=`"paged`" href=`"#$Id`"><span class=`"t`">$TitleHtml</span><span class=`"dots`"></span><span class=`"pg`" data-page-for=`"$Id`">0</span></a></p>`n"
}
function Get-ExportHtml([string]$Format, [bool]$WithChanges, [string]$ItemName, [bool]$Friendly, $Doc, [string]$ItemTitle) {
    $specs = @()
    if (-not $Doc) { $specs = @(Load-Specs) }
    $changes = @()
    if ($WithChanges) { $changes = @(Load-Changes | Where-Object { -not $_.Archived } | Sort-Object Name) }
    $one = $null
    $names = @(([string]$ItemName).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($names.Count -gt 1) {
        # Several changes (-Item a,b,c): one whole for the client, their documents together.
        $one = Get-ChangeBundle (Get-ChangeGroup $names) $ItemTitle
    }
    elseif ($names.Count) {
        $ItemName = $names[0]
        $one = @($specs | Where-Object { $_.Name -eq $ItemName }) + @(Load-Changes | Where-Object { $_.Name -eq $ItemName }) | Select-Object -First 1
        # A saved whole (lazyspec: bundles:): its changes, its title.
        $saved = @(Get-Bundles | Where-Object { $_.Id -eq $ItemName })
        if (-not $one -and $saved.Count) {
            if (-not $ItemTitle) { $ItemTitle = $saved[0].Title }
            $one = Get-ChangeBundle (Get-ChangeGroup $saved[0].Changes) $ItemTitle $saved[0].Id
        }
        if (-not $one) { throw "No spec, change or saved whole (lazyspec: bundles:) named '$ItemName' in openspec/." }
    }
    Load-ExportTexts
    $script:exportTranslate = $false
    $script:exportLang = Get-ExportLanguage $one
    if ($Doc -and $Doc.Language) { $script:exportLang = ($Doc.Language.ToLower() -split '[-_]')[0] }
    # -Language: the export in that language; the documents' own language is translated into it (DeepL).
    if ($Language) {
        $want = ($Language.ToLower() -split '[-_]')[0]
        if ($want -ne $script:exportLang) { $from = $script:exportLang; $script:exportLang = $want; Start-ExportTranslation $from }
    }
    $script:exportFriendly = $Friendly
    $script:exportFormat = $Format
    $title = Get-ExportSetting 'title' $projectName
    $subtitle = Get-ExportSetting 'subtitle' (Get-ExportText 'specification')
    $client = Get-ExportSetting 'client' ''
    $author = Get-ExportSetting 'author' 'Netmedia'
    $date = Get-Date -Format (Get-ExportText 'dateFormat' 'yyyy-MM-dd')
    $docBody = ''
    if ($Doc) {
        $title = $Doc.Title; $subtitle = $Doc.Subtitle
        if ($Doc.Client) { $client = $Doc.Client }
        if ($Doc.Author) { $author = $Doc.Author }
        if ($Doc.Date) { $date = $Doc.Date }
        $script:mdBaseDir = Split-Path $Doc.Path -Parent
        $docBody = ConvertTo-HtmlBody $Doc.Text
    }
    $reqs = 0
    $chapters = @()
    $scope = ''
    # One spec, or one change with every document of its workflow, in its order.
    if ($one) {
        $specs = @(); $changes = @()
        $subtitle = Get-ItemTitle $one
        if ($ItemTitle) { $subtitle = $ItemTitle }
        if ($one.Type -eq 'spec') {
            $specs = @($one)
            $subtitle = "$(Get-ExportText 'specification'): $subtitle"
        }
        else {
            # A change, or several as one (a chapter per kind of document, each change's part under its title).
            $members = @($one)
            if ($one.Type -eq 'bundle') { $members = @($one.Members) }
            $many = $members.Count -gt 1
            # A link to one of its documents ("open-questions.md") goes to that document's chapter.
            $script:docAnchors = @{}
            foreach ($m in $members) { foreach ($d in $m.Docs) { foreach ($f in $d.Files) { $script:docAnchors[(Split-Path $f -Leaf)] = "doc-$($d.Id)" } } }
            $n = 0
            foreach ($d in $one.Docs) {
                $sb = New-Object Text.StringBuilder
                if ($d.IsSpecs) {
                    if (-not $one.Caps.Count) { continue }
                    # The whole change's diagram first (several: each change's, all of them before the capabilities,
                    # not between another change's), a visual introduction; then its capabilities.
                    foreach ($m in $members) { [void]$sb.Append((Get-DiagramHtml (Get-Diagram 'change' $m.Name $m.Dir) (Get-ItemTitle $m))) }
                    [void]$sb.Append((Get-CapabilitiesHtml $members))
                }
                else {
                    $parts = @(foreach ($m in $members) { foreach ($md in @($m.Docs | Where-Object { $_.Id -eq $d.Id -and $_.Files.Count } | Select-Object -First 1)) { [pscustomobject]@{ Change = $m; Doc = $md } } })
                    if (-not $parts.Count) { continue }
                    foreach ($pt in $parts) {
                        $shift = 0
                        if ($many) { [void]$sb.Append("<h2>$(Html (Get-ItemTitle $pt.Change))</h2>`n"); $shift = 1 }
                        $files = @($pt.Doc.Files)
                        foreach ($f in $files) {
                            if ($files.Count -gt 1) { [void]$sb.Append("<h$(2 + $shift)>$(Html (Split-Path $f -Leaf))</h$(2 + $shift)>`n"); [void]$sb.Append((ConvertTo-HtmlBody (Remove-DocTitle (Read-Text $f)) (1 + $shift))) }
                            else {
                                $docText = Read-Text $f
                                $docHtml = ConvertTo-HtmlBody (Remove-DocTitle $docText) $shift
                                # models.md: the models' diagram, after the overview (else at the top).
                                if ((Split-Path $f -Leaf) -ieq 'models.md') {
                                    $pic = New-ModelDiagram $docText
                                    $density = 1
                                    # Word: a PNG of it (2x; old Word, LibreOffice and pandoc may show no SVG).
                                    if ($pic -and $script:exportFormat -eq 'Word') {
                                        $png = [IO.Path]::ChangeExtension($pic, '.png')
                                        try { ConvertTo-PngFromSvg $pic $png; [void]$script:exportTempFiles.Add($png); $pic = $png; $density = 2 }
                                        catch { Write-Host "  ! the models' diagram left out: $($_.Exception.Message)"; $pic = '' }
                                    }
                                    if ($pic) {
                                        $dia = Get-DiagramHtml $pic (Get-ExportText 'models') $density
                                        $at = $docHtml.IndexOf('</table>')
                                        if ($at -ge 0) { $docHtml = $docHtml.Insert($at + 8, "`n$dia") } else { $docHtml = $dia + $docHtml }
                                    }
                                }
                                [void]$sb.Append($docHtml)
                            }
                        }
                    }
                }
                $n++
                # The chapter's title: export-texts.json's for the workflow's usual documents, else the document's own "# Title".
                $dt = Get-ExportText $d.Id "`0"
                if ($dt -eq "`0") {
                    $dt = $d.Title
                    # Several changes: the first one's.
                    $own = @($d.Files)
                    if ($many -and $parts.Count) { $own = @($parts[0].Doc.Files) }
                    if ($own.Count -eq 1) {
                        $h1 = [regex]::Match((Read-Text $own[0]), '(?m)^#\s+(.+?)\s*$')
                        if ($h1.Success) { $dt = Get-TranslatedText $h1.Groups[1].Value }
                    }
                }
                if ($d.IsSpecs) { $dt = Get-ExportText 'specs' }
                $chapters += [pscustomobject]@{ Id = "doc-$($d.Id)"; Title = "$(Get-ChapterNumber $n)$dt"; Part = 'specs'; Body = $sb.ToString() }
            }
            foreach ($cap in $one.Caps) { $reqs += $cap.Added + $cap.Modified }
            $scope = "$(Get-CountText $chapters.Count 'nDocuments'), $(Get-CountText $one.Caps.Count 'nCapabilities'), $(Get-CountText $one.Total 'nTasks')"
            if ($many) { $scope = "$(Get-CountText $members.Count 'nChanges'), $scope" }
        }
    }
    foreach ($s in $specs) { $reqs += $s.Reqs }

    $n = 0
    foreach ($s in $specs) {
        $n++
        $name = $s.Title
        if (-not $name) { $name = Get-ArtifactTitle $s.Short }
        $name = Get-FriendlyTitle $s.Name $name
        # A spec's diagram ("diagrams:" straight under it, by the spec's name; saved in openspec\diagrams\).
        $body = (Get-DiagramHtml (Get-Diagram $s.Name '' $osDir) $name) + (ConvertTo-HtmlBody (Remove-DocTitle $s.Text))
        $chapters += [pscustomobject]@{ Id = "spec-$($s.Name)"; Title = "$(Get-ChapterNumber $n)$name"; Part = 'specs'; Body = $body }
    }
    foreach ($c in $changes) {
        $sb = New-Object Text.StringBuilder
        [void]$sb.Append((Get-DiagramHtml (Get-Diagram 'change' $c.Name $c.Dir) (Get-ItemTitle $c)))
        $proposal = Join-Path $c.Dir 'proposal.md'
        if (Test-Path -LiteralPath $proposal) { [void]$sb.Append((ConvertTo-HtmlBody (Remove-DocTitle (Read-Text $proposal)))) }
        [void]$sb.Append((Get-CapabilitiesHtml @($c)))
        $chapters += [pscustomobject]@{ Id = "change-$($c.Name)"; Title = (Get-ItemTitle $c); Part = 'changes'; Body = $sb.ToString() }
    }

    # The page's footer (title, page / pages): Edge and Chrome. Word drops a stylesheet with these; it numbers the pages itself.
    $pageCss = ''
    $meta = [pscustomobject]@{ title = $title; subtitle = $subtitle; client = $client; date = $date; author = $author }
    $themeCss = ''
    $coverLogo = ''
    if ($script:docTheme) {
        # The theme: its page (PDF), fonts and styles over LazySpec's; its cover logo.
        $themeCss = Get-ThemeCss $script:docTheme $meta ($Format -eq 'Pdf')
        $cl = $script:docTheme.Cover
        if ($cl.Logo) {
            $src = Get-FileUri $cl.Logo
            if ($Format -ne 'Word') { $src = "data:image/$([IO.Path]::GetExtension($cl.Logo).TrimStart('.').ToLower().Replace('jpg', 'jpeg'));base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes($cl.Logo)) }
            $coverLogo = "<div class=`"cover-logo`"><img src=`"$src`" style=`"height: $(Format-Num $cl.LogoHeight)mm`" data-height-mm=`"$(Format-Num $cl.LogoHeight)`" alt=`"`"></div>`n"
        }
    }
    elseif ($Format -ne 'Word') {
        $pageCss = @"
@page { size: A4; margin: 20mm 18mm 22mm 18mm;
  @bottom-left { content: "$(("$title - $subtitle") -replace '["\\<>]', '')"; font: 8pt 'Segoe UI', Arial, sans-serif; color: #8a96a3; }
  @bottom-right { content: counter(page) " / " counter(pages); font: 8pt 'Segoe UI', Arial, sans-serif; color: #8a96a3; } }
@page :first { @bottom-left { content: none; } @bottom-right { content: none; } }

"@
    }
    $subtitleHtml = ''
    if ($subtitle) { $subtitleHtml = "<p class=`"subtitle`">$(Html $subtitle)</p>" }
    # A Markdown document: its headings don't start pages; without a cover, the title at the top of the first page.
    $docCss = ''
    if ($Doc) {
        $docCss = "h1, h1.part { page-break-before: auto; }`n.page-break { page-break-before: always; margin: 0; height: 0; }`n.toc .l2 { margin-left: 14pt; font-size: 10pt; }`n"
        if (-not $Doc.Cover) { $docCss += ".cover .bar { margin: 0 0 10pt; }`n.cover .subtitle { margin-bottom: 8pt; }`n.cover { margin-bottom: 18pt; }`n.toc-title { page-break-before: auto; }`n" }
    }
    $h = New-Object Text.StringBuilder
    [void]$h.Append(@"
<!DOCTYPE html>
<html lang="$($script:exportLang)"><head><meta charset="utf-8">
<title>$(Html "$title - $subtitle")</title>
<style>
$pageCssbody { font-family: 'Segoe UI', Calibri, Arial, sans-serif; font-size: 10.5pt; line-height: 1.45; color: #1f2933; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
p, li, td, th, div, h1, h2, h3, h4, h5, h6 { font-family: 'Segoe UI', Calibri, Arial, sans-serif; }
a { color: #1d6fa5; text-decoration: none; }
h1 { page-break-before: always; font-size: 22pt; font-weight: 600; color: #0b3c5d; border-bottom: 2pt solid #f07b4f; padding-bottom: 4pt; margin: 0 0 14pt; }
h1.part { font-size: 28pt; border: none; margin-top: 90mm; text-align: center; }
h2 { font-size: 15pt; font-weight: 600; color: #0b3c5d; margin: 18pt 0 6pt; }
h3 { font-size: 12pt; font-weight: 600; color: #1f2933; margin: 14pt 0 4pt; }
h4, h5, h6 { font-size: 10.5pt; font-weight: 600; margin: 10pt 0 3pt; }
/* The levels, largest first: the capability, a section (Purpose, ADDED Requirements ...), a requirement, a scenario, its text. */
h2.cap { font-size: 18pt; color: #0b3c5d; margin: 30pt 0 10pt; padding-bottom: 4pt; border-bottom: 1.5pt solid #4a90c2; }
.sec { font-size: 14pt; font-weight: 600; color: #0b3c5d; margin: 26pt 0 10pt; padding-bottom: 3pt; border-bottom: 1px solid #c9d3dc; }
.sub { font-size: 12pt; font-weight: 600; color: #1f2933; margin: 16pt 0 5pt; }
h2, h3, h4, h5, h6 { page-break-after: avoid; break-after: avoid; page-break-inside: avoid; break-inside: avoid; }
.req { font-size: 12.5pt; font-weight: 600; color: #1f2933; border-left: 3pt solid #4a90c2; padding-left: 7pt; margin: 24pt 0 6pt; }
.scn { font-size: 11pt; font-weight: 600; color: #5b3f9e; margin: 14pt 0 3pt 10pt; }
.scenario { font-size: 9.5pt; color: #3e4c59; margin: 0 0 6pt 10pt; padding: 1pt 0 1pt 8pt; border-left: 1.5pt solid #d9cdee; }
.scenario p, .scenario li { font-size: 9.5pt; }
.tag { display: block; font-size: 7.5pt; font-weight: 600; letter-spacing: 0.6pt; text-transform: uppercase; color: #8a96a3; }
li.step { list-style: none; margin-left: -12pt; }
li.task-done { color: #52606d; }
li.task-done .done { color: #2e8b57; font-weight: 600; }
p.steps { margin: 3pt 0 8pt; }
.diagram { margin: 16pt 0 20pt; text-align: center; page-break-inside: avoid; break-inside: avoid; }
.diagram img { max-width: 100%; max-height: 195mm; height: auto; }
.diagram .caption { font-size: 8.5pt; color: #8a96a3; margin: 3pt 0 0; }
ul.toc-list { margin: 4pt 0 14pt; padding-left: 16pt; }
ul.toc-list li { font-size: 10pt; margin: 1.5pt 0; }
p.toc-scn { font-size: 9pt; color: #52606d; margin: 2pt 0 8pt; }
p.toc-scn .lbl { font-weight: 600; }
table { border-collapse: collapse; width: 100%; margin: 6pt 0 12pt; font-size: 9pt; }
th, td { border: 1px solid #c9d3dc; padding: 3pt 6pt; margin: 0; text-align: left; vertical-align: top; }
th { background: #eaf1f7; font-weight: 600; }
tr { page-break-inside: avoid; }
/* Nothing wider than the page (Chrome would shrink the whole document to fit it): long words, identifiers and
   links break where they must. */
body, p, li { overflow-wrap: anywhere; }
li code, p code { overflow-wrap: anywhere; word-break: break-word; }
/* A table with its columns' widths (table.sized, Get-TableWidths): exactly those, never wider than the page
   (Chrome would shrink the whole document to fit a wider one); a word breaks only when it can't fit its
   column ("anywhere" would let a column shrink to a letter). */
table.sized { table-layout: fixed; }
td, th, td code, th code { overflow-wrap: break-word; word-break: normal; }
img { max-width: 100%; }
tr.chg-add td:first-child, tr.chg-mod td:first-child, tr.chg-del td:first-child { font-weight: 700; text-align: center; }
tr.chg-del td { color: #8A3B32; }
code { font-family: Consolas, 'Courier New', monospace; font-size: 9pt; background: #f1f3f5; padding: 0 2pt; }
pre { font-family: Consolas, 'Courier New', monospace; font-size: 8.5pt; background: #f6f8fa; border: 1px solid #e1e4e8; padding: 6pt; white-space: pre; overflow: hidden; }
pre code { background: none; padding: 0; }
h1 code { font-size: 22pt; } h2 code { font-size: 15pt; } h3 code { font-size: 12pt; } h4 code, h5 code, h6 code { font-size: 10.5pt; }
h1 code, h2 code, h3 code, h4 code, h5 code, h6 code { font-size: inherit; background: none; padding: 0; }
pre.wrap, pre.wrap code { font-size: 9pt; white-space: pre-wrap; overflow-wrap: anywhere; word-wrap: break-word; }
/* Numbered questions at the margin, their answers lettered (a, b, c), a proposal at the answers' level; a plain
   numbered list (a scenario's steps) as tight as any list. */
ol.top { margin-left: 0; padding-left: 1.8em; }
ol.top > li { margin: 2pt 0; }
ol.top > li:has(> ol, > ul, > p) { margin: 10pt 0 22pt; }
ol.options { margin: 4pt 0; padding-left: 1.8em; }
ol.options > li { margin: 2pt 0; }
li > p { margin: 6pt 0; }
.scenario li > p { margin: 0; }
/* PDF: the contents as Word's: the title, dots, its page number. */
.toc a.paged { display: flex; align-items: baseline; }
.toc a.paged .dots { flex: 1; border-bottom: 1px dotted currentColor; margin: 0 3pt; min-width: 12pt; }
.toc a.paged .pg { min-width: 14pt; text-align: right; }
p.proposal { margin: 6pt 0 16pt; }
p.labelled { margin: 10pt 0 2pt; }
ul.labelled { margin: 0 0 10pt; }
p.proposal > strong:first-child { text-decoration: underline; }
blockquote { border-left: 3pt solid #c9d3dc; margin: 6pt 0; padding: 0 0 0 9pt; color: #52606d; }
hr { border: none; border-top: 1px solid #c9d3dc; margin: 12pt 0; }
.cover { text-align: left; }
.cover .bar { width: 40mm; border-top: 4pt solid #f07b4f; margin: 150pt 0 14pt; }
.cover .title { font-size: 34pt; font-weight: 600; color: #0b3c5d; margin: 0; line-height: 1.15; }
.cover .subtitle { font-size: 18pt; color: #4a90c2; margin: 6pt 0 40pt; }
.cover .meta { font-size: 10.5pt; color: #52606d; margin: 2pt 0; }
.toc-title { page-break-before: always; font-size: 22pt; font-weight: 600; color: #0b3c5d; border-bottom: 2pt solid #f07b4f; padding-bottom: 4pt; margin: 0 0 14pt; }
.toc p { margin: 3pt 0; font-size: 11pt; }
.toc .part { margin-top: 12pt; font-weight: 600; color: #52606d; }
$docCss$themeCss</style></head><body>
<div class="cover">
$coverLogo<div class="bar"></div>
<p class="title">$(Html $title)</p>
$subtitleHtml

"@)
    if ($client) { [void]$h.Append("<p class=`"meta`">$(Html (Get-ExportText 'client')): <strong>$(Html $client)</strong></p>`n") }
    [void]$h.Append("<p class=`"meta`">$(Html (Get-ExportText 'date')): $date</p>`n")
    if ($author) { [void]$h.Append("<p class=`"meta`">$(Html (Get-ExportText 'preparedBy')): $(Html $author)</p>`n") }
    if ($Doc) {
        # A document: its contents (toc: true; headings 1-2), then its text on a page of its own after a cover.
        [void]$h.Append("</div>`n")
        if ($Doc.Toc) {
            [void]$h.Append("<p class=`"toc-title`">$(Html (Get-ExportText 'contents'))</p>`n")
            if ($Format -eq 'Word') { [void]$h.Append("<p>[[TOC]]</p>`n") }
            else {
                [void]$h.Append("<div class=`"toc`">`n")
                foreach ($hm in [regex]::Matches($docBody, '(?s)<h([12])\b[^>]*\bid="([^"]+)"[^>]*>(.*?)</h\1>')) {
                    [void]$h.Append((Get-TocEntryHtml $hm.Groups[2].Value ([regex]::Replace($hm.Groups[3].Value, '<[^>]+>', '')) "l$($hm.Groups[1].Value)" $Format))
                }
                [void]$h.Append("</div>`n")
            }
        }
        if ($Doc.Cover -or $Doc.Toc) { [void]$h.Append("<p class=`"page-break`"></p>`n") }
        [void]$h.Append($docBody)
        [void]$h.Append("</body></html>`n")
        return [pscustomobject]@{ Html = $h.ToString(); Specs = 0; Changes = 0; Reqs = 0; Item = $null; Chapters = 0; Scope = ''; Meta = $meta; Doc = $Doc }
    }
    if (-not $scope) {
        $scope = "$(Get-CountText $specs.Count 'nChapters'), $(Get-CountText $reqs 'nRequirements')"
        if ($changes.Count) { $scope += ", $(Get-CountText $changes.Count 'nChanges')" }
    }
    [void]$h.Append("<p class=`"meta`">$(Html (Get-ExportText 'scope')): $(Html $scope)</p>`n</div>`n")

    [void]$h.Append("<p class=`"toc-title`">$(Html (Get-ExportText 'contents'))</p>`n")
    if ($Format -eq 'Word') { [void]$h.Append("<p>[[TOC]]</p>`n") }
    else {
        [void]$h.Append("<div class=`"toc`">`n")
        $part = 'specs'
        foreach ($ch in $chapters) {
            if ($ch.Part -ne $part) { $part = $ch.Part; [void]$h.Append("<p class=`"part`">$(Html (Get-ExportText 'plannedChanges'))</p>`n") }
            [void]$h.Append((Get-TocEntryHtml $ch.Id (Html $ch.Title) '' $Format))
        }
        [void]$h.Append("</div>`n")
    }
    $part = 'specs'
    foreach ($ch in $chapters) {
        if ($ch.Part -ne $part) { $part = $ch.Part; [void]$h.Append("<h1 class=`"part`">$(Html (Get-ExportText 'plannedChanges'))</h1>`n") }
        [void]$h.Append("<h1 id=`"$($ch.Id)`">$(Html $ch.Title)</h1>`n")
        [void]$h.Append($ch.Body)
    }
    [void]$h.Append("</body></html>`n")
    return [pscustomobject]@{ Html = $h.ToString(); Specs = $specs.Count; Changes = $changes.Count; Reqs = $reqs; Item = $one; Chapters = $chapters.Count; Scope = $scope; Meta = $meta }
}

# A file's path as a file:// URI ([Uri] alone takes a Unix path for a relative one).
function Get-FileUri([string]$Path) { return (New-Object Uri $Path, ([UriKind]::Absolute)).AbsoluteUri }
# Edge or Chrome: Windows' install folders, macOS's applications (Chromium too).
function Find-Browser {
    $candidates = @()
    foreach ($d in ${env:ProgramFiles(x86)}, $env:ProgramFiles) { if ($d) { $candidates += (Join-Path $d 'Microsoft\Edge\Application\msedge.exe') } }
    foreach ($d in $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) { if ($d) { $candidates += (Join-Path $d 'Google\Chrome\Application\chrome.exe') } }
    foreach ($d in '/Applications', "$HOME/Applications") {
        foreach ($app in 'Microsoft Edge', 'Google Chrome', 'Chromium') { $candidates += "$d/$app.app/Contents/MacOS/$app" }
    }
    foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    return $null
}
# The browser, headless: its window hidden on Windows (-WindowStyle is Windows only); elsewhere its messages
# into files in its profile's folder, not over the terminal.
function Start-Browser([string]$Browser, [string]$ArgLine, [string]$ProfileDir) {
    if ($env:OS -eq 'Windows_NT') { return (Start-Process -FilePath $Browser -ArgumentList $ArgLine -WindowStyle Hidden -PassThru) }
    [void](New-Item -ItemType Directory -Force -Path $ProfileDir)
    return (Start-Process -FilePath $Browser -ArgumentList $ArgLine -PassThru -RedirectStandardOutput (Join-Path $ProfileDir 'out.log') -RedirectStandardError (Join-Path $ProfileDir 'err.log'))
}
# SVG -> PNG at 2x: the browser's screenshot of it, its window the SVG's size, with its own empty profile.
function ConvertTo-PngFromSvg([string]$Svg, [string]$Png) {
    $browser = Find-Browser
    if (-not $browser) { throw 'a PNG of it needs Microsoft Edge or Google Chrome (neither was found)' }
    Initialize-ImageTool
    $size = [LazySpecImage]::Size($Svg)
    $profileDir = Join-Path ([IO.Path]::GetTempPath()) ('lazyspec-browser-' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $Png) { Remove-Item -LiteralPath $Png -Force }
    $argLine = "--headless=new --disable-gpu --no-first-run --no-default-browser-check --disable-extensions --hide-scrollbars --user-data-dir=`"$profileDir`" " +
        "--force-device-scale-factor=2 --window-size=$($size[0]),$($size[1]) --screenshot=`"$Png`" `"$(Get-FileUri $Svg)`""
    $p = Start-Browser $browser $argLine $profileDir
    try {
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while (-not $p.HasExited -and $watch.Elapsed.TotalSeconds -lt 60) { Start-Sleep -Milliseconds 200 }
        Stop-ProcessTree $p
        if (-not (Wait-File $Png 2)) { throw "$(Split-Path $browser -Leaf) wrote no PNG" }
    }
    finally { Remove-Item -LiteralPath $profileDir -Recurse -Force -ErrorAction SilentlyContinue }
}
function Wait-File([string]$Path, [int]$Seconds) {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.Elapsed.TotalSeconds -lt $Seconds) {
        if ((Test-Path -LiteralPath $Path) -and (Get-Item -LiteralPath $Path).Length -gt 0) { return $true }
        Start-Sleep -Milliseconds 200
    }
    return $false
}
# HTML -> PDF: Edge (or Chrome) prints it, headless, with its own empty profile.
# Ends a process and the ones it started. One that ended by itself meanwhile is fine: taskkill's "not found"
# (on stderr, an error under ErrorActionPreference Stop in Windows PowerShell) isn't a failure.
function Stop-ProcessTree($Proc) {
    if (-not $Proc) { return }
    try { if ($Proc.HasExited) { return } } catch { return }
    if ($env:OS -eq 'Windows_NT') { try { & taskkill.exe /T /F /PID $Proc.Id 2>&1 | Out-Null } catch { } }
    else { try { $Proc.Kill() } catch { } }
}
# The PDF's named destinations (a heading's id) and their pages (1 = the first). Edge and Chrome write the
# PDF's objects plainly (only the page contents and fonts are compressed): the catalog's /Dests and /Pages.
function Get-PdfDestPages([string]$Path) {
    $t = [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($Path))
    $obj = {
        param([string]$N)
        $at = [regex]::Match($t, "(?m)^$N 0 obj\b")
        if (-not $at.Success) { return '' }
        $end = $t.IndexOf('endobj', $at.Index)
        $st = $t.IndexOf('stream', $at.Index)
        if ($st -ge 0 -and $st -lt $end) { $end = $st }
        return $t.Substring($at.Index, $end - $at.Index)
    }
    $cat = [regex]::Match($t, '/Type\s*/Catalog\b[^>]*')
    $pages = [regex]::Match($cat.Value, '/Pages\s+(\d+)\s+0\s+R')
    $dests = [regex]::Match($cat.Value, '/Dests\s+(\d+)\s+0\s+R')
    $map = @{}
    if (-not $pages.Success -or -not $dests.Success) { return $map }
    # The pages in order: the page tree, depth first.
    $order = @{}
    $stack = New-Object Collections.Stack
    $stack.Push($pages.Groups[1].Value)
    $n = 0
    while ($stack.Count) {
        $id = $stack.Pop()
        $o = & $obj $id
        $kids = [regex]::Match($o, '/Kids\s*\[([^\]]*)\]')
        if ($o -match '/Type\s*/Pages\b' -and $kids.Success) {
            $refs = @([regex]::Matches($kids.Groups[1].Value, '(\d+)\s+0\s+R') | ForEach-Object { $_.Groups[1].Value })
            for ($i = $refs.Count - 1; $i -ge 0; $i--) { $stack.Push($refs[$i]) }
        }
        else { $n++; $order[$id] = $n }
    }
    foreach ($m in [regex]::Matches((& $obj $dests.Groups[1].Value), '/([^\s/\[\]<>()]+)\s*\[\s*(\d+)\s+0\s+R')) {
        if ($order.ContainsKey($m.Groups[2].Value)) { $map[$m.Groups[1].Value] = $order[$m.Groups[2].Value] }
    }
    return $map
}
function Export-Pdf([string]$HtmlPath, [string]$Target) {
    Invoke-PdfPrint $HtmlPath $Target
    # The contents' page numbers: where the first print put each chapter; then printed again with them
    # (a number on its entry's line: the pages stay as they were).
    $html = [IO.File]::ReadAllText($HtmlPath)
    if ($html -notmatch 'data-page-for="') { return }
    $pages = @{}
    try { $pages = Get-PdfDestPages $Target } catch { }
    if (-not $pages.Count) { Write-Host "  ! the contents without page numbers (the PDF's links weren't readable)"; return }
    $html = [regex]::Replace($html, '<span class="pg" data-page-for="([^"]+)">0</span>', {
            param($m)
            $p = $pages[$m.Groups[1].Value]
            if ($p) { return "<span class=`"pg`">$p</span>" }
            return '<span class="pg"></span>'
        })
    [IO.File]::WriteAllText($HtmlPath, $html, (New-Object Text.UTF8Encoding $false))
    Write-Host "  $($g.caret) the contents' page numbers: printing again"
    Remove-Item -LiteralPath $Target -Force
    Invoke-PdfPrint $HtmlPath $Target
}
function Invoke-PdfPrint([string]$HtmlPath, [string]$Target) {
    $browser = Find-Browser
    if (-not $browser) { throw 'PDF needs Microsoft Edge or Google Chrome (neither was found).' }
    Write-Host "  $($g.caret) printing with $(Split-Path $browser -Leaf)"
    $profileDir = Join-Path (Split-Path $HtmlPath -Parent) 'browser'
    $argLine = "--headless=new --disable-gpu --no-first-run --no-default-browser-check --disable-extensions --user-data-dir=`"$profileDir`" " +
        "--no-pdf-header-footer --print-to-pdf-no-header --print-to-pdf=`"$Target`" `"$(Get-FileUri $HtmlPath)`""
    $p = Start-Browser $browser $argLine $profileDir
    # Headless Edge sometimes stays running after it wrote the PDF: done when the file stops growing.
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $size = -1; $stable = 0
    while ($watch.Elapsed.TotalSeconds -lt 120) {
        Start-Sleep -Milliseconds 250
        $now = -1
        if (Test-Path -LiteralPath $Target) { try { $now = (Get-Item -LiteralPath $Target).Length } catch { } }
        if ($now -gt 0 -and $now -eq $size) { $stable++ } else { $stable = 0 }
        $size = $now
        if ($p.HasExited -and $now -gt 0) { break }
        if ($stable -ge 4) { break }
        if ($p.HasExited -and $watch.Elapsed.TotalSeconds -gt 5 -and $now -le 0) { break }
    }
    Stop-ProcessTree $p
    if (-not (Wait-File $Target 2)) { throw "$(Split-Path $browser -Leaf) wrote no PDF." }
}
# HTML -> Word: Word itself (its own table of contents, page numbers), else pandoc.
function Export-Word([string]$HtmlPath, [string]$Target) {
    $word = $null
    try { $word = New-Object -ComObject Word.Application } catch { }
    if ($word) {
        Write-Host "  $($g.caret) converting with Microsoft Word"
        $doc = $null
        try {
            $word.Visible = $false
            $word.DisplayAlerts = 0
            $doc = $word.Documents.Open($HtmlPath, $false, $true, $false)
            $doc.ActiveWindow.View.Type = 3                     # print layout, not web layout
            # The diagrams come in as links to the files: into the document with them.
            foreach ($shape in @($doc.InlineShapes)) { try { if ($shape.LinkFormat) { $shape.LinkFormat.SavePictureWithDocument = $true; $shape.LinkFormat.BreakLink() } } catch { } }
            $doc.PageSetup.PaperSize = 7                        # A4
            $doc.PageSetup.TopMargin = 56.7; $doc.PageSetup.BottomMargin = 62.4
            $doc.PageSetup.LeftMargin = 51; $doc.PageSetup.RightMargin = 51
            $range = $doc.Content
            if ($range.Find.Execute('[[TOC]]')) {
                $range.Text = ''
                [void]$doc.TablesOfContents.Add($range, $true, 1, $script:wordMode.TocLevels)
                $doc.TablesOfContents.Item(1).Update()
            }
            [void]$doc.Sections.Item(1).Footers.Item(1).PageNumbers.Add(2, $false)  # right, not on the cover
            $doc.SaveAs2($Target, 16)                          # .docx
        }
        finally {
            if ($doc) { try { $doc.Close($false) } catch { } }
            try { $word.Quit() } catch { }
            [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
        }
        return
    }
    $pandoc = Get-Command pandoc -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $pandoc) { throw 'Word needs Microsoft Word or pandoc (neither was found).' }
    Write-Host "  $($g.caret) converting with pandoc"
    $html = (Read-Text $HtmlPath).Replace('<p>[[TOC]]</p>', '')
    [IO.File]::WriteAllText($HtmlPath, $html, (New-Object Text.UTF8Encoding $false))
    & $pandoc.Source $HtmlPath -f html -t docx --toc "--toc-depth=$($script:wordMode.TocLevels)" -o $Target
    if ($LASTEXITCODE) { throw "pandoc ended with exit code $LASTEXITCODE." }
}

# --- the document theme ("lazyspec: documentTheme:" in config.yaml, or -Theme): one look, three formats -----
# A YAML file: the page, colours, the styles of the cover, headings, text, tables, links and code, the
# header and footer (a logo, texts, the page number), the cover's logo. Fonts: the .ttf / .otf files in
# fonts\ next to it (PDF and HTML use them without installing them; Word gets them embedded). Pictures:
# relative to the theme. HTML and PDF are styled with it; Word gets a base document made from it (unless a
# documentTemplate is set: Word documents then use that).

# A font file's names and style, from its name and OS/2 tables.
$script:fontTool = $false
function Initialize-FontTool {
    if ($script:fontTool) { return }
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
public static class LazySpecFont {
    static int U16(byte[] b, int o) { return (b[o] << 8) | b[o + 1]; }
    static long U32(byte[] b, int o) { return ((long)b[o] << 24) | ((long)b[o + 1] << 16) | ((long)b[o + 2] << 8) | b[o + 3]; }
    // [family (name 1), style (name 2), typographic family (16, else 1), weight, italic 0/1, cff 0/1]
    public static string[] Info(string path) {
        byte[] b = File.ReadAllBytes(path);
        long version = U32(b, 0);
        if (version == 0x74746366) { throw new Exception("a font collection (.ttc): use the single .ttf / .otf files"); }
        int n = U16(b, 4);
        int nameAt = -1, os2At = -1;
        for (int i = 0; i < n; i++) {
            int r = 12 + i * 16;
            string tag = Encoding.ASCII.GetString(b, r, 4);
            int off = (int)U32(b, r + 8);
            if (tag == "name") { nameAt = off; }
            if (tag == "OS/2") { os2At = off; }
        }
        if (nameAt < 0) { throw new Exception("no name table: not a font"); }
        string[] names = new string[18];
        int[] rank = new int[18];
        int count = U16(b, nameAt + 2), strings = nameAt + U16(b, nameAt + 4);
        for (int i = 0; i < count; i++) {
            int r = nameAt + 6 + i * 12;
            int platform = U16(b, r), encoding = U16(b, r + 2), language = U16(b, r + 4), id = U16(b, r + 6), len = U16(b, r + 8), off = U16(b, r + 10);
            if (id >= names.Length) { continue; }
            int score = 0; string s = null;
            if (platform == 3 && (encoding == 1 || encoding == 0)) { s = Encoding.BigEndianUnicode.GetString(b, strings + off, len); score = language == 0x409 ? 3 : 2; }
            else if (platform == 1 && encoding == 0) { s = Encoding.ASCII.GetString(b, strings + off, len); score = 1; }
            if (s != null && score > rank[id]) { names[id] = s; rank[id] = score; }
        }
        int weight = 400, italic = 0;
        if (os2At >= 0) {
            weight = U16(b, os2At + 4);
            int sel = U16(b, os2At + 62);
            if ((sel & 1) != 0) { italic = 1; }
        }
        string style = names[2] ?? "Regular";
        if (style.ToLower().Contains("italic") || style.ToLower().Contains("oblique")) { italic = 1; }
        return new string[] { names[1] ?? "", style, names[16] ?? names[1] ?? "", weight.ToString(), italic.ToString(), version == 0x4F54544F ? "1" : "0" };
    }
    // A font file's family names (name 1 and 16, every language), every font of a collection (.ttc); only
    // its tables' directory and its name table are read.
    public static string[] Families(string path) {
        var found = new System.Collections.Generic.List<string>();
        using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read)) {
            byte[] h = ReadAt(fs, 0, 12);
            long[] fonts = { 0 };
            if (U32(h, 0) == 0x74746366) {
                int count = (int)U32(h, 8);
                byte[] offs = ReadAt(fs, 12, count * 4);
                fonts = new long[count];
                for (int i = 0; i < count; i++) { fonts[i] = U32(offs, i * 4); }
            }
            foreach (long at in fonts) {
                byte[] head = ReadAt(fs, at, 12);
                int n = U16(head, 4);
                byte[] dir = ReadAt(fs, at + 12, n * 16);
                for (int i = 0; i < n; i++) {
                    if (Encoding.ASCII.GetString(dir, i * 16, 4) != "name") { continue; }
                    byte[] b = ReadAt(fs, U32(dir, i * 16 + 8), (int)U32(dir, i * 16 + 12));
                    int records = U16(b, 2), strings = U16(b, 4);
                    for (int k = 0; k < records; k++) {
                        int r = 6 + k * 12;
                        int platform = U16(b, r), id = U16(b, r + 6), len = U16(b, r + 8), off = strings + U16(b, r + 10);
                        if ((id != 1 && id != 16) || off + len > b.Length) { continue; }
                        string s = null;
                        if (platform == 3 || platform == 0) { s = Encoding.BigEndianUnicode.GetString(b, off, len); }
                        else if (platform == 1 && U16(b, r + 2) == 0) { s = Encoding.ASCII.GetString(b, off, len); }
                        if (!string.IsNullOrEmpty(s) && !found.Contains(s)) { found.Add(s); }
                    }
                }
            }
        }
        return found.ToArray();
    }
    static byte[] ReadAt(FileStream fs, long at, int len) {
        byte[] b = new byte[len];
        fs.Seek(at, SeekOrigin.Begin);
        int got = 0;
        while (got < len) { int n = fs.Read(b, got, len - got); if (n <= 0) { throw new Exception("a font file cut short"); } got += n; }
        return b;
    }
    // Word's embedded font: the first 32 bytes XORed with the key (the GUID's 16 bytes, last to first).
    public static byte[] Obfuscate(byte[] font, Guid key) {
        byte[] k = new byte[16];
        string hex = key.ToString("N");
        for (int i = 0; i < 16; i++) { k[i] = Convert.ToByte(hex.Substring(30 - i * 2, 2), 16); }
        byte[] o = (byte[])font.Clone();
        for (int i = 0; i < 32 && i < o.Length; i++) { o[i] ^= k[i % 16]; }
        return o;
    }
}
'@
    $script:fontTool = $true
}
# The installed fonts' families (lowercase name -> $true), from the font files themselves (Windows: the
# machine's and the user's; macOS). Once a run.
$script:installedFonts = $null
function Get-InstalledFontFamilies {
    if ($null -ne $script:installedFonts) { return $script:installedFonts }
    $dirs = @()
    if ($env:WINDIR) { $dirs += (Join-Path $env:WINDIR 'Fonts') }
    if ($env:LOCALAPPDATA) { $dirs += (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts') }
    $dirs += '/System/Library/Fonts', '/Library/Fonts', "$HOME/Library/Fonts"
    $found = @{}
    Initialize-FontTool
    foreach ($d in $dirs) {
        if (-not $d -or -not (Test-Path -LiteralPath $d -PathType Container)) { continue }
        foreach ($f in (Get-ChildItem -LiteralPath $d -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.ttf', '.otf', '.ttc' })) {
            try { foreach ($n in [LazySpecFont]::Families($f.FullName)) { $found[$n.ToLower()] = $true } } catch { }
        }
    }
    $script:installedFonts = $found
    return $found
}

# A small YAML: block mappings by indentation, flow mappings { a: b } and lists [a, b], quoted and plain
# scalars, # comments (a # right after a letter or digit, as in a colour #333333, is a value). Errors name the line.
function ConvertFrom-ThemeYaml([string]$Text, [string]$Path) {
    $lines = New-Object Collections.ArrayList
    $no = 0
    $acc = ''; $accNo = 0; $depth = 0
    foreach ($raw in $Text.Replace("`r", '').Split("`n")) {
        $no++
        # The comment off (outside quotes; " #" or a line starting with #).
        $sb = New-Object Text.StringBuilder
        $q = ''
        for ($i = 0; $i -lt $raw.Length; $i++) {
            $c = $raw[$i]
            if ($q) { if ($c -eq $q) { $q = '' } }
            elseif ($c -eq '"' -or $c -eq "'") { $q = [string]$c }
            elseif ($c -eq '#' -and ($i -eq 0 -or $raw[$i - 1] -eq ' ' -or $raw[$i - 1] -eq "`t") -and ($i + 1 -ge $raw.Length -or $raw[$i + 1] -eq ' ' -or $raw.Substring(0, $i).Trim() -eq '')) { break }
            [void]$sb.Append($c)
        }
        $l = $sb.ToString().TrimEnd()
        if (-not $l.Trim() -and -not $acc) { continue }
        # A flow mapping over several lines: one line.
        if ($acc) { $acc += ' ' + $l.Trim() } else { $acc = $l; $accNo = $no }
        $depth = ([regex]::Matches($acc, '[\{\[]')).Count - ([regex]::Matches($acc, '[\}\]]')).Count
        if ($depth -gt 0) { continue }
        [void]$lines.Add([pscustomobject]@{ No = $accNo; Indent = ($acc.Length - $acc.TrimStart().Length); Text = $acc.Trim() })
        $acc = ''
    }
    if ($acc) { throw "$Path, line $accNo`: a { or [ that isn't closed" }
    $pos = @{ I = 0 }
    $parseFlow = {
        param([string]$S, $P, [int]$LineNo)
        $skip = { while ($P.I -lt $S.Length -and $S[$P.I] -eq ' ') { $P.I++ } }
        & $skip
        if ($P.I -ge $S.Length) { return '' }
        $c = $S[$P.I]
        if ($c -eq '{') {
            $P.I++
            $map = [ordered]@{}
            while ($true) {
                & $skip
                if ($P.I -ge $S.Length) { throw "$Path, line $LineNo`: a { that isn't closed" }
                if ($S[$P.I] -eq '}') { $P.I++; return $map }
                $m = [regex]::Match($S.Substring($P.I), '^("[^"]*"|''[^'']*''|[^:,{}\[\]]+?)\s*:\s*')
                if (-not $m.Success) { throw "$Path, line $LineNo`: 'key: value' expected at '$($S.Substring($P.I))'" }
                $k = $m.Groups[1].Value.Trim('"', "'")
                $P.I += $m.Length
                $map[$k] = & $parseFlow $S $P $LineNo
                & $skip
                if ($P.I -lt $S.Length -and $S[$P.I] -eq ',') { $P.I++ }
            }
        }
        if ($c -eq '[') {
            $P.I++
            $list = New-Object Collections.ArrayList
            while ($true) {
                & $skip
                if ($P.I -ge $S.Length) { throw "$Path, line $LineNo`: a [ that isn't closed" }
                if ($S[$P.I] -eq ']') { $P.I++; return , $list.ToArray() }
                [void]$list.Add((& $parseFlow $S $P $LineNo))
                & $skip
                if ($P.I -lt $S.Length -and $S[$P.I] -eq ',') { $P.I++ }
            }
        }
        if ($c -eq '"' -or $c -eq "'") {
            $end = $S.IndexOf($c, $P.I + 1)
            if ($end -lt 0) { throw "$Path, line $LineNo`: a quote that isn't closed" }
            $v = $S.Substring($P.I + 1, $end - $P.I - 1)
            $P.I = $end + 1
            return $v
        }
        $m = [regex]::Match($S.Substring($P.I), '^[^,{}\[\]]*')
        $P.I += $m.Length
        return $m.Value.Trim()
    }
    $parseBlock = {
        param([int]$Indent)
        $map = [ordered]@{}
        $list = $null
        while ($pos.I -lt $lines.Count) {
            $ln = $lines[$pos.I]
            if ($ln.Indent -lt $Indent) { break }
            if ($ln.Indent -gt $Indent) { throw "$Path, line $($ln.No): indented more than the lines before it" }
            if ($ln.Text.StartsWith('- ') -or $ln.Text -eq '-') {
                if ($null -eq $list) { $list = New-Object Collections.ArrayList }
                $pos.I++
                [void]$list.Add((& $parseFlow $ln.Text.Substring(1).Trim() @{ I = 0 } $ln.No))
                continue
            }
            $m = [regex]::Match($ln.Text, '^("[^"]*"|''[^'']*''|[^:]+?)\s*:(?:\s+(.*))?$')
            if (-not $m.Success) { throw "$Path, line $($ln.No): 'key: value' expected, not '$($ln.Text)'" }
            $k = $m.Groups[1].Value.Trim('"', "'")
            $pos.I++
            if ($m.Groups[2].Success -and $m.Groups[2].Value.Trim() -and $m.Groups[2].Value.Trim() -notmatch '^[\{\[''"]') {
                # A plain value: the rest of the line (commas and all, as YAML reads it).
                $map[$k] = $m.Groups[2].Value.Trim()
            }
            elseif ($m.Groups[2].Success -and $m.Groups[2].Value.Trim()) {
                $p = @{ I = 0 }
                $v = & $parseFlow $m.Groups[2].Value $p $ln.No
                if ($p.I -lt $m.Groups[2].Value.Length -and $m.Groups[2].Value.Substring($p.I).Trim()) { throw "$Path, line $($ln.No): something after the value: '$($m.Groups[2].Value.Substring($p.I).Trim())'" }
                $map[$k] = $v
            }
            elseif ($pos.I -lt $lines.Count -and $lines[$pos.I].Indent -gt $Indent) { $map[$k] = & $parseBlock $lines[$pos.I].Indent }
            else { $map[$k] = '' }
        }
        if ($null -ne $list) { return , $list.ToArray() }
        return $map
    }
    if (-not $lines.Count) { return [ordered]@{} }
    $result = & $parseBlock $lines[0].Indent
    if ($pos.I -lt $lines.Count) { throw "$Path, line $($lines[$pos.I].No): indented less than the first line" }
    return $result
}

# A length ("25mm", "1.5cm", "10pt", "0.5in", "40px") in millimetres; a bare number: $Unit.
function ConvertTo-Mm([string]$V, [string]$Unit = 'mm', [string]$What = 'a length') {
    $m = [regex]::Match("$V".Trim(), '^(-?\d+(?:\.\d+)?)\s*(mm|cm|pt|in|px)?$')
    if (-not $m.Success) { throw "the theme: $What '$V' isn't a length (25mm, 1.5cm, 10pt, 0.5in)" }
    $n = [double]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
    $u = $m.Groups[2].Value
    if (-not $u) { $u = $Unit }
    switch ($u) { 'mm' { return $n } 'cm' { return $n * 10 } 'pt' { return $n * 25.4 / 72 } 'in' { return $n * 25.4 } 'px' { return $n * 25.4 / 96 } }
}
function ConvertTo-Pt([string]$V, [string]$What) { return (ConvertTo-Mm $V 'pt' $What) * 72 / 25.4 }
function Format-Num([double]$N) { return $N.ToString('0.##', [Globalization.CultureInfo]::InvariantCulture) }

# The theme's defaults: LazySpec's own look; the theme's values over them.
$themeDefaults = [ordered]@{
    body = [ordered]@{ font = 'Segoe UI'; size = '10.5pt'; color = '#1f2933'; lineHeight = '1.3' }
    title = [ordered]@{ size = '34pt'; bold = 'true'; color = '#0b3c5d' }
    subtitle = [ordered]@{ size = '18pt'; color = '#4a90c2' }
    heading1 = [ordered]@{ size = '22pt'; bold = 'true'; color = '#0b3c5d' }
    heading2 = [ordered]@{ size = '15pt'; bold = 'true'; color = '#0b3c5d' }
    heading3 = [ordered]@{ size = '12pt'; bold = 'true' }
    heading4 = [ordered]@{ size = '11pt'; bold = 'true' }
    heading5 = [ordered]@{ size = '10.5pt'; bold = 'true' }
    heading6 = [ordered]@{ size = '10.5pt'; bold = 'true' }
    tocHeading = [ordered]@{ size = '22pt'; bold = 'true'; color = '#0b3c5d' }
    table = [ordered]@{ size = '9pt'; borderColor = '#c9d3dc'; headerBackground = '#eaf1f7' }
    link = [ordered]@{ color = '#1d6fa5' }
    code = [ordered]@{ font = 'Consolas'; size = '9pt' }
}
$themeStyleKeys = 'font', 'size', 'bold', 'italic', 'underline', 'color', 'background', 'spaceBefore', 'spaceAfter', 'lineHeight', 'align', 'pageBreakBefore', 'borderColor', 'headerBackground'

# The theme, read and checked: -Theme (relative to the current folder), else documentTheme (relative to the
# project's root); $null when neither is set. Set but missing, broken, or a picture missing: an error.
$script:docTheme = $null
function Get-DocumentTheme {
    $raw = ''
    $base = $Root
    $from = 'lazyspec: documentTheme: in openspec/config.yaml'
    if ($Theme) { $raw = $Theme; $base = (Get-Location).ProviderPath; $from = '-Theme' }
    elseif ($hasRoot) { $raw = [string](Get-ProjectConfig).Values['documentTheme'] }
    $raw = $raw.Trim().Trim('"', "'")
    if (-not $raw) { return $null }
    $path = ($raw -replace '[\\/]', [IO.Path]::DirectorySeparatorChar)
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $base $path }
    $path = [IO.Path]::GetFullPath($path)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "The document theme isn't there: $path ($from). Client documents need the company layout: fix the path (or remove the setting)." }
    $dir = Split-Path $path -Parent
    try { $y = ConvertFrom-ThemeYaml ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)) $path } catch { throw "The document theme can't be read: $($_.Exception.Message)" }
    if ($y -isnot [Collections.IDictionary]) { throw "The document theme isn't a YAML mapping: $path" }
    foreach ($k in $y.Keys) { if ($k -notin 'page', 'colors', 'styles', 'header', 'footer', 'cover', 'numbering') { Write-Host "  ! the theme: '$k' isn't a theme key (page, colors, styles, header, footer, cover, numbering): ignored" } }
    $get = { param($Map, [string]$Key) if ($Map -is [Collections.IDictionary] -and $Map.Contains($Key)) { return $Map[$Key] } return $null }
    $colors = @{}
    $c = & $get $y 'colors'
    if ($c -is [Collections.IDictionary]) { foreach ($k in $c.Keys) { $colors[$k] = [string]$c[$k] } }
    $color = {
        param([string]$V)
        if (-not $V) { return '' }
        if ($colors.ContainsKey($V)) { $V = $colors[$V] }
        if ($V -notmatch '^#?[0-9A-Fa-f]{6}$') { throw "the theme: the colour '$V' isn't #RRGGBB (or a name under colors)" }
        return '#' + $V.TrimStart('#').ToUpper()
    }
    # The styles: LazySpec's defaults, the theme's body under every style, then the style's own.
    $styles = [ordered]@{}
    $ts = & $get $y 'styles'
    if ($ts -and $ts -isnot [Collections.IDictionary]) { throw "the theme: styles must be a mapping (body, title, heading1 ...)" }
    if ($ts) { foreach ($k in $ts.Keys) { if (-not $themeDefaults.Contains($k)) { Write-Host "  ! the theme: the style '$k' isn't one LazySpec uses ($($themeDefaults.Keys -join ', ')): ignored" } } }
    foreach ($name in $themeDefaults.Keys) {
        $s = [ordered]@{}
        foreach ($k in $themeDefaults[$name].Keys) { $s[$k] = $themeDefaults[$name][$k] }
        $own = & $get $ts $name
        if ($own -and $own -isnot [Collections.IDictionary]) { throw "the theme: styles.$name must be a mapping ({ font: ..., size: ... })" }
        if ($own) {
            foreach ($k in $own.Keys) {
                if ($k -notin $themeStyleKeys) { Write-Host "  ! the theme: styles.$name.$k isn't a style property ($($themeStyleKeys -join ', ')): ignored"; continue }
                $s[$k] = [string]$own[$k]
            }
        }
        foreach ($k in 'color', 'background', 'borderColor', 'headerBackground') { if ($s.Contains($k) -and $s[$k]) { $s[$k] = & $color $s[$k] } }
        foreach ($k in 'size', 'spaceBefore', 'spaceAfter') { if ($s.Contains($k) -and $s[$k]) { [void](ConvertTo-Pt $s[$k] "styles.$name.$k") } }
        $styles[$name] = $s
    }
    # Every style's font: its own, else the body's (code keeps its own).
    foreach ($name in $styles.Keys) { if (-not $styles[$name].Contains('font') -or -not $styles[$name]['font']) { $styles[$name]['font'] = $styles.body.font } }
    # Every heading's colour: its own, else the body's (not LazySpec's blue: the company's look only).
    foreach ($name in 'heading1', 'heading2', 'heading3', 'heading4', 'heading5', 'heading6', 'tocHeading') {
        if ($styles.Contains($name) -and -not $styles[$name]['color'] -and $styles.body['color']) { $styles[$name]['color'] = $styles.body['color'] }
    }
    # The page.
    $page = & $get $y 'page'
    $size = [string](& $get $page 'size')
    $pw = 210.0; $ph = 297.0
    if ($size) {
        switch -Regex ($size.Trim()) {
            '^(?i)a4$' { $pw = 210; $ph = 297 }
            '^(?i)a5$' { $pw = 148; $ph = 210 }
            '^(?i)letter$' { $pw = 215.9; $ph = 279.4 }
            '^(?i)legal$' { $pw = 215.9; $ph = 355.6 }
            default { $parts = $size.Trim() -split '\s+'; if ($parts.Count -ne 2) { throw "the theme: page.size '$size' isn't A4, A5, Letter, Legal or '<width> <height>'" }; $pw = ConvertTo-Mm $parts[0] 'mm' 'page.size'; $ph = ConvertTo-Mm $parts[1] 'mm' 'page.size' }
        }
    }
    $mg = @{ top = 25.0; right = 20.0; bottom = 22.0; left = 20.0 }
    $m = & $get $page 'margins'
    if ($m -is [Collections.IDictionary]) { foreach ($k in 'top', 'right', 'bottom', 'left') { if ($m.Contains($k)) { $mg[$k] = ConvertTo-Mm $m[$k] 'mm' "page.margins.$k" } } }
    elseif ($m) {
        $v = @("$m".Trim() -split '\s+' | ForEach-Object { ConvertTo-Mm $_ 'mm' 'page.margins' })
        switch ($v.Count) { 1 { $mg = @{ top = $v[0]; right = $v[0]; bottom = $v[0]; left = $v[0] } } 2 { $mg = @{ top = $v[0]; right = $v[1]; bottom = $v[0]; left = $v[1] } } 4 { $mg = @{ top = $v[0]; right = $v[1]; bottom = $v[2]; left = $v[3] } } default { throw "the theme: page.margins '$m': 1, 2 or 4 lengths, or { top, right, bottom, left }" } }
    }
    # A picture of the theme (relative to it): checked here.
    $picture = {
        param([string]$P, [string]$What)
        if (-not $P) { return '' }
        $f = ($P -replace '[\\/]', [IO.Path]::DirectorySeparatorChar)
        if (-not [IO.Path]::IsPathRooted($f)) { $f = Join-Path $dir $f }
        $f = [IO.Path]::GetFullPath($f)
        if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { throw "the theme's $What isn't there: $f" }
        if ([IO.Path]::GetExtension($f).ToLower() -notin '.png', '.jpg', '.jpeg', '.gif') { throw "the theme's $What must be a .png, .jpg or .gif (Word takes those): $f" }
        return $f
    }
    # Header and footer: left, center, right (a text with {title} {subtitle} {client} {date} {page} {pages},
    # or "logo"), the logo and its height, their text's size and colour, on the first page (the cover) or not.
    $band = {
        param($B, [string]$Name, [string]$DefaultSize)
        $r = [pscustomobject]@{ Left = ''; Center = ''; Right = ''; Logo = ''; LogoHeight = 10.0; Size = $DefaultSize; Color = '#8A96A3'; FirstPage = $false; Any = $false }
        if (-not $B) { return $r }
        if ($B -isnot [Collections.IDictionary]) { throw "the theme: $Name must be a mapping ({ left: ..., right: ... })" }
        foreach ($k in $B.Keys) { if ($k -notin 'left', 'center', 'right', 'logo', 'logoHeight', 'size', 'color', 'firstPage') { Write-Host "  ! the theme: $Name.$k isn't a $Name key: ignored" } }
        $r.Left = [string](& $get $B 'left'); $r.Center = [string](& $get $B 'center'); $r.Right = [string](& $get $B 'right')
        $r.Logo = & $picture ([string](& $get $B 'logo')) "$Name logo"
        if (& $get $B 'logoHeight') { $r.LogoHeight = ConvertTo-Mm (& $get $B 'logoHeight') 'mm' "$Name.logoHeight" }
        if (& $get $B 'size') { $r.Size = [string](& $get $B 'size'); [void](ConvertTo-Pt $r.Size "$Name.size") }
        if (& $get $B 'color') { $r.Color = & $color ([string](& $get $B 'color')) }
        $r.FirstPage = [string](& $get $B 'firstPage') -eq 'true'
        foreach ($slot in 'Left', 'Center', 'Right') { if ($r.$slot -eq 'logo' -and -not $r.Logo) { throw "the theme: $Name.$($slot.ToLower()) is 'logo', but $Name.logo names no picture" } }
        $r.Any = [bool]($r.Left -or $r.Center -or $r.Right)
        return $r
    }
    $header = & $band (& $get $y 'header') 'header' '8pt'
    $footer = & $band (& $get $y 'footer') 'footer' '8pt'
    $cv = & $get $y 'cover'
    $cover = [pscustomobject]@{ Logo = ''; LogoHeight = 25.0 }
    if ($cv -is [Collections.IDictionary]) {
        $cover.Logo = & $picture ([string](& $get $cv 'logo')) 'cover logo'
        if (& $get $cv 'logoHeight') { $cover.LogoHeight = ConvertTo-Mm (& $get $cv 'logoHeight') 'mm' 'cover.logoHeight' }
    }
    # The fonts in fonts\ next to the theme.
    $fonts = @()
    $fontDir = Join-Path $dir 'fonts'
    if (Test-Path -LiteralPath $fontDir -PathType Container) {
        Initialize-FontTool
        # Its subfolders too (a family's own folder, as it comes from the font's maker).
        foreach ($f in @(Get-ChildItem -LiteralPath $fontDir -File -Recurse | Where-Object { $_.Extension -match '^\.(ttf|otf)$' } | Sort-Object FullName)) {
            try {
                $i = [LazySpecFont]::Info($f.FullName)
                $fonts += [pscustomobject]@{ Path = $f.FullName; Family = $i[0]; Style = $i[1]; Typographic = $i[2]; Weight = [int]$i[3]; Italic = $i[4] -eq '1'; Cff = $i[5] -eq '1' }
            } catch { Write-Host "  ! the theme's font $($f.Name) not used: $($_.Exception.Message)" }
        }
    }
    # numbering: false - no numbers before the chapters' titles, nor before a document's own headings 1-2 ("1. Kostur").
    $numbering = [string](& $get $y 'numbering') -ne 'false'
    $t = [pscustomobject]@{ Numbering = $numbering; Path = $path; Dir = $dir; From = $from; PageW = $pw; PageH = $ph; Margins = $mg; Styles = $styles; Colors = $colors; Header = $header; Footer = $footer; Cover = $cover; Fonts = $fonts }
    return $t
}

# The fonts the theme's styles use: from fonts\ (their files), else installed, else missing (a warning).
function Get-ThemeFontFamilies($T) {
    $used = @{}
    foreach ($s in $T.Styles.Values) { if ($s.font) { $used[$s.font] = $true } }
    return @($used.Keys | Sort-Object)
}
# A family's files in fonts\, regular, bold, italic, bold italic (by the family Word knows them by, or the typographic one).
function Get-ThemeFontFiles($T, [string]$Family) {
    $files = @($T.Fonts | Where-Object { $_.Family -ieq $Family })
    if (-not $files.Count) { $files = @($T.Fonts | Where-Object { $_.Typographic -ieq $Family -and ($_.Weight -eq 400 -or $_.Weight -eq 700) }) }
    return $files
}
function Write-ThemeFontWarning($T, [bool]$ForWord) {
    $installed = Get-InstalledFontFamilies
    $missing = @()
    foreach ($fam in (Get-ThemeFontFamilies $T)) {
        if (@(Get-ThemeFontFiles $T $fam).Count) { continue }
        if (-not $installed.ContainsKey($fam.ToLower())) { $missing += $fam }
    }
    if ($missing.Count) { Write-Host "  ! the theme's fonts neither in $(Join-Path $T.Dir 'fonts') nor installed: $($missing -join ', ') (others are used in their place)" }
    if ($ForWord) {
        foreach ($fam in (Get-ThemeFontFamilies $T)) {
            foreach ($f in (Get-ThemeFontFiles $T $fam)) { if ($f.Cff) { Write-Host "  ! $(Split-Path $f.Path -Leaf): an OpenType (CFF) font; Word embeds TrueType (.ttf) fonts best: use the .ttf if there is one" } }
        }
    }
}


# A header's or footer's text: {title} {subtitle} {client} {date}; {page} and {pages} stay for the formats.
function Expand-ThemeText([string]$Text, $Meta) {
    $t = $Text
    foreach ($k in 'title', 'subtitle', 'client', 'date') { $t = $t.Replace("{$k}", [string]$Meta.$k) }
    return $t
}
function Get-CssString([string]$T) { return '"' + $T.Replace('\', '\\').Replace('"', '\"').Replace("`n", ' ') + '"' }
# A picture at a given height (mm) as a CSS image: the picture itself, its resolution set so that it is that
# high (image-set ... Nx). Not inside an SVG: Chrome prints before it loads a picture inside one.
function Get-CssPicture([string]$Path, [double]$HeightMm) {
    Initialize-ImageTool
    $size = [LazySpecImage]::Size($Path)
    $x = $size[1] / ($HeightMm / 25.4 * 96)
    $mime = @{ '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif' }[[IO.Path]::GetExtension($Path).ToLower()]
    $img = "data:$mime;base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
    return "image-set(url($img) $($x.ToString('0.####', [Globalization.CultureInfo]::InvariantCulture))x)"
}
# A style's CSS declarations.
function Get-ThemeCssDecl($S, [bool]$WithFont = $true) {
    $d = @()
    if ($WithFont -and $S.font) { $d += "font-family: '$($S.font.Replace("'", ''))', 'Segoe UI', Arial, sans-serif" }
    if ($S.size) { $d += "font-size: $(Format-Num (ConvertTo-Pt $S.size 'size'))pt" }
    if ($S.Contains('bold')) { $d += "font-weight: $(if ($S.bold -eq 'true') { '700' } else { '400' })" }
    if ($S.Contains('italic')) { $d += "font-style: $(if ($S.italic -eq 'true') { 'italic' } else { 'normal' })" }
    if ($S.Contains('underline')) { $d += "text-decoration: $(if ($S.underline -eq 'true') { 'underline' } else { 'none' })" }
    if ($S.color) { $d += "color: $($S.color)" }
    if ($S.background) { $d += "background: $($S.background)" }
    if ($S.spaceBefore) { $d += "margin-top: $(Format-Num (ConvertTo-Pt $S.spaceBefore 'spaceBefore'))pt" }
    if ($S.spaceAfter) { $d += "margin-bottom: $(Format-Num (ConvertTo-Pt $S.spaceAfter 'spaceAfter'))pt" }
    if ($S.lineHeight) { $d += "line-height: $($S.lineHeight)" }
    if ($S.align) { $d += "text-align: $(@{ left = 'left'; center = 'center'; right = 'right'; justify = 'justify'; both = 'justify' }[$S.align])" }
    if ($S.Contains('pageBreakBefore')) { $d += "page-break-before: $(if ($S.pageBreakBefore -eq 'true') { 'always' } else { 'auto' })" }
    return ($d -join '; ')
}
# A scenario's text size (pt): the body's less 1pt (8pt at least).
function Get-ScenarioPt($T) {
    $body = 11.0
    if ($T.Styles.body.size) { $body = ConvertTo-Pt $T.Styles.body.size 'size' }
    return [Math]::Max(8.0, $body - 1)
}
# The theme as CSS: its fonts (the files, inside the document), its styles over LazySpec's, and for PDF the
# page: size, margins, the header and footer (a logo, texts, the page number), the cover without them.
function Get-ThemeCss($T, $Meta, [bool]$Paged) {
    $sb = New-Object Text.StringBuilder
    foreach ($fam in (Get-ThemeFontFamilies $T)) {
        foreach ($f in (Get-ThemeFontFiles $T $fam)) {
            $weight = $f.Weight
            if ($f.Family -ieq $fam) { $weight = if ($f.Style -match '(?i)bold') { 700 } else { 400 } }
            $fmt = 'truetype'; $mime = 'font/ttf'
            if ([IO.Path]::GetExtension($f.Path) -ieq '.otf') { $fmt = 'opentype'; $mime = 'font/otf' }
            [void]$sb.Append("@font-face { font-family: '$($fam.Replace("'", ''))'; src: url(data:$mime;base64,$([Convert]::ToBase64String([IO.File]::ReadAllBytes($f.Path)))) format('$fmt'); font-weight: $weight; font-style: $(if ($f.Italic) { 'italic' } else { 'normal' }); }`n")
        }
    }
    $s = $T.Styles
    $rules = [ordered]@{
        'body, p, li, td, th, div, blockquote, .scenario p, .scenario li' = (Get-ThemeCssDecl ([ordered]@{ font = $s.body.font; size = $s.body.size; color = $s.body.color; lineHeight = $s.body.lineHeight }))
        # A scenario's text under its title's and its requirement's: 1pt smaller than the body's.
        '.scenario, .scenario p, .scenario li' = "font-size: $(Format-Num (Get-ScenarioPt $T))pt"
        'p' = (Get-ThemeCssDecl ([ordered]@{ spaceBefore = $s.body.spaceBefore; spaceAfter = $s.body.spaceAfter; align = $s.body.align }))
        '.cover .title' = (Get-ThemeCssDecl $s.title)
        '.cover .subtitle' = (Get-ThemeCssDecl $s.subtitle)
        'h1, h1.part, h1.cap, h1.sec, h1.sub, h1.req, h1.scn' = (Get-ThemeCssDecl $s.heading1)
        'h2, h2.part, h2.cap, h2.sec, h2.sub, h2.req, h2.scn' = (Get-ThemeCssDecl $s.heading2)
        'h3, h3.part, h3.cap, h3.sec, h3.sub, h3.req, h3.scn' = (Get-ThemeCssDecl $s.heading3)
        'h4, h4.part, h4.cap, h4.sec, h4.sub, h4.req, h4.scn' = (Get-ThemeCssDecl $s.heading4)
        'h5, h5.part, h5.cap, h5.sec, h5.sub, h5.req, h5.scn' = (Get-ThemeCssDecl $s.heading5)
        'h6, h6.part, h6.cap, h6.sec, h6.sub, h6.req, h6.scn' = (Get-ThemeCssDecl $s.heading6)
        # Room before a capability, a requirement, a scenario: LazySpec's, over the theme's headings'.
        'h2.cap, h3.cap, h4.cap' = 'margin-top: 30pt'
        'h2.req, h3.req, h4.req, h5.req, h6.req' = 'margin-top: 24pt'
        'h3.scn, h4.scn, h5.scn, h6.scn' = 'margin-top: 14pt'
        '.toc-title' = (Get-ThemeCssDecl $s.tocHeading)
        'table, th, td' = (Get-ThemeCssDecl ([ordered]@{ font = $s.table.font; size = $s.table.size; color = $s.table.color }))
        'th, td' = "border-color: $($s.table.borderColor)"
        'th' = "background: $($s.table.headerBackground)"
        'a' = (Get-ThemeCssDecl $s.link $false)
        'code, pre, pre code, pre.wrap, pre.wrap code' = (Get-ThemeCssDecl ([ordered]@{ font = $s.code.font; size = $s.code.size; color = $s.code.color }))
        # The company's look, not LazySpec's: no lines under the headings (the cover's bar in the headings' colour).
        'h1, h1.part, .toc-title, h2.cap, h2.sec, h3.sec, .sec, .sub' = 'border: none; padding-bottom: 0'
        '.cover .bar' = "border-color: $(if ($s.heading1.color) { $s.heading1.color } else { '#f07b4f' })"
        # The contents: plain text, as a Word contents (still links).
        '.toc a, ul.toc-list a, p.toc-scn a' = 'color: inherit; text-decoration: none'
        # The contents' entries as Word's (toc 1: 6pt above each).
        '.toc p' = 'margin: 6pt 0 0'
        # Room: between list items, as between paragraphs (half).
        'li' = "margin: 0 0 $(Format-Num ([Math]::Max(2, (ConvertTo-Pt $(if ($s.body.spaceAfter) { $s.body.spaceAfter } else { '6pt' }) 'spaceAfter') / 2)))pt"
        '.cover-logo' = 'margin: 0 0 30pt'
    }
    foreach ($k in $rules.Keys) { if ($rules[$k]) { [void]$sb.Append("$k { $($rules[$k]); }`n") } }
    if ($Paged) {
        $m = $T.Margins
        [void]$sb.Append("@page { size: $(Format-Num $T.PageW)mm $(Format-Num $T.PageH)mm; margin: $(Format-Num $m.top)mm $(Format-Num $m.right)mm $(Format-Num $m.bottom)mm $(Format-Num $m.left)mm;`n")
        $first = New-Object Text.StringBuilder
        foreach ($band in @(@{ B = $T.Header; At = 'top' }, @{ B = $T.Footer; At = 'bottom' })) {
            $b = $band.B
            foreach ($slot in 'Left', 'Center', 'Right') {
                $v = $b.$slot
                if (-not $v) { continue }
                $box = "@$($band.At)-$($slot.ToLower())"
                if ($v -eq 'logo') { $content = Get-CssPicture $b.Logo $b.LogoHeight }
                else {
                    $parts = [regex]::Split((Expand-ThemeText $v $Meta), '(\{page\}|\{pages\})') | Where-Object { $_ -ne '' }
                    $content = (@($parts | ForEach-Object { if ($_ -eq '{page}') { 'counter(page)' } elseif ($_ -eq '{pages}') { 'counter(pages)' } else { Get-CssString $_ } }) -join ' ')
                }
                # Towards the text, with room between them (as Word's header and footer distance).
                $va = 'bottom'; $pad = 'padding-bottom: 6mm'
                if ($band.At -eq 'bottom') { $va = 'top'; $pad = 'padding-top: 5mm' }
                [void]$sb.Append("  $box { content: $content; font-family: '$($s.body.font.Replace("'", ''))', 'Segoe UI', sans-serif; font-size: $(Format-Num (ConvertTo-Pt $b.Size 'size'))pt; color: $($b.Color); vertical-align: $va; $pad; }`n")
                if (-not $b.FirstPage) { [void]$first.Append("$box { content: none; } ") }
            }
        }
        [void]$sb.Append("}`n")
        if ($first.Length) { [void]$sb.Append("@page :first { $($first.ToString())}`n") }
    }
    return $sb.ToString()
}

# --- the theme as a Word base document ---
function ConvertTo-Twips([double]$Mm) { return [int][Math]::Round($Mm * 1440 / 25.4) }
function Get-ThemeRpr($S, [bool]$WithFont = $true) {
    $r = ''
    if ($WithFont -and $S.font) { $f = Xml $S.font; $r += "<w:rFonts w:ascii=`"$f`" w:hAnsi=`"$f`" w:eastAsia=`"$f`" w:cs=`"$f`"/>" }
    if ($S.Contains('bold')) { if ($S.bold -eq 'true') { $r += '<w:b/><w:bCs/>' } else { $r += '<w:b w:val="0"/><w:bCs w:val="0"/>' } }
    if ($S.Contains('italic')) { if ($S.italic -eq 'true') { $r += '<w:i/><w:iCs/>' } else { $r += '<w:i w:val="0"/><w:iCs w:val="0"/>' } }
    if ($S.color) { $r += "<w:color w:val=`"$($S.color.TrimStart('#'))`"/>" }
    if ($S.size) { $hp = [int][Math]::Round((ConvertTo-Pt $S.size 'size') * 2); $r += "<w:sz w:val=`"$hp`"/><w:szCs w:val=`"$hp`"/>" }
    if ($S.Contains('underline')) { if ($S.underline -eq 'true') { $r += '<w:u w:val="single"/>' } else { $r += '<w:u w:val="none"/>' } }
    if ($r) { return "<w:rPr>$r</w:rPr>" }
    return ''
}
function Get-ThemePpr($S, [string]$Before, [string]$After, [bool]$Heading, [int]$Outline = -1) {
    $p = ''
    if ($Heading) { $p += '<w:keepNext/><w:keepLines/>' }
    if ($S.Contains('pageBreakBefore') -and $S.pageBreakBefore -eq 'true') { $p += '<w:pageBreakBefore/>' }
    $b = $Before; $a = $After
    if ($S.spaceBefore) { $b = [string](ConvertTo-Twips ((ConvertTo-Pt $S.spaceBefore 'spaceBefore') * 25.4 / 72)) }
    if ($S.spaceAfter) { $a = [string](ConvertTo-Twips ((ConvertTo-Pt $S.spaceAfter 'spaceAfter') * 25.4 / 72)) }
    $sp = ''
    if ($b) { $sp += " w:before=`"$b`"" }
    if ($a) { $sp += " w:after=`"$a`"" }
    if ($S.lineHeight) {
        $lh = [double]::Parse($S.lineHeight, [Globalization.CultureInfo]::InvariantCulture)
        # With a size: at least size x line height, as a browser sets it (Word's multiple multiplies the font's own
        # line gap, large in some fonts); without one: Word's multiple.
        if ($S.size) { $sp += " w:line=`"$([int][Math]::Round((ConvertTo-Pt $S.size 'size') * $lh * 20))`" w:lineRule=`"atLeast`"" }
        else { $sp += " w:line=`"$([int][Math]::Round(240 * $lh))`" w:lineRule=`"auto`"" }
    }
    if ($sp) { $p += "<w:spacing$sp/>" }
    if ($S.align) { $p += "<w:jc w:val=`"$(@{ left = 'left'; center = 'center'; right = 'right'; justify = 'both'; both = 'both' }[$S.align])`"/>" }
    if ($Outline -ge 0) { $p += "<w:outlineLvl w:val=`"$Outline`"/>" }
    if ($p) { return "<w:pPr>$p</w:pPr>" }
    return ''
}
function Get-ThemeStylesXml($T) {
    $s = $T.Styles
    $w = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"'
    $body = $s.body
    $x = New-Object Text.StringBuilder
    [void]$x.Append("<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:styles $w><w:docDefaults><w:rPrDefault>$(Get-ThemeRpr ([ordered]@{ font = $body.font; size = $body.size; color = $body.color }))</w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after=`"120`" w:line=`"276`" w:lineRule=`"auto`"/></w:pPr></w:pPrDefault></w:docDefaults>")
    $para = {
        param([string]$Id, [string]$Name, [string]$Extra, [string]$Ppr, [string]$Rpr, [string]$Based = 'Normal')
        $basedOn = ''
        if ($Based) { $basedOn = "<w:basedOn w:val=`"$Based`"/><w:next w:val=`"Normal`"/>" }
        [void]$x.Append("<w:style w:type=`"paragraph`" w:styleId=`"$Id`"><w:name w:val=`"$Name`"/>$basedOn$Extra<w:qFormat/>$Ppr$Rpr</w:style>")
    }
    [void]$x.Append("<w:style w:type=`"paragraph`" w:default=`"1`" w:styleId=`"Normal`"><w:name w:val=`"Normal`"/><w:qFormat/>$(Get-ThemePpr ([ordered]@{ size = $body.size; spaceBefore = $body.spaceBefore; spaceAfter = $body.spaceAfter; lineHeight = $body.lineHeight; align = $body.align }) '' '120' $false)$(Get-ThemeRpr $body)</w:style>")
    [void]$x.Append('<w:style w:type="character" w:default="1" w:styleId="DefaultParagraphFont"><w:name w:val="Default Paragraph Font"/><w:uiPriority w:val="1"/><w:semiHidden/><w:unhideWhenUsed/></w:style>')
    [void]$x.Append('<w:style w:type="table" w:default="1" w:styleId="TableNormal"><w:name w:val="Normal Table"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/><w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="108" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>')
    [void]$x.Append('<w:style w:type="numbering" w:default="1" w:styleId="NoList"><w:name w:val="No List"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/></w:style>')
    & $para 'Title' 'Title' '' (Get-ThemePpr $s.title '0' '120' $true) (Get-ThemeRpr $s.title)
    & $para 'Subtitle' 'Subtitle' '' (Get-ThemePpr $s.subtitle '0' '600' $true) (Get-ThemeRpr $s.subtitle)
    $space = @{ 1 = @('0', '280'); 2 = @('360', '120'); 3 = @('280', '80'); 4 = @('200', '60'); 5 = @('200', '60'); 6 = @('200', '60') }
    for ($i = 1; $i -le 6; $i++) { & $para "Heading$i" "heading $i" '' (Get-ThemePpr $s["heading$i"] $space[$i][0] $space[$i][1] $true ($i - 1)) (Get-ThemeRpr $s["heading$i"]) }
    $la = [int][Math]::Max(40, [Math]::Round((ConvertTo-Pt $(if ($body.spaceAfter) { $body.spaceAfter } else { '6pt' }) 'spaceAfter') * 10))
    & $para 'ListParagraph' 'List Paragraph' '<w:uiPriority w:val="34"/>' "<w:pPr><w:spacing w:after=`"$la`"/><w:ind w:left=`"720`"/></w:pPr>" ''
    & $para 'TOCHeading' 'TOC Heading' '<w:uiPriority w:val="39"/><w:unhideWhenUsed/>' (Get-ThemePpr $s.tocHeading '0' '280' $true 9) (Get-ThemeRpr $s.tocHeading) 'Heading1'
    $tw = ConvertTo-Twips ($T.PageW - $T.Margins.left - $T.Margins.right)
    & $para 'TOC1' 'toc 1' '<w:uiPriority w:val="39"/><w:unhideWhenUsed/>' "<w:pPr><w:tabs><w:tab w:val=`"right`" w:leader=`"dot`" w:pos=`"$tw`"/></w:tabs><w:spacing w:before=`"120`" w:after=`"0`"/></w:pPr>" ''
    & $para 'TOC2' 'toc 2' '<w:uiPriority w:val="39"/><w:unhideWhenUsed/>' "<w:pPr><w:tabs><w:tab w:val=`"right`" w:leader=`"dot`" w:pos=`"$tw`"/></w:tabs><w:spacing w:before=`"120`" w:after=`"0`"/><w:ind w:left=`"220`"/></w:pPr>" ''
    $tb = $s.table
    $bc = $tb.borderColor.TrimStart('#')
    $edges = -join @('top', 'left', 'bottom', 'right', 'insideH', 'insideV' | ForEach-Object { "<w:$_ w:val=`"single`" w:sz=`"4`" w:space=`"0`" w:color=`"$bc`"/>" })
    [void]$x.Append("<w:style w:type=`"table`" w:styleId=`"TableGrid`"><w:name w:val=`"Table Grid`"/><w:basedOn w:val=`"TableNormal`"/><w:uiPriority w:val=`"39`"/><w:pPr><w:spacing w:before=`"40`" w:after=`"40`" w:line=`"240`" w:lineRule=`"auto`"/></w:pPr>$(Get-ThemeRpr ([ordered]@{ font = $tb.font; size = $tb.size; color = $tb.color }))<w:tblPr><w:tblBorders>$edges</w:tblBorders><w:tblCellMar><w:left w:w=`"108`" w:type=`"dxa`"/><w:right w:w=`"108`" w:type=`"dxa`"/></w:tblCellMar></w:tblPr><w:tblStylePr w:type=`"firstRow`"><w:rPr><w:b/><w:bCs/></w:rPr><w:tcPr><w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"$($tb.headerBackground.TrimStart('#'))`"/></w:tcPr></w:tblStylePr></w:style>")
    $link = [ordered]@{}
    foreach ($k in $s.link.Keys) { if ($k -ne 'font') { $link[$k] = $s.link[$k] } }
    if (-not $link.Contains('underline')) { $link['underline'] = 'true' }
    [void]$x.Append("<w:style w:type=`"character`" w:styleId=`"Hyperlink`"><w:name w:val=`"Hyperlink`"/><w:basedOn w:val=`"DefaultParagraphFont`"/><w:uiPriority w:val=`"99`"/><w:unhideWhenUsed/>$(Get-ThemeRpr $link $false)</w:style>")
    [void]$x.Append('</w:styles>')
    return $x.ToString()
}
# A header's or footer's paragraph: left, a centre tab, centre, a right tab, right; a logo, texts, PAGE / NUMPAGES.
function Get-ThemeBandXml($T, $B, $Meta, [string]$LogoRel, [int]$DocPr) {
    $width = ConvertTo-Twips ($T.PageW - $T.Margins.left - $T.Margins.right)
    $f = Xml $T.Styles.body.font
    $hp = [int][Math]::Round((ConvertTo-Pt $B.Size 'size') * 2)
    $rpr = "<w:rPr><w:rFonts w:ascii=`"$f`" w:hAnsi=`"$f`" w:cs=`"$f`"/><w:color w:val=`"$($B.Color.TrimStart('#'))`"/><w:sz w:val=`"$hp`"/><w:szCs w:val=`"$hp`"/></w:rPr>"
    $field = { param([string]$Code) "<w:r>$rpr<w:fldChar w:fldCharType=`"begin`"/></w:r><w:r>$rpr<w:instrText xml:space=`"preserve`"> $Code </w:instrText></w:r><w:r>$rpr<w:fldChar w:fldCharType=`"separate`"/></w:r><w:r>$rpr<w:t>1</w:t></w:r><w:r>$rpr<w:fldChar w:fldCharType=`"end`"/></w:r>" }
    $slotXml = {
        param([string]$V)
        if (-not $V) { return '' }
        if ($V -eq 'logo') {
            Initialize-ImageTool
            $size = [LazySpecImage]::Size($B.Logo)
            $cy = [long]($B.LogoHeight * 36000); $cx = [long]($cy * $size[0] / $size[1])
            $name = Split-Path $B.Logo -Leaf
            return "<w:r><w:drawing><wp:inline distT=`"0`" distB=`"0`" distL=`"0`" distR=`"0`"><wp:extent cx=`"$cx`" cy=`"$cy`"/><wp:docPr id=`"$DocPr`" name=`"Logo`"/><wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a=`"http://schemas.openxmlformats.org/drawingml/2006/main`" noChangeAspect=`"1`"/></wp:cNvGraphicFramePr><a:graphic xmlns:a=`"http://schemas.openxmlformats.org/drawingml/2006/main`"><a:graphicData uri=`"http://schemas.openxmlformats.org/drawingml/2006/picture`"><pic:pic xmlns:pic=`"http://schemas.openxmlformats.org/drawingml/2006/picture`"><pic:nvPicPr><pic:cNvPr id=`"$DocPr`" name=`"$(Xml $name)`"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed=`"$LogoRel`"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x=`"0`" y=`"0`"/><a:ext cx=`"$cx`" cy=`"$cy`"/></a:xfrm><a:prstGeom prst=`"rect`"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>"
        }
        $o = ''
        foreach ($part in ([regex]::Split((Expand-ThemeText $V $Meta), '(\{page\}|\{pages\})') | Where-Object { $_ -ne '' })) {
            if ($part -eq '{page}') { $o += & $field 'PAGE' }
            elseif ($part -eq '{pages}') { $o += & $field 'NUMPAGES' }
            else { $o += "<w:r>$rpr<w:t xml:space=`"preserve`">$(Xml $part)</w:t></w:r>" }
        }
        return $o
    }
    $tab = "<w:r>$rpr<w:tab/></w:r>"
    return "<w:p><w:pPr><w:tabs><w:tab w:val=`"center`" w:pos=`"$([int]($width / 2))`"/><w:tab w:val=`"right`" w:pos=`"$width`"/></w:tabs><w:spacing w:after=`"0`"/></w:pPr>$(& $slotXml $B.Left)$tab$(& $slotXml $B.Center)$tab$(& $slotXml $B.Right)</w:p>"
}
# Word's theme part: the theme's fonts as its heading and body fonts, its colours as the accents.
function Get-ThemePartXml($T) {
    $s = $T.Styles
    $accent = '4472C4'
    if ($s.heading1.color) { $accent = $s.heading1.color.TrimStart('#') }
    $text = '000000'
    if ($s.body.color) { $text = $s.body.color.TrimStart('#') }
    $link = '0563C1'
    if ($s.link.color) { $link = $s.link.color.TrimStart('#') }
    $clr = { param([string]$N, [string]$V) "<a:$N><a:srgbClr val=`"$V`"/></a:$N>" }
    $fill = '<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>'
    $ln = '<a:ln w="6350"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>'
    $eff = '<a:effectStyle><a:effectLst/></a:effectStyle>'
    return "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><a:theme xmlns:a=`"http://schemas.openxmlformats.org/drawingml/2006/main`" name=`"LazySpec`"><a:themeElements>" +
        "<a:clrScheme name=`"LazySpec`"><a:dk1><a:sysClr val=`"windowText`" lastClr=`"000000`"/></a:dk1><a:lt1><a:sysClr val=`"window`" lastClr=`"FFFFFF`"/></a:lt1>$(& $clr 'dk2' $text)$(& $clr 'lt2' 'E7E6E6')" +
        "$(& $clr 'accent1' $accent)$(& $clr 'accent2' $accent)$(& $clr 'accent3' 'A5A5A5')$(& $clr 'accent4' 'FFC000')$(& $clr 'accent5' '5B9BD5')$(& $clr 'accent6' '70AD47')$(& $clr 'hlink' $link)$(& $clr 'folHlink' '954F72')</a:clrScheme>" +
        "<a:fontScheme name=`"LazySpec`"><a:majorFont><a:latin typeface=`"$(Xml $s.heading1.font)`"/><a:ea typeface=`"`"/><a:cs typeface=`"`"/></a:majorFont><a:minorFont><a:latin typeface=`"$(Xml $s.body.font)`"/><a:ea typeface=`"`"/><a:cs typeface=`"`"/></a:minorFont></a:fontScheme>" +
        "<a:fmtScheme name=`"LazySpec`"><a:fillStyleLst>$fill$fill$fill</a:fillStyleLst><a:lnStyleLst>$ln$ln$ln</a:lnStyleLst><a:effectStyleLst>$eff$eff$eff</a:effectStyleLst><a:bgFillStyleLst>$fill$fill$fill</a:bgFillStyleLst></a:fmtScheme>" +
        '</a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>'
}
# The base .docx of a theme: its styles, page, header and footer (none on the cover unless firstPage), and
# its fonts embedded (obfuscated, as Word embeds them): Word shows them without installing them.
function New-ThemeDocxBase($T, $Meta) {
    $w = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
    $wp = 'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"'
    $relT = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
    $parts = [ordered]@{}
    $ct = New-Object Text.StringBuilder
    [void]$ct.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="jpeg" ContentType="image/jpeg"/><Default Extension="jpg" ContentType="image/jpeg"/><Default Extension="gif" ContentType="image/gif"/><Default Extension="odttf" ContentType="application/vnd.openxmlformats-officedocument.obfuscatedFont"/>')
    $override = { param([string]$Part, [string]$Type) [void]$ct.Append("<Override PartName=`"$Part`" ContentType=`"application/vnd.openxmlformats-officedocument.$Type`"/>") }
    & $override '/word/document.xml' 'wordprocessingml.document.main+xml'
    & $override '/word/styles.xml' 'wordprocessingml.styles+xml'
    & $override '/word/settings.xml' 'wordprocessingml.settings+xml'
    & $override '/word/fontTable.xml' 'wordprocessingml.fontTable+xml'
    & $override '/word/numbering.xml' 'wordprocessingml.numbering+xml'
    & $override '/docProps/app.xml' 'extended-properties+xml'
    [void]$ct.Append('<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>')
    $parts['_rels/.rels'] = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><Relationships xmlns=`"http://schemas.openxmlformats.org/package/2006/relationships`"><Relationship Id=`"rId1`" Type=`"$relT/officeDocument`" Target=`"word/document.xml`"/><Relationship Id=`"rId2`" Type=`"http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties`" Target=`"docProps/core.xml`"/><Relationship Id=`"rId3`" Type=`"$relT/extended-properties`" Target=`"docProps/app.xml`"/></Relationships>"
    $parts['docProps/core.xml'] = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><cp:coreProperties xmlns:cp=`"http://schemas.openxmlformats.org/package/2006/metadata/core-properties`" xmlns:dc=`"http://purl.org/dc/elements/1.1/`" xmlns:dcterms=`"http://purl.org/dc/terms/`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`"><dc:title>$(Xml $Meta.title)</dc:title><dc:creator>$(Xml $Meta.author)</dc:creator><dcterms:created xsi:type=`"dcterms:W3CDTF`">$((Get-Date).ToUniversalTime().ToString('s'))Z</dcterms:created></cp:coreProperties>"
    $parts['docProps/app.xml'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>LazySpec</Application></Properties>'
    $parts['word/styles.xml'] = Get-ThemeStylesXml $T
    $parts['word/settings.xml'] = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:settings $w><w:embedTrueTypeFonts/><w:defaultTabStop w:val=`"709`"/><w:characterSpacingControl w:val=`"doNotCompress`"/><w:compat><w:compatSetting w:name=`"compatibilityMode`" w:uri=`"http://schemas.microsoft.com/office/word`" w:val=`"15`"/></w:compat></w:settings>"
    $parts['word/numbering.xml'] = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:numbering $w></w:numbering>"
    $parts['word/theme/theme1.xml'] = Get-ThemePartXml $T
    & $override '/word/theme/theme1.xml' 'theme+xml'
    $docRels = New-Object Text.StringBuilder
    [void]$docRels.Append("<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><Relationships xmlns=`"http://schemas.openxmlformats.org/package/2006/relationships`"><Relationship Id=`"rId1`" Type=`"$relT/styles`" Target=`"styles.xml`"/><Relationship Id=`"rId2`" Type=`"$relT/settings`" Target=`"settings.xml`"/><Relationship Id=`"rId3`" Type=`"$relT/fontTable`" Target=`"fontTable.xml`"/><Relationship Id=`"rId4`" Type=`"$relT/numbering`" Target=`"numbering.xml`"/><Relationship Id=`"rId5`" Type=`"$relT/theme`" Target=`"theme/theme1.xml`"/>")
    # The fonts: the theme's families, each with its files (regular, bold, italic, bold italic) embedded.
    $ft = New-Object Text.StringBuilder
    $ftRels = New-Object Text.StringBuilder
    [void]$ft.Append("<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:fonts $w>")
    $n = 0
    $embedded = @()
    foreach ($fam in (Get-ThemeFontFamilies $T)) {
        [void]$ft.Append("<w:font w:name=`"$(Xml $fam)`"><w:charset w:val=`"00`"/><w:family w:val=`"auto`"/><w:pitch w:val=`"variable`"/>")
        $slots = [ordered]@{ Regular = $null; Bold = $null; Italic = $null; BoldItalic = $null }
        foreach ($f in (Get-ThemeFontFiles $T $fam)) {
            $bold = if ($f.Family -ieq $fam) { $f.Style -match '(?i)bold' } else { $f.Weight -ge 600 }
            $slot = @('Regular', 'Bold', 'Italic', 'BoldItalic')[([int]$bold) + 2 * [int]$f.Italic]
            if (-not $slots[$slot]) { $slots[$slot] = $f }
        }
        foreach ($slot in $slots.Keys) {
            $f = $slots[$slot]
            if (-not $f) { continue }
            $n++
            $key = [guid]::NewGuid()
            $parts["word/fonts/font$n.odttf"] = [LazySpecFont]::Obfuscate([IO.File]::ReadAllBytes($f.Path), $key)
            [void]$ftRels.Append("<Relationship Id=`"rIdFont$n`" Type=`"$relT/font`" Target=`"fonts/font$n.odttf`"/>")
            [void]$ft.Append("<w:embed$slot r:id=`"rIdFont$n`" w:fontKey=`"{$($key.ToString().ToUpper())}`"/>")
            $embedded += "$fam $slot"
        }
        [void]$ft.Append('</w:font>')
    }
    [void]$ft.Append('</w:fonts>')
    $parts['word/fontTable.xml'] = $ft.ToString()
    if ($ftRels.Length) { $parts['word/_rels/fontTable.xml.rels'] = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><Relationships xmlns=`"http://schemas.openxmlformats.org/package/2006/relationships`">$($ftRels.ToString())</Relationships>" }
    # Header and footer; empty ones for the first page (the cover) unless firstPage.
    $sect = ''
    $titlePg = $false
    $docPr = 1
    foreach ($band in @(@{ B = $T.Header; Kind = 'header'; Tag = 'hdr' }, @{ B = $T.Footer; Kind = 'footer'; Tag = 'ftr' })) {
        $b = $band.B
        if (-not $b.Any) { continue }
        $logoRel = ''
        $rels = ''
        if ($b.Logo -and ($b.Left -eq 'logo' -or $b.Center -eq 'logo' -or $b.Right -eq 'logo')) {
            $ext = [IO.Path]::GetExtension($b.Logo).TrimStart('.').ToLower()
            $parts["word/media/$($band.Kind)-logo.$ext"] = [IO.File]::ReadAllBytes($b.Logo)
            $logoRel = 'rIdLogo'
            $rels = "<Relationship Id=`"rIdLogo`" Type=`"$relT/image`" Target=`"media/$($band.Kind)-logo.$ext`"/>"
        }
        $parts["word/$($band.Kind)1.xml"] = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:$($band.Tag) $w $wp>$(Get-ThemeBandXml $T $b $Meta $logoRel $docPr)</w:$($band.Tag)>"
        $docPr++
        if ($rels) { $parts["word/_rels/$($band.Kind)1.xml.rels"] = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><Relationships xmlns=`"http://schemas.openxmlformats.org/package/2006/relationships`">$rels</Relationships>" }
        & $override "/word/$($band.Kind)1.xml" "wordprocessingml.$($band.Kind)+xml"
        [void]$docRels.Append("<Relationship Id=`"rId$($band.Kind)1`" Type=`"$relT/$($band.Kind)`" Target=`"$($band.Kind)1.xml`"/>")
        $sect += "<w:$($band.Kind)Reference w:type=`"default`" r:id=`"rId$($band.Kind)1`"/>"
        if (-not $b.FirstPage) {
            $parts["word/$($band.Kind)0.xml"] = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:$($band.Tag) $w><w:p/></w:$($band.Tag)>"
            & $override "/word/$($band.Kind)0.xml" "wordprocessingml.$($band.Kind)+xml"
            [void]$docRels.Append("<Relationship Id=`"rId$($band.Kind)0`" Type=`"$relT/$($band.Kind)`" Target=`"$($band.Kind)0.xml`"/>")
            $sect += "<w:$($band.Kind)Reference w:type=`"first`" r:id=`"rId$($band.Kind)0`"/>"
            $titlePg = $true
        }
    }
    # The schema's order: the header references before the footer ones.
    $refs = @([regex]::Matches($sect, '<w:headerReference[^>]*/>') | ForEach-Object { $_.Value }) + @([regex]::Matches($sect, '<w:footerReference[^>]*/>') | ForEach-Object { $_.Value })
    $m = $T.Margins
    $hdrDist = ConvertTo-Twips ([Math]::Min(12.5, $m.top / 2))
    $ftrDist = ConvertTo-Twips ([Math]::Min(12.5, $m.bottom / 2))
    $sectPr = "<w:sectPr>$($refs -join '')<w:pgSz w:w=`"$(ConvertTo-Twips $T.PageW)`" w:h=`"$(ConvertTo-Twips $T.PageH)`"/><w:pgMar w:top=`"$(ConvertTo-Twips $m.top)`" w:right=`"$(ConvertTo-Twips $m.right)`" w:bottom=`"$(ConvertTo-Twips $m.bottom)`" w:left=`"$(ConvertTo-Twips $m.left)`" w:header=`"$hdrDist`" w:footer=`"$ftrDist`" w:gutter=`"0`"/><w:cols w:space=`"709`"/>$(if ($titlePg) { '<w:titlePg/>' })</w:sectPr>"
    $parts['word/document.xml'] = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:document $w $wp><w:body>$sectPr</w:body></w:document>"
    [void]$docRels.Append('</Relationships>')
    $parts['word/_rels/document.xml.rels'] = $docRels.ToString()
    [void]$ct.Append('</Types>')
    $parts['[Content_Types].xml'] = $ct.ToString()
    if ($embedded.Count) { Write-Host "  $($g.caret) fonts embedded in the Word document: $($embedded -join ', ')" }
    # The package, as bytes.
    Add-Type -AssemblyName System.IO.Compression
    $ms = New-Object IO.MemoryStream
    $zip = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($k in $parts.Keys) {
            $v = $parts[$k]
            if ($v -is [string]) { $v = (New-Object Text.UTF8Encoding $false).GetBytes($v) }
            $s = $zip.CreateEntry($k).Open()
            $s.Write($v, 0, $v.Length)
            $s.Dispose()
        }
    } finally { $zip.Dispose() }
    return , $ms.ToArray()
}

# --- Word with the project's template ("lazyspec: documentTemplate:" in config.yaml, or -Template) -------
# The template is the base document: its styles, page setup, section properties, headers and footers (and
# their images) stay; its sample body goes, only its last w:sectPr is kept. The content is written with the
# template's built-in styles: Title and Subtitle (the cover), Heading1..6, Normal, ListParagraph, TableGrid,
# TOCHeading; no fonts of its own except for code. Built here, from the export's HTML: no Word or pandoc
# needed. Word, when it's there, only fills in the contents' page numbers.

function Open-ZipBytes([byte[]]$Bytes, [string]$Mode) {
    Add-Type -AssemblyName System.IO.Compression
    $ms = New-Object IO.MemoryStream
    $ms.Write($Bytes, 0, $Bytes.Length)
    $ms.Position = 0
    return [pscustomobject]@{ Stream = $ms; Zip = (New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::$Mode, $true)) }
}
# A file's bytes even while Word has it open (it lets others read).
function Read-SharedBytes([string]$Path) {
    $fs = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try { $ms = New-Object IO.MemoryStream; $fs.CopyTo($ms); return , $ms.ToArray() } finally { $fs.Dispose() }
}
function Read-ZipText($Zip, [string]$Name) {
    $e = $Zip.GetEntry($Name)
    if (-not $e) { return $null }
    $r = New-Object IO.StreamReader($e.Open(), [Text.Encoding]::UTF8)
    try { return $r.ReadToEnd() } finally { $r.Dispose() }
}
function Write-ZipBytes($Zip, [string]$Name, [byte[]]$Bytes) {
    $e = $Zip.GetEntry($Name)
    if ($e) { $e.Delete() }
    $s = $Zip.CreateEntry($Name).Open()
    try { $s.Write($Bytes, 0, $Bytes.Length) } finally { $s.Dispose() }
}
function Write-ZipText($Zip, [string]$Name, [string]$Text) { Write-ZipBytes $Zip $Name ((New-Object Text.UTF8Encoding $false).GetBytes($Text)) }

# The template's path, checked: -Template (relative to the current folder), else documentTemplate (relative to
# the project's root); '' when neither is set. Set but missing or broken: an error, never the default look.
function Get-DocumentTemplate {
    $raw = ''
    $base = $Root
    $from = 'lazyspec: documentTemplate: in openspec/config.yaml'
    if ($Template) { $raw = $Template; $base = (Get-Location).ProviderPath; $from = '-Template' }
    elseif ($hasRoot) { $raw = [string](Get-ProjectConfig).Values['documentTemplate'] }
    $raw = $raw.Trim().Trim('"', "'")
    if (-not $raw) { return '' }
    $path = ($raw -replace '[\\/]', [IO.Path]::DirectorySeparatorChar)
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $base $path }
    $path = [IO.Path]::GetFullPath($path)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "The Word template isn't there: $path ($from). Client documents need the company layout: fix the path (or remove the setting)." }
    $pkg = $null
    try { $pkg = Open-ZipBytes (Read-SharedBytes $path) 'Read' } catch { throw "The Word template isn't a valid .docx (not a Word package): $path ($from)." }
    try {
        $docXml = Read-ZipText $pkg.Zip 'word/document.xml'
        if (-not $docXml -or $docXml -notmatch '<w:body[ >]') { throw "The Word template isn't a valid .docx (no word/document.xml with a body): $path ($from)." }
        try { [void]([xml]$docXml) } catch { throw "The Word template isn't a valid .docx (its word/document.xml is broken): $path ($from)." }
    }
    finally { $pkg.Zip.Dispose(); $pkg.Stream.Dispose() }
    return $path
}

# The fonts the template sets (styles, theme, headers, footers) that this PC doesn't have: Word and PDF
# printers put others in their place.
function Get-MissingTemplateFonts([string]$Path) {
    $pkg = Open-ZipBytes (Read-SharedBytes $Path) 'Read'
    $fonts = @{}
    try {
        foreach ($e in @($pkg.Zip.Entries)) {
            if ($e.FullName -notmatch '^word/(styles|fontTable|header\d*|footer\d*|theme/theme\d*)\.xml$') { continue }
            $t = Read-ZipText $pkg.Zip $e.FullName
            foreach ($m in [regex]::Matches($t, 'w:(?:ascii|hAnsi)="([^"]+)"')) { $fonts[$m.Groups[1].Value] = $true }
            # The fonts the template declares (fontTable): its author's, even where no style uses them yet.
            foreach ($m in [regex]::Matches($t, '<w:font w:name="([^"]+)"')) { $fonts[$m.Groups[1].Value] = $true }
            foreach ($m in [regex]::Matches($t, '<a:(?:latin) typeface="([^"]+)"')) { $fonts[$m.Groups[1].Value] = $true }
        }
    }
    finally { $pkg.Zip.Dispose(); $pkg.Stream.Dispose() }
    # The installed ones (the machine's and the user's) by their family names.
    $installed = Get-InstalledFontFamilies
    $missing = @()
    foreach ($name in ($fonts.Keys | Sort-Object)) {
        if (-not $name -or $name.StartsWith('+')) { continue }
        $n = $name.ToLower()
        if ($installed.ContainsKey($n)) { continue }
        $missing += $name
    }
    return , $missing
}
function Write-TemplateFontWarning([string]$Path) {
    $missing = @()
    try { $missing = Get-MissingTemplateFonts $Path } catch { Write-Host "  ! the template's fonts not checked: $($_.Exception.Message)"; return }
    if ($missing.Count) { Write-Host "  ! fonts of the Word template not installed on this PC: $($missing -join ', ') (Word and PDF use others in their place)" }
}

function Xml([string]$T) { return [Security.SecurityElement]::Escape($T) }
$script:wordCode = @{ Font = 'Consolas'; Size = 18 }
# A scenario's text in Word (half-points; 0: the style's): with a theme, 1pt under its body's.
$script:wordScenarioSize = 0
# The specification: a chapter (heading 1) a page, the contents of headings 1; a Markdown document: neither, headings 1-2.
$script:wordMode = @{ ChapterBreaks = $true; TocLevels = 1; TocBreak = $true }

# The converter's state, for one document.
function New-WordContext($Styles, [long]$WidthTwips, [int]$NumBase) {
    return @{
        Styles = $Styles; Width = $WidthTwips; NumBase = $NumBase; Rels = (New-Object Collections.ArrayList); Media = (New-Object Collections.ArrayList)
        RelIds = @{}; Bookmarks = @{}; BookmarkId = 0; DocPr = 1000; Nums = (New-Object Collections.ArrayList); Toc = (New-Object Collections.ArrayList)
    }
}
# A built-in style's ID in the template (found by its name: localized templates have other IDs); '' when it has none.
function Get-TemplateStyles([string]$StylesXml) {
    $byName = @{}
    $ids = @{}
    foreach ($m in [regex]::Matches($StylesXml, '<w:style\b[^>]*w:styleId="([^"]+)"[^>]*>\s*<w:name w:val="([^"]+)"')) {
        $byName[$m.Groups[2].Value.ToLower()] = $m.Groups[1].Value
        $ids[$m.Groups[1].Value] = $true
    }
    $want = [ordered]@{ Title = 'title'; Subtitle = 'subtitle'; Normal = 'normal'; ListParagraph = 'list paragraph'; TableGrid = 'table grid'; TOCHeading = 'toc heading'; TOC1 = 'toc 1'; TOC2 = 'toc 2'; Hyperlink = 'hyperlink' }
    for ($i = 1; $i -le 6; $i++) { $want["Heading$i"] = "heading $i" }
    $styles = @{}
    foreach ($k in $want.Keys) {
        $styles[$k] = ''
        if ($byName.ContainsKey($want[$k])) { $styles[$k] = $byName[$want[$k]] } elseif ($ids.ContainsKey($k)) { $styles[$k] = $k }
    }
    return $styles
}
function Get-BookmarkName($Ctx, [string]$Id) {
    if (-not $Ctx.Bookmarks.ContainsKey($Id)) {
        $n = 'ls_' + ($Id -replace '[^A-Za-z0-9_]', '_')
        if ($n.Length -gt 34) { $n = $n.Substring(0, 34) }
        $n = "$n$($Ctx.Bookmarks.Count)"
        $Ctx.Bookmarks[$Id] = $n
    }
    return $Ctx.Bookmarks[$Id]
}
function Add-WordRel($Ctx, [string]$Type, [string]$Target, [bool]$External) {
    $key = "$Type|$Target"
    if ($Ctx.RelIds.ContainsKey($key)) { return $Ctx.RelIds[$key] }
    $id = "rIdLs$($Ctx.Rels.Count + 1)"
    [void]$Ctx.Rels.Add([pscustomobject]@{ Id = $id; Type = $Type; Target = $Target; External = $External })
    $Ctx.RelIds[$key] = $id
    return $id
}

# --- inline content: runs ---
function New-RunFormat { return @{ B = $false; I = $false; Code = $false; Link = ''; Size = 0 } }
function Copy-RunFormat($F) { return @{ B = $F.B; I = $F.I; Code = $F.Code; Link = $F.Link; Size = $F.Size } }
# The runs of an element's inline content, as a list of { T (text) | Br | Xml (a drawing) , Format }.
function Add-InlineRuns($Ctx, $Node, $Fmt, $Runs) {
    foreach ($c in $Node.ChildNodes) {
        if ($c.NodeType -eq 'Text' -or $c.NodeType -eq 'SignificantWhitespace' -or $c.NodeType -eq 'Whitespace') { [void]$Runs.Add(@{ T = $c.Value; F = $Fmt }); continue }
        if ($c.NodeType -ne 'Element') { continue }
        $tag = $c.LocalName.ToLower()
        $f = Copy-RunFormat $Fmt
        switch ($tag) {
            { $_ -in 'strong', 'b', 'th' } { $f.B = $true; Add-InlineRuns $Ctx $c $f $Runs }
            { $_ -in 'em', 'i' } { $f.I = $true; Add-InlineRuns $Ctx $c $f $Runs }
            'code' { $f.Code = $true; Add-InlineRuns $Ctx $c $f $Runs }
            'br' { [void]$Runs.Add(@{ Br = $true; F = $Fmt }) }
            'img' { $x = Get-WordImage $Ctx $c; if ($x) { [void]$Runs.Add(@{ Xml = $x; F = $Fmt }) } }
            'a' {
                $href = $c.GetAttribute('href')
                if ($href) { $f.Link = $href }
                if ($c.GetAttribute('name') -and -not $c.HasChildNodes) { continue }
                Add-InlineRuns $Ctx $c $f $Runs
            }
            'span' {
                # A requirement's or scenario's label ("Requirement"): before its title, with a colon.
                if ($c.GetAttribute('class') -eq 'tag') { $f.B = $true; [void]$Runs.Add(@{ T = "$($c.InnerText.Trim()): "; F = $f }); continue }
                Add-InlineRuns $Ctx $c $f $Runs
            }
            default { Add-InlineRuns $Ctx $c $f $Runs }
        }
    }
}
# Runs as WordprocessingML: white space as HTML shows it (not in code blocks), links as hyperlinks.
function Format-Runs($Ctx, $Runs, [bool]$Pre) {
    $sb = New-Object Text.StringBuilder
    $space = $true
    $items = New-Object Collections.ArrayList
    foreach ($r in $Runs) {
        if ($r.Br -or $r.Xml) { [void]$items.Add($r); $space = $true; continue }
        $t = [string]$r.T
        if (-not $Pre) {
            $t = [regex]::Replace($t, '\s+', ' ')
            if ($space -and $t.StartsWith(' ')) { $t = $t.Substring(1) }
            if (-not $t) { continue }
            $space = $t.EndsWith(' ')
        }
        [void]$items.Add(@{ T = $t; F = $r.F })
    }
    # No space at the paragraph's end.
    for ($i = $items.Count - 1; $i -ge 0; $i--) {
        if ($items[$i].Br -or $items[$i].Xml) { break }
        $items[$i].T = $items[$i].T.TrimEnd()
        if ($items[$i].T) { break }
    }
    $link = ''
    foreach ($r in $items) {
        $l = ''
        if (-not $r.Br -and -not $r.Xml) { $l = $r.F.Link }
        if ($l -ne $link) {
            if ($link) { [void]$sb.Append('</w:hyperlink>') }
            $link = $l
            if ($link) {
                if ($link.StartsWith('#')) { [void]$sb.Append("<w:hyperlink w:anchor=`"$(Get-BookmarkName $Ctx $link.Substring(1))`" w:history=`"1`">") }
                else { [void]$sb.Append("<w:hyperlink r:id=`"$(Add-WordRel $Ctx 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink' $link $true)`" w:history=`"1`">") }
            }
        }
        if ($r.Xml) { [void]$sb.Append($r.Xml); continue }
        if ($r.Br) { [void]$sb.Append('<w:r><w:br/></w:r>'); continue }
        if (-not $r.T) { continue }
        $rpr = ''
        if ($r.F.Link -and $Ctx.Styles.Hyperlink) { $rpr += "<w:rStyle w:val=`"$($Ctx.Styles.Hyperlink)`"/>" }
        # Code: the only font LazySpec sets (monospace, the theme's code font); the template's fonts everywhere else.
        $cf = Xml $script:wordCode.Font
        if ($r.F.Code) { $rpr += "<w:rFonts w:ascii=`"$cf`" w:hAnsi=`"$cf`" w:cs=`"$cf`"/>" }
        if ($r.F.B) { $rpr += '<w:b/><w:bCs/>' }
        if ($r.F.I) { $rpr += '<w:i/><w:iCs/>' }
        if ($r.F.Code -and $r.F.Size -ge 0) { $sz = $script:wordCode.Size; if ($r.F.Size) { $sz = $r.F.Size }; $rpr += "<w:sz w:val=`"$sz`"/><w:szCs w:val=`"$sz`"/>" }
        elseif (-not $r.F.Code -and $r.F.Size -ge 0 -and $Ctx.TextSize) { $rpr += "<w:sz w:val=`"$($Ctx.TextSize)`"/><w:szCs w:val=`"$($Ctx.TextSize)`"/>" }
        if ($rpr) { $rpr = "<w:rPr>$rpr</w:rPr>" }
        $lines = $r.T.Split("`n")
        for ($k = 0; $k -lt $lines.Count; $k++) {
            if ($k) { [void]$sb.Append("<w:r>$rpr<w:br/></w:r>") }
            if ($lines[$k]) { [void]$sb.Append("<w:r>$rpr<w:t xml:space=`"preserve`">$(Xml $lines[$k])</w:t></w:r>") }
        }
    }
    if ($link) { [void]$sb.Append('</w:hyperlink>') }
    return $sb.ToString()
}
# A paragraph: its properties in the schema's order.
function Add-WordPara($Ctx, $Sb, [string]$Style, [string]$Runs, $Opt) {
    if (-not $Opt) { $Opt = @{} }
    $ppr = ''
    $sid = ''
    if ($Style) { $sid = $Ctx.Styles[$Style] }
    if ($sid) { $ppr += "<w:pStyle w:val=`"$sid`"/>" }
    if ($Opt.KeepNext) { $ppr += '<w:keepNext/>' }
    if ($Opt.PageBreak) { $ppr += '<w:pageBreakBefore/>' }
    if ($Opt.NumId) { $ppr += "<w:numPr><w:ilvl w:val=`"$($Opt.Level)`"/><w:numId w:val=`"$($Opt.NumId)`"/></w:numPr>" }
    if ($Opt.Border) { $ppr += '<w:pBdr><w:bottom w:val="single" w:sz="4" w:space="1" w:color="auto"/></w:pBdr>' }
    if ($Opt.Before -or $Opt.After) {
        $sp = ''
        if ($Opt.Before) { $sp += " w:before=`"$($Opt.Before)`"" }
        if ($Opt.After) { $sp += " w:after=`"$($Opt.After)`"" }
        $ppr += "<w:spacing$sp/>"
    }
    if ($Opt.Indent) { $ppr += "<w:ind w:left=`"$($Opt.Indent)`"/>" }
    if ($Opt.Center) { $ppr += '<w:jc w:val="center"/>' }
    if ($ppr) { $ppr = "<w:pPr>$ppr</w:pPr>" }
    $bm = ''; $bmEnd = ''
    if ($Opt.Bookmark) {
        $Ctx.BookmarkId++
        $bm = "<w:bookmarkStart w:id=`"$($Ctx.BookmarkId)`" w:name=`"$(Get-BookmarkName $Ctx $Opt.Bookmark)`"/>"
        $bmEnd = "<w:bookmarkEnd w:id=`"$($Ctx.BookmarkId)`"/>"
    }
    [void]$Sb.Append("<w:p>$ppr$bm$Runs$bmEnd</w:p>")
}
function Get-InlineXml($Ctx, $Node, [bool]$Pre = $false, [bool]$Heading = $false) {
    $runs = New-Object Collections.ArrayList
    $f = New-RunFormat
    # In a heading, code keeps the heading's size (only the font is code's).
    if ($Heading) { $f.Size = -1 }
    if ($Pre) {
        $f.Code = $true
        # A code block's own size (a diagram's long lines: smaller), in half-points.
        $m = [regex]::Match($Node.GetAttribute('style'), 'font-size:\s*([\d.]+)pt')
        if ($m.Success) { $f.Size = [int][Math]::Round([double]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) * 2) }
    }
    Add-InlineRuns $Ctx $Node $f $runs
    return Format-Runs $Ctx $runs $Pre
}

# A picture (a diagram): into the package, at most the text's width (and a page's height).
function Get-WordImage($Ctx, $Img) {
    $src = $Img.GetAttribute('src')
    $bytes = $null
    $ext = 'png'
    try {
        if ($src -match '^data:image/([a-z+]+);base64,(.*)$') { $ext = $Matches[1]; $bytes = [Convert]::FromBase64String($Matches[2]) }
        elseif ($src) { $p = $src; if ($src -match '^file:') { $p = ([Uri]$src).LocalPath }; $bytes = [IO.File]::ReadAllBytes($p); $ext = [IO.Path]::GetExtension($p).TrimStart('.').ToLower() }
    } catch { Write-Host "  ! a picture not added: $($_.Exception.Message)"; return '' }
    if (-not $bytes) { return '' }
    if ($ext -eq 'jpg') { $ext = 'jpeg' }
    if ($ext -notin 'png', 'jpeg', 'gif', 'bmp') { Write-Host "  ! a $ext picture not added (Word takes png, jpeg, gif, bmp)"; return '' }
    $w = 0; $h = 0
    try {
        Initialize-ImageTool
        $size = [LazySpecImage]::SizeOf($bytes)
        $w = $size[0]; $h = $size[1]
    } catch { }
    if (-not $w) { $w = [int]$Img.GetAttribute('width'); $h = [int]$Img.GetAttribute('height') }
    if (-not $w -or -not $h) { $w = 600; $h = 400 }
    # 96 dpi; the text's width; at most 22 cm high. A height in mm (the cover's logo): that height.
    $cx = [long]$w * 9525; $cy = [long]$h * 9525
    $mm = $Img.GetAttribute('data-height-mm')
    if ($mm) { $cy = [long]([double]::Parse($mm, [Globalization.CultureInfo]::InvariantCulture) * 36000); $cx = [long]($cy * $w / $h) }
    $maxX = $Ctx.Width * 635; $maxY = [long](22 * 360000)
    $k = [Math]::Min(1.0, [Math]::Min($maxX / $cx, $maxY / $cy))
    $cx = [long]($cx * $k); $cy = [long]($cy * $k)
    $n = $Ctx.Media.Count + 1
    $name = "lazyspec-image$n.$ext"
    [void]$Ctx.Media.Add([pscustomobject]@{ Name = $name; Bytes = $bytes; Ext = $ext })
    $rid = Add-WordRel $Ctx 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image' "media/$name" $false
    $Ctx.DocPr++
    $id = $Ctx.DocPr
    $alt = Xml $Img.GetAttribute('alt')
    return "<w:r><w:drawing><wp:inline distT=`"0`" distB=`"0`" distL=`"0`" distR=`"0`"><wp:extent cx=`"$cx`" cy=`"$cy`"/><wp:docPr id=`"$id`" name=`"Picture $id`" descr=`"$alt`"/>" +
        '<wp:cNvGraphicFramePr><a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/></wp:cNvGraphicFramePr>' +
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">' +
        "<pic:pic xmlns:pic=`"http://schemas.openxmlformats.org/drawingml/2006/picture`"><pic:nvPicPr><pic:cNvPr id=`"$id`" name=`"$name`"/><pic:cNvPicPr/></pic:nvPicPr>" +
        "<pic:blipFill><a:blip r:embed=`"$rid`"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>" +
        "<pic:spPr><a:xfrm><a:off x=`"0`" y=`"0`"/><a:ext cx=`"$cx`" cy=`"$cy`"/></a:xfrm><a:prstGeom prst=`"rect`"><a:avLst/></a:prstGeom></pic:spPr></pic:pic>" +
        '</a:graphicData></a:graphic></wp:inline></w:drawing></w:r>'
}

# A list (ul / ol): a numbering of its own (so ordered lists start at 1), its level by how deep it is.
function New-WordList($Ctx, [string]$Kind) {
    [void]$Ctx.Nums.Add($Kind)
    return $Ctx.NumBase + $Ctx.Nums.Count
}
function Add-WordList($Ctx, $Sb, $List, [int]$Level) {
    $kind = 'bullet'
    if ($List.LocalName -eq 'ol') { $kind = 'decimal'; if ($List.GetAttribute('type') -eq 'a') { $kind = 'letter' } }
    $num = New-WordList $Ctx $kind
    foreach ($li in $List.ChildNodes) {
        if ($li.NodeType -ne 'Element' -or $li.LocalName -ne 'li') { continue }
        # A scenario's steps (WHEN / THEN ...) and task lists: no bullet, their own marks.
        $plain = $li.GetAttribute('class') -match '\bstep\b'
        $first = @{ NumId = $num; Level = [Math]::Min(8, $Level) }
        if ($plain) { $first = $null }
        Add-WordBlocks $Ctx $Sb $li $Level 'ListParagraph' $first (360 * ($Level + 1) + 360)
    }
}
# A table: TableGrid, the text's width, the header row repeated on every page.
function Add-WordTable($Ctx, $Sb, $Table) {
    $rows = @($Table.SelectNodes('.//tr'))
    if (-not $rows.Count) { return }
    $cols = 0
    foreach ($r in $rows) { $n = @($r.ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.LocalName -in 'td', 'th' }).Count; if ($n -gt $cols) { $cols = $n } }
    if (-not $cols) { return }
    $cw = [long][Math]::Floor($Ctx.Width / $cols)
    # Its columns' widths: the HTML's (<col style="width: N%">, Get-TableWidths), else equal.
    $pcts = @($Table.SelectNodes('.//col') | ForEach-Object { $m = [regex]::Match($_.GetAttribute('style'), 'width:\s*([\d.]+)%'); if ($m.Success) { [double]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) } })
    $widths = @(for ($i = 0; $i -lt $cols; $i++) { if ($pcts.Count -eq $cols) { [long][Math]::Floor($Ctx.Width * $pcts[$i] / 100) } else { $cw } })
    $tblStyle = ''
    if ($Ctx.Styles.TableGrid) { $tblStyle = "<w:tblStyle w:val=`"$($Ctx.Styles.TableGrid)`"/>" }
    # The style's header row (bold, shaded) only on a table that has one.
    $hasHead = [bool]$Table.SelectSingleNode('.//thead') -or [bool](@($rows[0].ChildNodes | Where-Object { $_.NodeType -eq 'Element' }).Count -and -not @($rows[0].ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.LocalName -ne 'th' }).Count)
    $look = if ($hasHead) { 'w:val="04A0" w:firstRow="1"' } else { 'w:val="0080" w:firstRow="0"' }
    [void]$Sb.Append("<w:tbl><w:tblPr>$tblStyle<w:tblW w:w=`"5000`" w:type=`"pct`"/><w:tblLook $look w:lastRow=`"0`" w:firstColumn=`"0`" w:lastColumn=`"0`" w:noHBand=`"0`" w:noVBand=`"1`"/></w:tblPr><w:tblGrid>")
    for ($i = 0; $i -lt $cols; $i++) { [void]$Sb.Append("<w:gridCol w:w=`"$($widths[$i])`"/>") }
    [void]$Sb.Append('</w:tblGrid>')
    foreach ($r in $rows) {
        $cells = @($r.ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.LocalName -in 'td', 'th' })
        $head = ($r.ParentNode.LocalName -eq 'thead') -or (@($cells | Where-Object { $_.LocalName -eq 'th' }).Count -eq $cells.Count -and $cells.Count)
        [void]$Sb.Append('<w:tr>')
        if ($head) { [void]$Sb.Append('<w:trPr><w:tblHeader/></w:trPr>') }
        for ($i = 0; $i -lt $cols; $i++) {
            # A cell's background (a changed row of models.md): its shading.
            $shd = ''
            if ($i -lt $cells.Count) {
                $bg = [regex]::Match($cells[$i].GetAttribute('style'), 'background:\s*#([0-9A-Fa-f]{6})')
                if ($bg.Success) { $shd = "<w:shd w:val=`"clear`" w:color=`"auto`" w:fill=`"$($bg.Groups[1].Value.ToUpper())`"/>" }
            }
            [void]$Sb.Append("<w:tc><w:tcPr><w:tcW w:w=`"$($widths[$i])`" w:type=`"dxa`"/>$shd</w:tcPr>")
            $cell = New-Object Text.StringBuilder
            if ($i -lt $cells.Count) {
                $content = $cells[$i]
                # A header cell's text bold (as the browser shows it).
                if ($content.LocalName -eq 'th') {
                    $content = $Ctx.Doc.CreateElement('td')
                    $strong = $Ctx.Doc.CreateElement('strong')
                    foreach ($n in @($cells[$i].ChildNodes)) { [void]$strong.AppendChild($n.CloneNode($true)) }
                    [void]$content.AppendChild($strong)
                }
                Add-WordBlocks $Ctx $cell $content 0 'Normal' $null 0
            }
            # Every cell holds a paragraph at least.
            if (-not $cell.Length) { [void]$cell.Append('<w:p/>') }
            # Its paragraphs tight, as a table's (Normal's paragraph spacing would win over the table style's):
            # a spacing in each paragraph's properties, in the schema's place (before ind / jc).
            $tight = '<w:spacing w:before="20" w:after="20" w:line="240" w:lineRule="auto"/>'
            $cx = [regex]::Replace($cell.ToString(), '<w:p><w:pPr>((?:(?!</w:pPr>).)*?)(<w:ind\b|<w:jc\b|</w:pPr>)', {
                    param($m) if ($m.Groups[1].Value -match '<w:spacing\b') { $m.Value } else { "<w:p><w:pPr>$($m.Groups[1].Value)$tight$($m.Groups[2].Value)" } })
            $cx = $cx.Replace('<w:p/>', "<w:p><w:pPr>$tight</w:pPr></w:p>").Replace('<w:p><w:r>', "<w:p><w:pPr>$tight</w:pPr><w:r>")
            [void]$Sb.Append($cx)
            [void]$Sb.Append('</w:tc>')
        }
        [void]$Sb.Append('</w:tr>')
    }
    [void]$Sb.Append('</w:tbl>')
}
# The contents: the template's TOCHeading, then a TOC field over Heading 1 (filled in here, without page
# numbers; Word adds them when it's there, F9 in Word otherwise).
function Add-WordToc($Ctx, $Sb) {
    $p = ''
    if ($Ctx.Styles.TOC1) { $p = "<w:pPr><w:pStyle w:val=`"$($Ctx.Styles.TOC1)`"/></w:pPr>" }
    [void]$Sb.Append("<w:p>$p<w:r><w:fldChar w:fldCharType=`"begin`"/></w:r><w:r><w:instrText xml:space=`"preserve`"> TOC \o `"1-$($script:wordMode.TocLevels)`" \h \z \u </w:instrText></w:r><w:r><w:fldChar w:fldCharType=`"separate`"/></w:r></w:p>")
    foreach ($e in $Ctx.Toc) {
        # An entry in its level's style (toc 1, toc 2).
        $ep = $p
        $sid = $Ctx.Styles["TOC$($e.Level)"]
        if ($sid) { $ep = "<w:pPr><w:pStyle w:val=`"$sid`"/></w:pPr>" }
        [void]$Sb.Append("<w:p>$ep<w:hyperlink w:anchor=`"$(Get-BookmarkName $Ctx $e.Id)`" w:history=`"1`"><w:r><w:t xml:space=`"preserve`">$(Xml $e.Text)</w:t></w:r></w:hyperlink></w:p>")
    }
    [void]$Sb.Append("<w:p>$p<w:r><w:fldChar w:fldCharType=`"end`"/></w:r></w:p>")
}

# An element's content as blocks: inline content (text, links ...) gathers into paragraphs of $Style;
# headings, lists, tables, code, pictures make their own. $First: the first paragraph's numbering (a list
# item's), $Indent: every other paragraph's left indent (a list item's text, a scenario).
function Add-WordBlocks($Ctx, $Sb, $Node, [int]$Level, [string]$Style, $First, [int]$Indent) {
    $state = @{ First = $First }
    # The next paragraph's properties: the number once, else the indent.
    $nextOpt = {
        $o = @{}
        if ($state.First) { $o = @{ NumId = $state.First.NumId; Level = $state.First.Level } }
        elseif ($Indent) { $o = @{ Indent = $Indent } }
        $state.First = $null
        return $o
    }
    $pending = New-Object Collections.ArrayList
    $flush = {
        if (-not $pending.Count) { return }
        $runs = New-Object Collections.ArrayList
        foreach ($n in $pending) {
            if ($n.NodeType -eq 'Element') {
                $wrap = $Ctx.Doc.CreateElement('span')
                [void]$wrap.AppendChild($n.CloneNode($true))
                Add-InlineRuns $Ctx $wrap (New-RunFormat) $runs
            }
            else { [void]$runs.Add(@{ T = $n.Value; F = (New-RunFormat) }) }
        }
        $pending.Clear()
        $xml = Format-Runs $Ctx $runs $false
        if (-not $xml) { return }
        Add-WordPara $Ctx $Sb $Style $xml (& $nextOpt)
    }
    $blockTags = 'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'table', 'pre', 'blockquote', 'hr'
    $inList = $Style -eq 'ListParagraph'
    foreach ($c in @($Node.ChildNodes)) {
        if ($c.NodeType -ne 'Element' -or $c.LocalName -notin $blockTags) { [void]$pending.Add($c); continue }
        & $flush
        $tag = $c.LocalName
        $cls = $c.GetAttribute('class')
        switch -Regex ($tag) {
            '^h([1-6])$' {
                $lv = [int]$Matches[1]
                $id = $c.GetAttribute('id')
                $opt = @{ KeepNext = $true }
                # A chapter: a page of its own (the specification), in the contents (a part's title too).
                if ($lv -eq 1 -and $script:wordMode.ChapterBreaks) { $opt.PageBreak = $true }
                if ($lv -le $script:wordMode.TocLevels) {
                    if (-not $id) { $id = "part$($Ctx.Toc.Count)" }
                    [void]$Ctx.Toc.Add([pscustomobject]@{ Id = $id; Text = [regex]::Replace($c.InnerText.Trim(), '\s+', ' '); Level = $lv })
                }
                if ($id) { $opt.Bookmark = $id }
                Add-WordPara $Ctx $Sb "Heading$lv" (Get-InlineXml $Ctx $c $false $true) $opt
                $state.First = $null
            }
            '^(ul|ol)$' { $lv = 0; if ($inList) { $lv = $Level + 1 }; $state.First = $null; Add-WordList $Ctx $Sb $c $lv }
            '^table$' { $state.First = $null; Add-WordTable $Ctx $Sb $c }
            '^pre$' { Add-WordPara $Ctx $Sb 'Normal' (Get-InlineXml $Ctx $c $true) (& $nextOpt) }
            '^hr$' { Add-WordPara $Ctx $Sb 'Normal' '' @{ Border = $true } }
            '^blockquote$' { Add-WordBlocks $Ctx $Sb $c $Level 'Normal' $null ($Indent + 567) }
            '^p$' {
                # The contents' place: filled in when the chapters are known.
                if ($c.InnerText.Trim() -eq '[[TOC]]') { [void]$Sb.Append('<!--lazyspec-toc-->'); break }
                switch ($cls) {
                    'title' { Add-WordPara $Ctx $Sb 'Title' (Get-InlineXml $Ctx $c) @{} }
                    'subtitle' { Add-WordPara $Ctx $Sb 'Subtitle' (Get-InlineXml $Ctx $c) @{} }
                    'toc-title' { Add-WordPara $Ctx $Sb 'TOCHeading' (Get-InlineXml $Ctx $c) @{ PageBreak = $script:wordMode.TocBreak } }
                    'page-break' { Add-WordPara $Ctx $Sb 'Normal' '' @{ PageBreak = $true } }
                    'caption' { Add-WordPara $Ctx $Sb 'Normal' (Get-InlineXml $Ctx $c) @{ Center = $true } }
                    default { Add-WordPara $Ctx $Sb $Style (Get-InlineXml $Ctx $c) (& $nextOpt) }
                }
            }
            default {
                # A div: the cover, a scenario (indented), a diagram (its picture centred), what's inside.
                if ($cls -eq 'bar') { break }
                if ($cls -eq 'cover-logo') {
                    foreach ($img in @($c.SelectNodes('.//img'))) { $x = Get-WordImage $Ctx $img; if ($x) { Add-WordPara $Ctx $Sb 'Normal' $x @{ After = 600 } } }
                    break
                }
                if ($cls -eq 'diagram') {
                    # Room above it and below its caption, as in PDF (16pt, 20pt).
                    foreach ($img in @($c.SelectNodes('.//img'))) { $x = Get-WordImage $Ctx $img; if ($x) { Add-WordPara $Ctx $Sb 'Normal' $x @{ Center = $true; KeepNext = $true; Before = 320 } } }
                    foreach ($cap in @($c.SelectNodes('./p'))) { Add-WordPara $Ctx $Sb 'Normal' (Get-InlineXml $Ctx $cap) @{ Center = $true; After = 400 } }
                    break
                }
                $in = $Indent
                $size = $Ctx.TextSize
                if ($cls -eq 'scenario') { $in += 284; if ($script:wordScenarioSize) { $Ctx.TextSize = $script:wordScenarioSize } }
                Add-WordBlocks $Ctx $Sb $c $Level $Style $state.First $in
                $Ctx.TextSize = $size
                $state.First = $null
            }
        }
    }
    & $flush
}

# The export's HTML -> a .docx on the template.
function Export-WordTemplate([string]$Html, [string]$Target, [string]$TemplatePath) {
    Write-Host "  $($g.caret) Word template: $TemplatePath"
    Export-WordOnBase $Html $Target (Read-SharedBytes $TemplatePath) $TemplatePath
}
# The export's HTML -> a .docx on the theme's base document.
function Export-WordTheme([string]$Html, [string]$Target, $T, $Meta) {
    $script:wordCode = @{ Font = $T.Styles.code.font; Size = [int][Math]::Round((ConvertTo-Pt $T.Styles.code.size 'size') * 2) }
    $script:wordScenarioSize = [int][Math]::Round((Get-ScenarioPt $T) * 2)
    Export-WordOnBase $Html $Target (New-ThemeDocxBase $T $Meta) $T.Path
}
# The export's HTML -> a .docx on a base document (the template's, or the theme's).
function Export-WordOnBase([string]$Html, [string]$Target, [byte[]]$Base, [string]$Source) {
    $pkg = Open-ZipBytes $Base 'Update'
    try {
        $zip = $pkg.Zip
        $docXml = Read-ZipText $zip 'word/document.xml'
        # The body goes, its last section's properties stay (headers, footers, margins, the cover's own first page).
        $bodyStart = [regex]::Match($docXml, '<w:body>')
        $sect = [regex]::Match($docXml, '(?s)<w:sectPr\b(?:(?!<w:sectPr\b).)*?</w:sectPr>\s*</w:body>')
        if (-not $bodyStart.Success) { throw "The Word template has no <w:body>: $Source" }
        $sectPr = ''
        if ($sect.Success) { $sectPr = [regex]::Replace($sect.Value, '\s*</w:body>$', '') }
        $oldBody = $docXml.Substring($bodyStart.Index, $docXml.IndexOf('</w:body>') - $bodyStart.Index)
        $head = $docXml.Substring(0, $bodyStart.Index)
        # The namespaces the content needs, on the root as Word writes them.
        $nsNeeded = @{
            w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'; r = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
            wp = 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
        }
        foreach ($k in $nsNeeded.Keys) { if ($head -notmatch "xmlns:$k=") { $head = [regex]::Replace($head, '<w:document\b', "<w:document xmlns:$k=`"$($nsNeeded[$k])`"", 1) } }
        # The text's width: the page's, less the margins (twips).
        $width = 9026
        $pg = [regex]::Match($sectPr, '<w:pgSz\b[^>]*w:w="(\d+)"'); $ml = [regex]::Match($sectPr, '<w:pgMar\b[^>]*w:left="(\d+)"'); $mr = [regex]::Match($sectPr, '<w:pgMar\b[^>]*w:right="(\d+)"')
        if ($pg.Success -and $ml.Success -and $mr.Success) { $width = [long]$pg.Groups[1].Value - [long]$ml.Groups[1].Value - [long]$mr.Groups[1].Value }

        $numXml = Read-ZipText $zip 'word/numbering.xml'
        $numMax = 0
        if ($numXml) { foreach ($m in [regex]::Matches($numXml, '<w:num w:numId="(\d+)"')) { $numMax = [Math]::Max($numMax, [int]$m.Groups[1].Value) } }
        $ctx = New-WordContext (Get-TemplateStyles (Read-ZipText $zip 'word/styles.xml')) $width $numMax
        # The export's HTML as XML (it writes well-formed HTML; the void tags closed, the named entities as numbers).
        $body = [regex]::Match($Html, '(?s)<body>(.*)</body>').Groups[1].Value
        $body = [regex]::Replace($body, '<(br|hr|img|meta|col|input)\b([^>]*?)/?>', '<$1$2/>')
        $body = $body.Replace('&nbsp;', '&#160;')
        $x = New-Object Xml.XmlDocument
        $x.PreserveWhitespace = $true
        $x.LoadXml("<body>$body</body>")
        $ctx.Doc = $x
        $sb = New-Object Text.StringBuilder
        Add-WordBlocks $ctx $sb $x.DocumentElement 0 'Normal' $null 0
        # The contents, now that the chapters are known.
        $toc = New-Object Text.StringBuilder
        if ($ctx.Toc.Count) { Add-WordToc $ctx $toc }
        $content = $sb.ToString().Replace('<!--lazyspec-toc-->', $toc.ToString())
        $newDoc = "$head<w:body>$content<w:p/>$sectPr</w:body></w:document>"
        try { [void]([xml]$newDoc) } catch { throw "LazySpec wrote a broken word/document.xml (a bug: please report it): $($_.Exception.Message)" }
        Write-ZipText $zip 'word/document.xml' $newDoc

        # Relationships: the content's; the sample body's pictures and links go (the headers' have their own).
        $relsXml = Read-ZipText $zip 'word/_rels/document.xml.rels'
        $dropped = @()
        foreach ($m in [regex]::Matches($relsXml, '<Relationship\b[^>]*/>')) {
            $id = [regex]::Match($m.Value, 'Id="([^"]+)"').Groups[1].Value
            $type = [regex]::Match($m.Value, 'Type="[^"]*/([^"/]+)"').Groups[1].Value
            if ($type -notin 'image', 'hyperlink') { continue }
            if ($oldBody -match "r:(?:embed|id|link)=`"$([regex]::Escape($id))`"" -and $newDoc -notmatch "`"$([regex]::Escape($id))`"") {
                $relsXml = $relsXml.Replace($m.Value, '')
                if ($type -eq 'image') { $dropped += [regex]::Match($m.Value, 'Target="([^"]+)"').Groups[1].Value }
            }
        }
        $add = -join @($ctx.Rels | ForEach-Object {
                $mode = ''
                if ($_.External) { $mode = ' TargetMode="External"' }
                "<Relationship Id=`"$($_.Id)`" Type=`"$($_.Type)`" Target=`"$(Xml $_.Target)`"$mode/>" })
        $relsXml = $relsXml.Replace('</Relationships>', "$add</Relationships>")
        # The numbering: the content's lists (bullets; 1. 2.; a) b)), after the template's own.
        if ($ctx.Nums.Count) {
            if (-not $numXml) {
                $numXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"></w:numbering>'
                $relsXml = $relsXml.Replace('</Relationships>', '<Relationship Id="rIdLsNum" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/></Relationships>')
                $ct = Read-ZipText $zip '[Content_Types].xml'
                Write-ZipText $zip '[Content_Types].xml' $ct.Replace('</Types>', '<Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/></Types>')
            }
            $absMax = 0; foreach ($m in [regex]::Matches($numXml, 'w:abstractNumId="(\d+)"')) { $absMax = [Math]::Max($absMax, [int]$m.Groups[1].Value) }
            $abs = @{}
            $absXml = New-Object Text.StringBuilder
            foreach ($kind in 'bullet', 'decimal', 'letter') {
                $absMax++
                $abs[$kind] = $absMax
                [void]$absXml.Append("<w:abstractNum w:abstractNumId=`"$absMax`"><w:multiLevelType w:val=`"hybridMultilevel`"/>")
                for ($l = 0; $l -le 8; $l++) {
                    $fmt = 'bullet'; $text = @([string][char]0x2022, [string][char]0x25E6, [string][char]0x25AA)[$l % 3]
                    if ($kind -eq 'decimal') { $fmt = @('decimal', 'lowerLetter', 'lowerRoman')[$l % 3]; $text = "%$($l + 1)." }
                    # Lettered (answers under a numbered question): letters at any level, as in PDF and HTML.
                    if ($kind -eq 'letter') { $fmt = 'lowerLetter'; $text = "%$($l + 1)." }
                    [void]$absXml.Append("<w:lvl w:ilvl=`"$l`"><w:start w:val=`"1`"/><w:numFmt w:val=`"$fmt`"/><w:lvlText w:val=`"$(Xml $text)`"/><w:lvlJc w:val=`"left`"/><w:pPr><w:ind w:left=`"$(360 * ($l + 1) + 360)`" w:hanging=`"360`"/></w:pPr></w:lvl>")
                }
                [void]$absXml.Append('</w:abstractNum>')
            }
            $nums = New-Object Text.StringBuilder
            for ($i = 0; $i -lt $ctx.Nums.Count; $i++) {
                $id = $numMax + 1 + $i
                [void]$nums.Append("<w:num w:numId=`"$id`"><w:abstractNumId w:val=`"$($abs[$ctx.Nums[$i]])`"/><w:lvlOverride w:ilvl=`"0`"><w:startOverride w:val=`"1`"/></w:lvlOverride></w:num>")
            }
            # The abstract numberings before every w:num (the schema's order).
            $firstNum = $numXml.IndexOf('<w:num ')
            if ($firstNum -lt 0) { $firstNum = $numXml.IndexOf('<w:numIdMacAtCleanup'); }
            if ($firstNum -lt 0) { $firstNum = $numXml.IndexOf('</w:numbering>') }
            $numXml = $numXml.Insert($firstNum, $absXml.ToString())
            $cleanup = $numXml.IndexOf('<w:numIdMacAtCleanup')
            if ($cleanup -lt 0) { $cleanup = $numXml.IndexOf('</w:numbering>') }
            $numXml = $numXml.Insert($cleanup, $nums.ToString())
            Write-ZipText $zip 'word/numbering.xml' $numXml
        }
        Write-ZipText $zip 'word/_rels/document.xml.rels' $relsXml
        # The pictures, and their types.
        $ct = Read-ZipText $zip '[Content_Types].xml'
        foreach ($m in $ctx.Media) {
            Write-ZipBytes $zip "word/media/$($m.Name)" $m.Bytes
            if ($ct -notmatch "Extension=`"$($m.Ext)`"") { $ct = $ct.Replace('<Override ', "<Default Extension=`"$($m.Ext)`" ContentType=`"image/$($m.Ext)`"/><Override ") }
        }
        # A .dotx as the template: the result is a document.
        $ct = $ct.Replace('wordprocessingml.template.main+xml', 'wordprocessingml.document.main+xml')
        Write-ZipText $zip '[Content_Types].xml' $ct
        # The sample body's pictures that nothing uses any more.
        $allRels = -join @($zip.Entries | Where-Object { $_.FullName -match '\.rels$' } | ForEach-Object { Read-ZipText $zip $_.FullName })
        foreach ($t in $dropped) {
            if ($allRels -notmatch [regex]::Escape("Target=`"$t`"")) { $e = $zip.GetEntry("word/$t"); if ($e) { $e.Delete() } }
        }
        # The document's title in its properties.
        $core = Read-ZipText $zip 'docProps/core.xml'
        if ($core) {
            $t = $x.SelectSingleNode("//p[@class='title']")
            if ($t) {
                $title = Xml $t.InnerText.Trim()
                $core = [regex]::Replace($core, '<dc:title\s*/>|<dc:title>[^<]*</dc:title>', "<dc:title>$title</dc:title>")
                Write-ZipText $zip 'docProps/core.xml' $core
            }
        }
    }
    finally { $pkg.Zip.Dispose() }
    [IO.File]::WriteAllBytes($Target, $pkg.Stream.ToArray())
    $pkg.Stream.Dispose()
    # The contents' page numbers: Word fills them in when it's there (the rest of the document as written).
    $word = $null
    try { $word = New-Object -ComObject Word.Application } catch { }
    if (-not $word) { Write-Host "  ! the contents have no page numbers yet: in Word, right-click them, Update Field (no Word on this PC)"; return }
    $doc = $null
    try {
        $word.Visible = $false
        $word.DisplayAlerts = 0
        $doc = $word.Documents.Open($Target, $false, $false, $false)
        foreach ($t in @($doc.TablesOfContents)) { $t.Update() }
        $doc.Save()
        Write-Host "  $($g.caret) contents' page numbers by Microsoft Word"
    }
    catch { Write-Host "  ! the contents' page numbers not filled in ($($_.Exception.Message)): in Word, Update Field" }
    finally {
        if ($doc) { try { $doc.Close($false) } catch { } }
        try { $word.Quit() } catch { }
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
    }
}

function Invoke-Export([string]$Format, [string]$Target, [bool]$WithChanges, [bool]$OpenIt, [string]$ItemName, [bool]$Friendly, [string]$MarkdownPath, [string]$ItemTitle) {
    # A Markdown document (-Markdown): in the project's look when it's in one; else the specification.
    $mdDoc = $null
    if ($MarkdownPath) {
        $md = $MarkdownPath
        if (-not [IO.Path]::IsPathRooted($md)) { $md = Join-Path (Get-Location).Path $md }
        $md = [IO.Path]::GetFullPath($md)
        if (-not (Test-Path -LiteralPath $md -PathType Leaf)) { throw "The Markdown file isn't there: $md" }
        if ($ItemName -or $WithChanges) { Write-Host "  ! -Item and -IncludeChanges are for the specification: not used with -Markdown" }
        $mdDoc = Read-MarkdownDocument $md
        $script:wordMode = @{ ChapterBreaks = $false; TocLevels = 2; TocBreak = $mdDoc.Cover }
        if (-not $hasRoot) { Write-Host "  ! $(Split-Path $md -Leaf) isn't in a project (no openspec folder above it): no project theme or template (-Theme, -Template still work)" }
    }
    elseif (-not $hasRoot) { throw "No openspec folder in $((Get-Location).Path) or above it: nothing to export." }
    # Word: the project's template, when it has one; every format: its theme (checked first: a missing one
    # stops the export). Both: Word documents use the template, PDF and HTML the theme.
    $templatePath = ''
    if ($Format -eq 'Word' -and -not ($Theme -and -not $Template)) { $templatePath = Get-DocumentTemplate }
    elseif ($Template) { Write-Host "  ! -Template is for Word documents: the $Format export doesn't use it" }
    $script:docTheme = Get-DocumentTheme
    if ($script:docTheme -and $templatePath) { Write-Host "  ! a document template and a theme: this Word document uses the template ($(Split-Path $templatePath -Leaf)); PDF and HTML use the theme" }
    elseif ($script:docTheme) { Write-Host "  $($g.caret) document theme: $($script:docTheme.Path)"; Write-ThemeFontWarning $script:docTheme ($Format -eq 'Word') }
    $ext = @{ Pdf = 'pdf'; Word = 'docx'; Html = 'html' }[$Format]
    if ($mdDoc) { $doc = Get-ExportHtml $Format $false '' $Friendly $mdDoc } else { $doc = Get-ExportHtml $Format $WithChanges $ItemName $Friendly $null $ItemTitle }
    if ($mdDoc) { $what = "document $(Split-Path $mdDoc.Path -Leaf): $($mdDoc.Title)" }
    elseif ($doc.Item) {
        if (-not $doc.Chapters) { throw "$($doc.Item.Name) has none of its documents yet: nothing to export." }
        $what = "$($doc.Item.Type) $($doc.Item.Name): $($doc.Scope)"
        if ($doc.Item.Type -eq 'spec') { $what = "spec $($doc.Item.Name): $($doc.Reqs) requirements" }
        if ($doc.Item.Type -eq 'bundle') { $what = "changes $($doc.Item.Name.Replace(',', ', ')) as one, $($doc.Item.Title): $($doc.Scope)" }
    }
    else {
        if (-not $doc.Specs) { throw 'openspec/specs has no specs yet: nothing to export.' }
        $what = "$($doc.Specs) specs, $($doc.Reqs) requirements"
        if ($WithChanges) { $what += ", $($doc.Changes) active changes" }
    }
    # A Markdown document: next to it, the same name.
    if (-not $Target -and $mdDoc) { $Target = [IO.Path]::ChangeExtension($mdDoc.Path, $ext) }
    if (-not $Target) {
        $slug = ($projectName.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
        if (-not $slug) { $slug = 'project' }
        $part = 'specification'
        if ($doc.Item) { $part = ($doc.Item.Name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-') }
        # Several changes as one: by the saved whole's key, else its title (without accents), else their names.
        if ($doc.Item.Type -eq 'bundle') {
            $t = ''
            if ($doc.Item.Id) { $t = Get-Slug $doc.Item.Id } elseif ($ItemTitle) { $t = Get-Slug $ItemTitle }
            if ($t) { $part = $t }
        }
        $Target = Join-Path $Root "export\$slug-$part-$(Get-Date -Format 'yyyy-MM-dd').$ext"
    }
    $Target = [IO.Path]::GetFullPath($Target)
    [void](New-Item -ItemType Directory -Force -Path (Split-Path $Target -Parent))
    if ($projectName) { Write-Host "  $($g.caret) $projectName`: $what" } else { Write-Host "  $($g.caret) $what" }
    $how = "language $($script:exportLang)"
    if ($Friendly) { $how += ', client-friendly (scenarios as sentences)' }
    Write-Host "  $($g.caret) $how"
    # The previous export still open (a PDF viewer, Word): say so plainly, before the work.
    if (Test-Path -LiteralPath $Target) {
        try { $fs = [IO.File]::Open($Target, 'Open', 'ReadWrite', 'None'); $fs.Close() }
        catch { throw "$(Split-Path $Target -Leaf) is open in another program (a PDF viewer, Word): close it and retry." }
    }
    $utf8 = New-Object Text.UTF8Encoding $false
    if ($Format -eq 'Html') { [IO.File]::WriteAllText($Target, $doc.Html, $utf8) }
    else {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('lazyspec-export-' + [guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $tmp)
        try {
            $htmlPath = Join-Path $tmp 'specification.html'
            [IO.File]::WriteAllText($htmlPath, $doc.Html, $utf8)
            if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Force }
            if ($Format -eq 'Pdf') { Export-Pdf $htmlPath $Target }
            elseif ($templatePath) { Write-TemplateFontWarning $templatePath; Export-WordTemplate $doc.Html $Target $templatePath }
            elseif ($script:docTheme) { Export-WordTheme $doc.Html $Target $script:docTheme $doc.Meta }
            else { Export-Word $htmlPath $Target }
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
    foreach ($t in $script:exportTempFiles) { Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue }
    $script:exportTempFiles.Clear()
    Write-Host "$($g.check) Written: $Target"
    if ($script:exportTranslate) { Save-TranslationCache; Invoke-ExportHasek $Target }
    if ($OpenIt) { Invoke-Item -LiteralPath $Target }
}

if ($AddLanguage) {
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
    try { Add-ExportLanguage $AddLanguage; exit 0 }
    catch { Write-Host "$($g.cross) -AddLanguage failed: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
}
if ($Export) {
    # Shown in LazySpec's run screen too (it reads this as UTF-8).
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
    # The diagrams: the latest from Figma when there is a token (the saved ones when that fails), unless
    # -KeepDiagrams; -RefreshDiagrams: the latest in any case (and says so when there is no token).
    $script:diagramsRefresh = $RefreshDiagrams.IsPresent -or (-not $KeepDiagrams.IsPresent -and [bool](Get-FigmaToken))
    $script:diagramsOffline = $KeepDiagrams.IsPresent -and -not $RefreshDiagrams.IsPresent
    try { Invoke-Export $Export $Out $IncludeChanges.IsPresent $Open.IsPresent (@($Item) -join ',') $ClientFriendly.IsPresent $Markdown $Title; exit 0 }
    catch { Write-Host "$($g.cross) Export failed: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
}

# --- drawing -------------------------------------------------------------------------------------------

function Border-Top([int]$W, [string]$Left, [string]$Right, [int]$Split) {
    $segs = @((S $g.tl $st.border), (S $g.h $st.border), (S ' lazyspec ' $st.brand), (S " $Left " $st.title))
    $used = 2 + 10 + $Left.Length + 2
    $rightText = " $Right "
    $fill = $W - $used - $rightText.Length - 2
    if ($fill -lt 1) { $rightText = ''; $fill = $W - $used - 1 }
    $line = ''
    for ($i = 0; $i -lt $fill; $i++) { if ($used + $i -eq $Split) { $line += $g.tt } else { $line += $g.h } }
    $segs += (S $line $st.border)
    $segs += (S $rightText $st.muted)
    $segs += (S ($g.h + $g.tr) $st.border)
    return , (Fit $segs $W)
}
function Border-Line([int]$W, [string]$Left, [string]$Mid, [string]$Right, [int]$Split, [string]$SplitChar) {
    $line = $Left
    for ($i = 1; $i -lt $W - 1; $i++) { if ($Split -gt 0 -and $i -eq $Split) { $line += $SplitChar } else { $line += $Mid } }
    $line += $Right
    return , @(S $line $st.border)
}
function Border-Bottom([int]$W, $Hints, [int]$Split) {
    $segs = @((S ($g.bl + $g.h + ' ') $st.border))
    foreach ($h in $Hints) { $segs += (S $h[0] $st.key); $segs += (S " $($h[1])  " $st.muted) }
    $len = 0
    foreach ($s in $segs) { $len += $s.T.Length }
    $rest = $W - $len - 1
    if ($rest -gt 0) {
        $line = ''
        for ($i = 0; $i -lt $rest; $i++) { if ($len + $i -eq $Split) { $line += $g.bt } else { $line += $g.h } }
        $segs += (S $line $st.border)
    }
    $segs += (S $g.br $st.border)
    return , (Fit $segs $W)
}
# Two columns between borders: left lines (width $Lw) and right lines, $Rows rows.
function Columns($Rows, [int]$W, [int]$Lw, $Left, $Right, $LeftBg) {
    $Rw = $W - $Lw - 3
    $out = @()
    for ($i = 0; $i -lt $Rows; $i++) {
        $l = $null; $r = $null; $bg = ''
        if ($i -lt $Left.Count) { $l = $Left[$i] }
        if ($i -lt $Right.Count) { $r = $Right[$i] }
        if ($LeftBg -and $LeftBg.ContainsKey($i)) { $bg = $LeftBg[$i] }
        $segs = @(S $g.v $st.border) + (Fit $l $Lw $bg) + @(S $g.v $st.border) + (Fit $r $Rw) + @(S $g.v $st.border)
        $out += , $segs
    }
    return , $out
}
function Full-Rows($Rows, [int]$W, $Lines) {
    $out = @()
    for ($i = 0; $i -lt $Rows; $i++) {
        $l = $null
        if ($i -lt $Lines.Count) { $l = $Lines[$i] }
        $out += , (@(S $g.v $st.border) + (Fit $l ($W - 2)) + @(S $g.v $st.border))
    }
    return , $out
}
function Section-Head($Lines, [string]$Title, [string]$Note) {
    $segs = @(S " $Title" $st.title)
    if ($Note) { $segs += (S "  $($g.mid) $Note" $st.muted) }
    [void]$Lines.Add($segs)
}

# The first paragraph of a markdown text (no headings, tables or code), as at most $Max wrapped lines.
function Get-Summary([string]$Text, [int]$Width, [int]$Max) {
    $para = ''
    foreach ($block in ([regex]::Split($Text.Replace("`r", ''), '\n\s*\n'))) {
        $b = $block.Trim()
        if (-not $b -or $b.StartsWith('#') -or $b.StartsWith('|') -or $b.StartsWith('```')) { continue }
        $para = (@($b.Split("`n") | ForEach-Object { ($_.Trim() -replace '^[-*+]\s+', '') }) -join ' ')
        break
    }
    $out = [string[]](Wrap (Plain-Inline $para) $Width)
    if ($out.Count -gt $Max) { $out = @($out[0..($Max - 1)]); $out[$Max - 1] = (Short $out[$Max - 1] ($Width - 1)) + $g.ell }
    return , $out
}
function Add-Hint($Lines) {
    [void]$Lines.Add(@())
    [void]$Lines.Add(@((S ' Enter' $st.key), (S ' open the whole page' $st.muted), (S "   e" $st.key), (S ' edit' $st.muted)))
}
function Get-SpecDetails($Spec, [int]$Width) {
    $lines = New-Object Collections.ArrayList
    $chip = S ' CAPABILITY ' $st.chipOk
    if ($Spec.Platform) { $chip = S ' PLATFORM ' $st.chipOn }
    [void]$lines.Add(@($chip, (S "  $(Get-ItemTitle $Spec)" $st.title)))
    [void]$lines.Add(@((S " openspec/specs/$($Spec.Name)/spec.md" $st.muted), (S "   modified $(Ago $Spec.Modified)" $st.faint)))
    [void]$lines.Add(@())
    [void]$lines.Add(@((S " $($Spec.Reqs)" $st.bold), (S " requirement$(if ($Spec.Reqs -ne 1) { 's' })  $($g.mid)  " $st.muted), (S "$($Spec.Scenarios)" $st.bold), (S " scenario$(if ($Spec.Scenarios -ne 1) { 's' })" $st.muted)))
    [void]$lines.Add(@())
    $purpose = Get-Section $Spec.Text 'Purpose'
    if ($purpose) {
        Section-Head $lines 'PURPOSE' ''
        foreach ($l in (Get-Summary $purpose ($Width - 2) 4)) { [void]$lines.Add(@(S " $l" $st.text)) }
        [void]$lines.Add(@())
    }
    $reqs = [regex]::Matches($Spec.Text, '(?ms)^###\s+Requirement:\s*(.+?)\s*$(.*?)(?=^###\s|\z)')
    if ($reqs.Count) {
        Section-Head $lines 'REQUIREMENTS' ''
        foreach ($m in $reqs) {
            $sc = Count $m.Groups[2].Value '(?m)^####\s+Scenario:'
            [void]$lines.Add(@((S "  $($g.diamond) " $st.accent), (S (Plain-Inline $m.Groups[1].Value) $st.text), (S "  $sc" $st.faint)))
        }
        [void]$lines.Add(@())
    }
    # The changes that will change it (their delta specs for this capability).
    $touching = @($script:changes | Where-Object { -not $_.Archived -and @($_.Caps | ForEach-Object { $_.Name }) -contains $Spec.Name })
    if ($touching.Count) {
        Section-Head $lines 'CHANGED BY' "$($touching.Count) change$(if ($touching.Count -ne 1) { 's' })"
        foreach ($c in $touching) {
            $cap = $c.Caps | Where-Object { $_.Name -eq $Spec.Name } | Select-Object -First 1
            $look = $stageLook[$c.Stage]
            $row = @((S "  $($look[0]) " $look[1]), (S "$($c.Name)  " $st.text))
            if ($cap.Added) { $row += (S "+$($cap.Added) " $st.ok) }
            if ($cap.Modified) { $row += (S "~$($cap.Modified) " $st.warn) }
            if ($cap.Removed) { $row += (S "-$($cap.Removed) " $st.err) }
            [void]$lines.Add($row)
        }
    }
    Add-Hint $lines
    return , $lines
}
function Get-ChangeDetails($Change, [int]$Width) {
    $lines = New-Object Collections.ArrayList
    $look = $stageLook[$Change.Stage]
    [void]$lines.Add(@((S " $($Change.Stage.ToUpper()) " $look[2]), (S "  $(Get-ItemTitle $Change)" $st.title)))
    $rel = "openspec/changes/$($Change.Name)/"
    if ($Change.Archived) { $rel = "openspec/changes/archive/$($Change.Name)/" }
    [void]$lines.Add(@((S " $rel" $st.muted), (S "   modified $(Ago $Change.Modified)" $st.faint)))
    [void]$lines.Add(@())
    $pct = 0
    if ($Change.Total) { $pct = [int][Math]::Round(100 * $Change.Done / $Change.Total) }
    $barW = [Math]::Max(10, [Math]::Min(40, $Width - 26))
    [void]$lines.Add(@(S ' ') + (Bar $Change.Done $Change.Total $barW $look[1]) + @((S "  $pct%" "1;$($look[1])"), (S "   $($Change.Done) of $($Change.Total) tasks" $st.muted)))
    [void]$lines.Add(@())
    # Tasks by group: "## 1. Schema" and its checkboxes.
    if ($Change.Tasks) {
        Section-Head $lines 'TASKS' ''
        $groups = [regex]::Matches($Change.Tasks, '(?ms)^##\s+(.+?)\s*$(.*?)(?=^##\s|\z)')
        $gw = 0
        foreach ($m in $groups) { if ($m.Groups[1].Value.Length -gt $gw) { $gw = $m.Groups[1].Value.Length } }
        $gw = [Math]::Min($gw + 2, [Math]::Max(16, $Width - 26))
        foreach ($m in $groups) {
            $d = Count $m.Groups[2].Value '(?mi)^\s*[-*]\s+\[x\]'
            $o = Count $m.Groups[2].Value '(?m)^\s*[-*]\s+\[ \]'
            $glyph = S "$($g.ring) " $st.faint
            $style = $st.text
            if ($o -eq 0 -and $d -gt 0) { $glyph = S "$($g.check) " $st.ok; $style = $st.muted }
            elseif ($d -gt 0) { $glyph = S "$($g.diamond) " $st.accent }
            [void]$lines.Add(@((S '  '), $glyph, (S (Pad (Short $m.Groups[1].Value ($gw - 2)) $gw) $style)) + (Bar $d ($d + $o) 10 $look[1]) + @(S "  $d/$($d + $o)" $st.muted))
        }
        [void]$lines.Add(@())
    }
    if ($Change.Caps.Count) {
        Section-Head $lines 'CAPABILITIES' ''
        $nw = 0
        foreach ($c in $Change.Caps) { if ($c.Name.Length -gt $nw) { $nw = $c.Name.Length } }
        foreach ($c in $Change.Caps) {
            $exists = Test-Path -LiteralPath (Join-Path (Join-Path (Join-Path $osDir 'specs') $c.Name) 'spec.md')
            $mark = S "  $($g.dot) " $st.ok
            if ($exists) { $mark = S "  $($g.diamond) " $st.accent }
            $row = @($mark, (S (Pad $c.Name ($nw + 2)) $st.text))
            if ($c.Added) { $row += (S "+$($c.Added) " $st.ok) }
            if ($c.Modified) { $row += (S "~$($c.Modified) " $st.warn) }
            if ($c.Removed) { $row += (S "-$($c.Removed) " $st.err) }
            if ($c.Renamed) { $row += (S "$($c.Renamed) renamed " $st.shared) }
            if ($exists) { $row += (S ' existing' $st.faint) } else { $row += (S ' new' $st.faint) }
            [void]$lines.Add($row)
        }
        [void]$lines.Add(@())
    }
    $proposal = Read-Text (Join-Path $Change.Dir 'proposal.md')
    $why = Get-Section $proposal 'Why'
    if ($why) {
        Section-Head $lines 'WHY' ''
        foreach ($l in (Get-Summary $why ($Width - 2) 4)) { [void]$lines.Add(@(S " $l" $st.text)) }
        [void]$lines.Add(@())
    }
    # The workflow's documents, in its order: done or not yet; the delta specs as a count.
    Section-Head $lines 'DOCUMENTS' ''
    $row = @((S ' '))
    $used = 1
    foreach ($d in $Change.Docs) {
        if ($d.IsSpecs) { $seg = S "$($g.check) $($Change.Caps.Count) delta spec$(if ($Change.Caps.Count -ne 1) { 's' })   " $st.ok; if (-not $Change.Caps.Count) { $seg = S "$($g.ring) delta specs   " $st.faint } }
        elseif ($d.Files.Count) { $seg = S "$($g.check) $($d.Id)   " $st.ok; if ($d.Extra) { $seg = S "$($g.check) $($d.Id)   " $st.muted } }
        else { $seg = S "$($g.ring) $($d.Id)   " $st.faint }
        if ($used + $seg.T.Length -gt $Width -and $row.Count -gt 1) { [void]$lines.Add($row); $row = @((S ' ')); $used = 1 }
        $row += $seg; $used += $seg.T.Length
    }
    [void]$lines.Add($row)
    if ($Change.Workflow.Missing) { [void]$lines.Add(@(S " workflow '$($Change.Workflow.Missing)' not found: shown as spec-driven" $st.warn)) }
    elseif ($Change.Workflow.Name -ne 'spec-driven') { [void]$lines.Add(@(S " workflow $($Change.Workflow.Name)" $st.faint)) }
    Add-Hint $lines
    return , $lines
}

# A scrollbar for a pane of $Rows rows showing $Total lines from $Top: one character per row.
function Get-ScrollBar([int]$Rows, [int]$Total, [int]$Top, [bool]$Focused) {
    $out = @()
    if ($Total -le $Rows -or $Rows -lt 1) { for ($i = 0; $i -lt $Rows; $i++) { $out += , (S ' ' '') }; return , $out }
    $thumb = [Math]::Max(1, [int][Math]::Floor($Rows * $Rows / $Total))
    $max = $Total - $Rows
    $pos = [int][Math]::Round(($Rows - $thumb) * $Top / $max)
    $style = $st.faint
    if ($Focused) { $style = $st.accent }
    for ($i = 0; $i -lt $Rows; $i++) {
        if ($i -ge $pos -and $i -lt $pos + $thumb) { $out += , (S $g.full $style) } else { $out += , (S $g.light $st.faint) }
    }
    return , $out
}
# The details' lines on screen: $Rows rows of width $Width (the last column is the scrollbar).
function Get-DetailRows($Details, [int]$Rows, [int]$Width, [bool]$Focused) {
    $max = [Math]::Max(0, $Details.Count - $Rows)
    if ($script:detailScroll -gt $max) { $script:detailScroll = $max }
    $bar = Get-ScrollBar $Rows $Details.Count $script:detailScroll $Focused
    $out = @()
    for ($i = 0; $i -lt $Rows; $i++) {
        $l = $null
        if ($script:detailScroll + $i -lt $Details.Count) { $l = $Details[$script:detailScroll + $i] }
        $out += , ((Fit $l ($Width - 1)) + @($bar[$i]))
    }
    return , $out
}
function Get-Details($Width) {
    $sel = Get-Selected
    if ($sel -and $sel.Type -eq 'spec') { return Get-SpecDetails $sel $Width }
    if ($sel) { return Get-ChangeDetails $sel $Width }
    return , @(@(), @(S ' Nothing selected.' $st.muted))
}
function Bottom-Line([int]$W, [int]$Split) {
    $rows = @()
    if ($script:confirm) {
        $c = $script:confirm
        $yes = S ' Yes ' $st.chip; $no = S ' No ' $st.chip
        if ($c.Choice -eq 0) { $yes = S ' Yes ' $st.chipDanger } else { $no = S ' No ' $st.chipOn }
        $rows += , (@(S $g.v $st.border) + (Fit @((S ' ? ' $st.key), (S "$($c.Text)  " $st.bold), $yes, (S ' '), $no) ($W - 2)) + @(S $g.v $st.border))
    } elseif ($script:choose) {
        $c = $script:choose
        $line = @((S ' ? ' $st.key), (S "$($c.Text)  " $st.bold))
        for ($i = 0; $i -lt $c.Options.Count; $i++) {
            if ($i -eq $c.Choice) { $line += (S " $($c.Options[$i]) " $st.chipOn) } else { $line += (S " $($c.Options[$i]) " $st.chip) }
            $line += (S ' ')
        }
        $rows += , (@(S $g.v $st.border) + (Fit $line ($W - 2)) + @(S $g.v $st.border))
    } elseif ($script:input) {
        $i = $script:input
        $rows += , (@(S $g.v $st.border) + (Fit @((S ' ? ' $st.key), (S "$($i.Label)  " $st.bold), (S "$($i.Value)$($g.cursor)" $st.accent), (S "   $($i.Hint)" $st.faint)) ($W - 2)) + @(S $g.v $st.border))
    } elseif ($script:message) {
        $rows += , (@(S $g.v $st.border) + (Fit @((S ' ! ' $st.warn), (S $script:message $st.warn)) ($W - 2)) + @(S $g.v $st.border))
    }
    return , $rows
}
function Home-Hints {
    if ($script:confirm) { return , @(@('y n', 'yes, no'), @("$([string][char]0x2190)$([string][char]0x2192)", 'choose'), @('Enter', 'ok'), @('Esc', 'cancel')) }
    if ($script:choose) {
        # Each key with what it picks: "p pdf  w word  h html".
        $c = $script:choose
        $names = $c.Options
        if ($c.PSObject.Properties['Short']) { $names = $c.Short }
        $hints = @()
        for ($i = 0; $i -lt $c.Keys.Count; $i++) { $hints += , @($c.Keys[$i], ([string]$names[$i]).ToLower()) }
        return , ($hints + @(, @("$([string][char]0x2190)$([string][char]0x2192)", 'choose')) + @(, @('Enter', 'ok')) + @(, @('Esc', 'cancel')))
    }
    if ($script:input) { return , @(@('Enter', 'ok'), @('Esc', 'cancel')) }
    if ($script:filtering) { return , @(@('type', 'filter'), @('Enter', 'keep'), @('Esc', 'clear')) }
    if ($script:zoom) { return , @(@("$($g.up)$($g.down) PgUp PgDn", 'scroll'), @('z Esc', 'show the lists'), @('Enter', 'read'), @('e', 'edit'), @('?', 'help'), @('q', 'quit')) }
    if ($script:pane -eq 'details') { return , @(@("$($g.up)$($g.down) PgUp PgDn", 'scroll'), @("$([string][char]0x2190) Esc", 'lists'), @('z', 'zoom'), @('Enter', 'read'), @('e', 'edit'), @('?', 'help'), @('q', 'quit')) }
    return , @(@("$($g.up)$($g.down)", 'select'), @('Enter', 'open'), @('Tab', 'scope/plan'), @('v', 'validate'), @('a', 'archive'), @('n', 'new'), @('x', 'export'), @('m', 'as one'), @('e', 'edit'), @('s', 'sort'), @('/', 'filter'), @('?', 'help'), @('q', 'quit'))
}

function Home-Status([int]$Active, [int]$Lines, [int]$Rows) {
    $status = "openspec/  $($g.mid)  scope $($script:specs.Count)  $($g.mid)  plan $Active"
    if ($Lines -gt $Rows) {
        $pct = [int][Math]::Round(100 * $script:detailScroll / [Math]::Max(1, $Lines - $Rows))
        $status = "details $pct%  $($g.mid)  $status"
    }
    return $status
}
function Draw-Home([int]$W, [int]$H) {
    $bottom = Bottom-Line $W 0
    $bodyRows = $H - 3 - $bottom.Count
    $active = @($script:changes | Where-Object { -not $_.Archived }).Count
    $rows = New-Object Collections.ArrayList

    # Zoomed: the details over the whole width (z or Esc brings the lists back).
    if ($script:zoom) {
        $sel = Get-Selected
        $label = $projectName
        if ($sel) { $label = "$projectName $($g.mid) $(if ($sel.Type -eq 'spec') { $sel.Short } else { $sel.Name })" }
        $details = Get-Details ($W - 4)
        $shown = Get-DetailRows $details $bodyRows ($W - 2) $true
        [void]$rows.Add((Border-Top $W $label (Home-Status $active $details.Count $bodyRows) 0))
        foreach ($r in $shown) { [void]$rows.Add((@(S $g.v $st.border) + @($r) + @(S $g.v $st.border))) }
        foreach ($r in $bottom) { [void]$rows.Add($r) }
        [void]$rows.Add((Border-Line $W $g.lt $g.h $g.rt 0 ''))
        [void]$rows.Add((Border-Bottom $W (Home-Hints) 0))
        return , $rows
    }

    $Lw = [Math]::Min(40, [Math]::Max(30, [int]($W * 0.30)))
    $left = New-Object Collections.ArrayList
    $bg = @{}
    $vs = @(Get-VisibleSpecs)
    $vc = @(Get-VisibleChanges)
    $listFocus = $script:pane -ne 'details'
    $selBg = $st.sel
    if (-not $listFocus) { $selBg = '48;5;234' }
    # Specifications.
    [void]$left.Add(@((S ' SCOPE ' $st.title), (S "$($g.mid) $($vs.Count)" $st.muted)))
    if (-not $vs.Count) { [void]$left.Add(@(S '   none yet' $st.faint)) }
    $sw = $Lw - 9
    for ($i = 0; $i -lt $vs.Count; $i++) {
        $s = $vs[$i]
        $mark = '  '
        if ($i -eq $script:specIndex -and $script:focus -eq 'specs') { $mark = "$($g.tri) "; $bg[$left.Count] = $selBg }
        $glyph = S "$($g.dot) " $st.ok
        if ($s.Platform) { $glyph = S "$($g.diamond) " $st.accent }
        [void]$left.Add(@((S " $mark" $st.accent), $glyph, (S (Pad (Short (Get-ItemTitle $s) $sw) $sw) $st.text), (S (PadL "$($s.Reqs)" 3) $st.muted)))
    }
    [void]$left.Add(@())
    # Changes.
    $archived = @($script:changes | Where-Object { $_.Archived }).Count
    $note = "$active"
    if ($archived) { if ($script:showArchived) { $note += " + $archived archived" } else { $note += " $($g.mid) $archived archived (h)" } }
    [void]$left.Add(@((S ' PLAN ' $st.title), (S "$($g.mid) $note" $st.muted)))
    if (-not $vc.Count) { [void]$left.Add(@(S '   nothing planned  (n: new change)' $st.faint)) }
    $cw = $Lw - 12
    for ($i = 0; $i -lt $vc.Count; $i++) {
        $c = $vc[$i]
        $mark = '  '
        if ($i -eq $script:changeIndex -and $script:focus -eq 'changes') { $mark = "$($g.tri) "; $bg[$left.Count] = $selBg }
        $look = $stageLook[$c.Stage]
        $style = $st.text
        if ($c.Archived) { $style = $st.faint }
        $countStyle = $st.muted
        if ($c.Stage -eq 'Completed') { $countStyle = $st.ok }
        [void]$left.Add(@((S " $mark" $st.accent), (S "$($look[0]) " $look[1]), (S (Pad (Short (Get-ItemTitle $c) $cw) $cw) $style), (S (PadL "$($c.Done)/$($c.Total)" 6) $countStyle)))
    }
    [void]$left.Add(@())
    [void]$left.Add(@((S '   s' $st.key), (S ' sort: ' $st.muted), (S $sortLabels[$script:sort] $st.accent)))
    if ($script:filter -or $script:filtering) {
        $f = $script:filter
        if ($script:filtering) { $f += $g.cursor }
        [void]$left.Add(@((S '   /' $st.key), (S ' filter: ' $st.muted), (S $f $st.warn)))
    }

    $Rw = $W - $Lw - 3
    $details = Get-Details ($Rw - 2)
    $right = Get-DetailRows $details $bodyRows $Rw (-not $listFocus)

    # Whose it is, and where help is: at the bottom of the column (links open in the browser).
    $bar = S " $($g.bar) " $st.brandBar
    $brand = @(
        @($bar, (S 'LazySpec ' $st.brandName), (S $kitVersion $st.faint)),
        @($bar, (S 'by ' $st.faint), (S 'Netmedia' $st.netmedia 'https://netmedia.agency')),
        @($bar, (S 'https://netmedia.agency' $st.brandLink 'https://netmedia.agency')),
        @($bar, (S '? ' $st.key), (S 'help and keys' $st.muted)))
    # The selected item stays visible when the lists are longer than the column.
    $room = $bodyRows - $brand.Count - 1
    $selRow = -1
    foreach ($k in $bg.Keys) { $selRow = $k }
    $skip = 0
    if ($left.Count -gt $room -and $selRow -ge $room) { $skip = [Math]::Min($selRow - $room + 2, $left.Count - $room) }
    if ($skip -gt 0) {
        $left.RemoveRange(0, $skip)
        $nbg = @{}
        foreach ($k in $bg.Keys) { $nbg[$k - $skip] = $bg[$k] }
        $bg = $nbg
    }
    $gap = $bodyRows - $left.Count - $brand.Count
    if ($gap -ge 1) {
        for ($i = 0; $i -lt $gap; $i++) { [void]$left.Add(@()) }
        foreach ($b in $brand) { [void]$left.Add($b) }
    }
    [void]$rows.Add((Border-Top $W $projectName (Home-Status $active $details.Count $bodyRows) ($Lw + 1)))
    foreach ($r in (Columns $bodyRows $W $Lw $left $right $bg)) { [void]$rows.Add($r) }
    foreach ($r in $bottom) { [void]$rows.Add($r) }
    [void]$rows.Add((Border-Line $W $g.lt $g.h $g.rt ($Lw + 1) $g.bt))
    [void]$rows.Add((Border-Bottom $W (Home-Hints) 0))
    return , $rows
}

# The read screen: a spec (its spec.md) or a change (proposal, design, tasks, delta specs) in full.
function Get-ReadTabs($Item) {
    if ($Item.Type -eq 'spec') { return @([pscustomobject]@{ Title = 'Spec'; Path = $Item.Path; Text = $Item.Text }) }
    if ($Item.Type -eq 'bundle') { return Get-BundleReadTabs $Item }
    # One tab per document of the change's workflow, in its order (then the other .md files in its folder).
    $tabs = @()
    foreach ($d in $Item.Docs) {
        if ($d.IsSpecs) {
            if (-not $Item.Caps.Count) { continue }
            $sb = New-Object Text.StringBuilder
            foreach ($c in $Item.Caps) {
                [void]$sb.AppendLine("# $($c.Name)")
                [void]$sb.AppendLine('')
                [void]$sb.AppendLine((Read-Text $c.Path))
                [void]$sb.AppendLine('')
            }
            $tabs += [pscustomobject]@{ Title = "Specs ($($Item.Caps.Count))"; Path = $Item.Caps[0].Path; Text = $sb.ToString() }
            continue
        }
        if (-not $d.Files.Count) { continue }
        if ($d.Files.Count -eq 1) { $tabs += [pscustomobject]@{ Title = $d.Title; Path = $d.Files[0]; Text = (Read-Text $d.Files[0]) }; continue }
        # A glob with several files: one after the other, each under its name.
        $sb = New-Object Text.StringBuilder
        foreach ($f in $d.Files) {
            [void]$sb.AppendLine("# $($f.Substring($Item.Dir.TrimEnd('\', '/').Length + 1).Replace('\', '/'))")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine((Read-Text $f))
            [void]$sb.AppendLine('')
        }
        $tabs += [pscustomobject]@{ Title = "$($d.Title) ($($d.Files.Count))"; Path = $d.Files[0]; Text = $sb.ToString() }
    }
    if (-not $tabs.Count) { $tabs += [pscustomobject]@{ Title = 'Empty'; Path = $Item.Dir; Text = "This change has none of its workflow's documents yet ($(@($Item.Docs | ForEach-Object { $_.Generates }) -join ', '))." } }
    return $tabs
}
# Several changes as one: a tab per kind of document, each change's part under its title.
function Get-BundleReadTabs($Item) {
    $tabs = @()
    foreach ($d in $Item.Docs) {
        $sb = New-Object Text.StringBuilder
        $count = 0; $path = ''
        foreach ($m in $Item.Members) {
            if ($d.IsSpecs) {
                foreach ($c in $m.Caps) {
                    [void]$sb.AppendLine("# $(Get-ItemTitle $m) $($g.mid) $($c.Name)")
                    [void]$sb.AppendLine('')
                    [void]$sb.AppendLine((Remove-DocTitle (Read-Text $c.Path)))
                    [void]$sb.AppendLine('')
                    if (-not $path) { $path = $c.Path }
                    $count++
                }
                continue
            }
            $md = @($m.Docs | Where-Object { $_.Id -eq $d.Id -and $_.Files.Count } | Select-Object -First 1)
            if (-not $md.Count) { continue }
            foreach ($f in $md[0].Files) {
                $head = Get-ItemTitle $m
                if ($md[0].Files.Count -gt 1) { $head += " $($g.mid) $(Split-Path $f -Leaf)" }
                [void]$sb.AppendLine("# $head")
                [void]$sb.AppendLine('')
                [void]$sb.AppendLine((Remove-DocTitle (Read-Text $f)))
                [void]$sb.AppendLine('')
                if (-not $path) { $path = $f }
            }
            $count++
        }
        if (-not $count) { continue }
        $t = $d.Title
        if ($d.IsSpecs) { $t = 'Specs' }
        $tabs += [pscustomobject]@{ Title = "$t ($count)"; Path = $path; Text = $sb.ToString() }
    }
    if (-not $tabs.Count) { $tabs += [pscustomobject]@{ Title = 'Empty'; Path = $Item.Dir; Text = 'None of these changes has its workflow''s documents yet.' } }
    return $tabs
}
function Draw-Read([int]$W, [int]$H) {
    $item = $script:readItem
    $tabs = @(Get-ReadTabs $item)
    if ($script:readTab -ge $tabs.Count) { $script:readTab = $tabs.Count - 1 }
    $tab = $tabs[$script:readTab]
    $key = "$($item.Name)/$($script:readTab)/$W/$($item.Modified.Ticks)"
    if (-not $script:readCache.ContainsKey($key)) { $script:readCache[$key] = Render-Markdown $tab.Text ($W - 6) }
    $doc = $script:readCache[$key]
    $head = New-Object Collections.ArrayList
    $chips = @(S ' ')
    for ($i = 0; $i -lt $tabs.Count; $i++) {
        if ($i -eq $script:readTab) { $chips += (S " $($tabs[$i].Title) " $st.chipOn) } else { $chips += (S " $($tabs[$i].Title) " $st.chip) }
        $chips += (S ' ')
    }
    $rel = $tab.Path
    if ($rel.StartsWith($Root)) { $rel = $rel.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/') }
    $chips += (S "  $rel" $st.faint)
    [void]$head.Add($chips)
    [void]$head.Add(@())
    # The export's question (x), at the bottom as on Home.
    $bottom = Bottom-Line $W 0
    $bodyRows = $H - 3 - $head.Count - $bottom.Count
    $max = [Math]::Max(0, $doc.Count - $bodyRows)
    if ($script:readScroll -gt $max) { $script:readScroll = $max }
    $lines = New-Object Collections.ArrayList
    foreach ($l in $head) { [void]$lines.Add($l) }
    for ($i = $script:readScroll; $i -lt [Math]::Min($doc.Count, $script:readScroll + $bodyRows); $i++) { [void]$lines.Add(@(S '  ') + @($doc[$i])) }
    $title = Get-ItemTitle $item
    $pos = 'all'
    if ($max -gt 0) { $pos = "$([int][Math]::Round(100 * $script:readScroll / $max))%" }
    $rows = New-Object Collections.ArrayList
    [void]$rows.Add((Border-Top $W "$projectName $($g.mid) $title" "$($doc.Count) lines $($g.mid) $pos" 0))
    foreach ($r in (Full-Rows ($H - 3 - $bottom.Count) $W $lines)) { [void]$rows.Add($r) }
    foreach ($r in $bottom) { [void]$rows.Add($r) }
    [void]$rows.Add((Border-Line $W $g.lt $g.h $g.rt 0 ''))
    if ($script:choose) { $hints = Home-Hints }
    else {
        $hints = @(@("$($g.up)$($g.down) PgUp PgDn", 'scroll'), @('Home End', 'top, end'))
        if ($tabs.Count -gt 1) { $hints += , @("$([string][char]0x2190)$([string][char]0x2192)", 'document') }
        $hints += , @('x', 'export'); $hints += , @('e', 'edit'); $hints += , @('?', 'help'); $hints += , @('Esc', 'back')
    }
    [void]$rows.Add((Border-Bottom $W $hints 0))
    return , $rows
}

# Several changes as one (m on Home; x, chosen changes): the saved wholes, then the changes to mark; then
# read or export them as one whole.
function Get-PickRows($P) {
    $rows = @()
    foreach ($bd in @(Get-Bundles)) {
        $found = @(foreach ($n in $bd.Changes) { Find-Change $n $script:changes })
        $rows += [pscustomobject]@{ Kind = 'bundle'; Bundle = $bd; Found = $found; Missing = $bd.Changes.Count - $found.Count }
    }
    foreach ($c in $P.Items) { $rows += [pscustomobject]@{ Kind = 'change'; Change = $c } }
    if ($P.Index -ge $rows.Count) { $P.Index = [Math]::Max(0, $rows.Count - 1) }
    return $rows
}
function Draw-Pick([int]$W, [int]$H) {
    $p = $script:pick
    $all = @(Get-PickRows $p)
    $lines = New-Object Collections.ArrayList
    [void]$lines.Add(@())
    $then = 'read them'
    if ($p.Then -ne 'read') { $then = "export them as one $($p.Then.ToUpper())" }
    foreach ($l in (Wrap "The changes that go to the client as one whole: a chapter per kind of document (proposal, specs, design, tasks ...), each change's part under its title. A saved whole: Enter. Else mark the changes, then Enter: a title for the whole (and save it for next time?), then $then." ($W - 8))) { [void]$lines.Add(@(S "  $l" $st.muted)) }
    $tw = [Math]::Max(10, $W - 24)
    $at = 0
    $kind = ''
    for ($i = 0; $i -lt $all.Count; $i++) {
        $r = $all[$i]
        if ($r.Kind -ne $kind) {
            $kind = $r.Kind
            [void]$lines.Add(@())
            if ($kind -eq 'bundle') { [void]$lines.Add(@((S '  SAVED ' $st.title), (S "$($g.mid) openspec/config.yaml lazyspec: bundles:" $st.faint))) }
            else { [void]$lines.Add(@((S '  CHANGES ' $st.title), (S "$($g.mid) $($p.Items.Count) active" $st.faint))) }
        }
        $mark = '  '
        $style = $st.text
        if ($i -eq $p.Index) { $mark = "$($g.tri) "; $style = $st.bold; $at = $lines.Count }
        if ($r.Kind -eq 'bundle') {
            $title = $r.Bundle.Title
            if (-not $title) { $title = $r.Bundle.Id }
            $note = "$($r.Found.Count) changes"
            if ($r.Missing) { $note += ", $($r.Missing) not found" }
            [void]$lines.Add(@((S "  $mark" $st.accent), (S "$($g.diamond) " $st.shared), (S (Pad (Short $title $tw) $tw) $style), (S (PadL $note 11) $st.muted)))
            continue
        }
        $c = $r.Change
        $box = S '[ ] ' $st.faint
        if ($p.Marked[$c.Name]) { $box = S "[$($g.check)] " $st.ok }
        $look = $stageLook[$c.Stage]
        [void]$lines.Add(@((S "  $mark" $st.accent), $box, (S "$($look[0]) " $look[1]), (S (Pad (Short (Get-ItemTitle $c) ($tw - 4)) ($tw - 4)) $style), (S (PadL "$($c.Done)/$($c.Total)" 7) $st.muted)))
    }
    # The current one stays visible when the list is longer than the screen.
    $bodyRows = $H - 4
    $shown = @($lines)
    if ($at -ge $bodyRows) { $shown = @($lines | Select-Object -Skip ($at - $bodyRows + 1)) }
    $rows = New-Object Collections.ArrayList
    [void]$rows.Add((Border-Top $W "$projectName $($g.mid) changes as one" "$(@($all | Where-Object { $_.Kind -eq 'bundle' }).Count) saved $($g.mid) $($p.Items.Count) active" 0))
    foreach ($r in (Full-Rows $bodyRows $W $shown)) { [void]$rows.Add($r) }
    [void]$rows.Add((Border-Line $W $g.lt $g.h $g.rt 0 ''))
    # A question (remove a saved whole?), else what is marked.
    $q = Bottom-Line $W 0
    if (@($q).Count) { [void]$rows.Add($q[0]) }
    else {
        $names = @($p.Items | Where-Object { $p.Marked[$_.Name] } | ForEach-Object { Get-ItemTitle $_ })
        $foot = @((S " $($names.Count) marked" $st.accent))
        if ($names.Count) { $foot += (S "  $($g.mid)  $($names -join ', ')" $st.muted) }
        foreach ($r in (Full-Rows 1 $W @(, $foot))) { [void]$rows.Add($r) }
    }
    $hints = @(@("$($g.up)$($g.down)", 'select'), @('Space', 'mark'), @('a', 'all, none'), @('Enter', 'go on'))
    if (@($all | Where-Object { $_.Kind -eq 'bundle' }).Count) { $hints += , @('d', 'remove a saved one') }
    if ($script:confirm) { $hints = Home-Hints } else { $hints += , @('Esc', 'cancel') }
    [void]$rows.Add((Border-Bottom $W $hints 0))
    return , $rows
}
function Start-Pick([string]$Then) {
    $list = @(Get-VisibleChanges | Where-Object { -not $_.Archived })
    if ($list.Count -lt 2) { $list = @($script:changes | Where-Object { -not $_.Archived } | Sort-Object Name) }
    if ($list.Count -lt 2 -and -not @(Get-Bundles).Count) { $script:message = 'Changes as one: there are fewer than two active changes.'; return }
    # The last ones marked again (else the selected change).
    $marked = @{}
    foreach ($n in $script:lastPick) { if (@($list | Where-Object { $_.Name -eq $n }).Count) { $marked[$n] = $true } }
    $sel = Get-Selected
    if (-not $marked.Count -and $sel -and $sel.Type -eq 'change') { $marked[$sel.Name] = $true }
    $script:pick = [pscustomobject]@{ Then = $Then; Items = $list; Marked = $marked; Index = 0; Back = $script:screen }
    $script:message = ''
    $script:screen = 'pick'
}
function On-PickKey($K) {
    $p = $script:pick
    $name = $K.Name; $ch = [string]$K.Char
    $script:message = ''
    $all = @(Get-PickRows $p)
    $n = $all.Count
    $row = $all[$p.Index]
    if ($name -eq 'Up' -or $ch -eq 'k') { $p.Index = ($p.Index - 1 + $n) % $n }
    elseif ($name -eq 'Down' -or $ch -eq 'j') { $p.Index = ($p.Index + 1) % $n }
    elseif ($name -eq 'Home') { $p.Index = 0 }
    elseif ($name -eq 'End') { $p.Index = $n - 1 }
    elseif ($name -eq 'Space') {
        # A saved whole: its changes marked (to change them, then Enter).
        if ($row.Kind -eq 'bundle') {
            $p.Marked = @{}
            foreach ($c in $row.Found) { $p.Marked[$c.Name] = $true }
            $script:lastPickTitle = $row.Bundle.Title
        }
        else { $c = $row.Change; $p.Marked[$c.Name] = -not $p.Marked[$c.Name] }
    }
    elseif ($ch -eq 'a') {
        $every = @($p.Items | Where-Object { $p.Marked[$_.Name] }).Count -eq $p.Items.Count
        foreach ($c in $p.Items) { $p.Marked[$c.Name] = -not $every }
    }
    elseif ($ch -eq 'd' -and $row.Kind -eq 'bundle') {
        $script:confirm = [pscustomobject]@{ Text = "Remove the saved whole '$($row.Bundle.Title)' from openspec/config.yaml?"; Choice = 1; Id = $row.Bundle.Id; Do = {
                param($c)
                Set-ConfigBundle $c.Id '' @()
                $script:message = "Removed $($c.Id) from openspec/config.yaml."
            } }
    }
    elseif ($name -eq 'Enter') {
        if ($row.Kind -eq 'bundle') {
            if (-not $row.Found.Count) { $script:message = "None of $($row.Bundle.Id)'s changes is in openspec/changes."; return }
            $script:pick = $null
            $script:screen = $p.Back
            $script:lastPick = @($row.Found | ForEach-Object { $_.Name })
            $script:lastPickTitle = $row.Bundle.Title
            Use-Pick $p.Then ((@($row.Found | ForEach-Object { $_.Name })) -join ',') $row.Bundle.Title $row.Bundle.Id
            return
        }
        Complete-Pick
    }
    elseif ($name -eq 'Esc' -or $ch -eq 'q') { $script:screen = $p.Back; $script:pick = $null }
}
function Complete-Pick {
    $p = $script:pick
    $names = @($p.Items | Where-Object { $p.Marked[$_.Name] } | ForEach-Object { $_.Name })
    if (-not $names.Count) { $script:message = 'Mark at least one change (Space).'; return }
    $script:pick = $null
    $script:screen = $p.Back
    $script:lastPick = $names
    if ($names.Count -eq 1) { Use-Pick $p.Then $names[0] ''; return }
    # The title: the saved whole's with the same changes, else the last one typed.
    $value = $script:lastPickTitle
    $key = (@($names | Sort-Object) -join ',')
    foreach ($bd in @(Get-Bundles)) { if ((@($bd.Changes | Sort-Object) -join ',') -eq $key) { $value = $bd.Title } }
    $script:input = [pscustomobject]@{ Label = 'Title of the whole:'; Value = $value; Hint = 'on the cover (Enter on nothing: the changes'' titles)'; Free = $true
        Then = $p.Then; Names = ($names -join ','); Do = {
            param($v, $i)
            $script:lastPickTitle = $v
            Start-SaveBundle $i.Then $i.Names $v
        } }
}
# Not saved yet with this title and these changes: save it as a whole for next time?
function Start-SaveBundle([string]$Then, [string]$Names, [string]$Title) {
    $key = (@($Names.Split(',') | Sort-Object) -join ',')
    $same = @(Get-Bundles | Where-Object { (@($_.Changes | Sort-Object) -join ',') -eq $key -and $_.Title -eq $Title })
    if ($same.Count -or -not $Title -or -not (Get-Slug $Title)) { $id = ''; if ($same.Count) { $id = $same[0].Id }; Use-Pick $Then $Names $Title $id; return }
    $id = Get-Slug $Title
    $script:choose = [pscustomobject]@{ Text = "Save it as '$id' in openspec/config.yaml?"; Options = @('Save it', 'Not now'); Short = @('save', 'not now'); Keys = @('s', 'n'); Choice = 0
        Then = $Then; Names = $Names; Title = $Title; Id = $id; Do = {
            param($k, $c)
            $saved = ''
            if ($k -eq 0) {
                try { Set-ConfigBundle $c.Id $c.Title $c.Names.Split(','); $saved = $c.Id }
                catch { $script:message = "Not saved: $($_.Exception.Message)" }
            }
            Use-Pick $c.Then $c.Names $c.Title $saved
            if ($saved) { $script:message = "Saved as $saved (openspec/config.yaml lazyspec: bundles:)." }
        } }
}
function Use-Pick([string]$Then, [string]$Names, [string]$Title, [string]$Id) {
    # A saved whole: exported by its key (-Item <key>), so the file has its name.
    if ($Then -ne 'read') {
        if ($Id -and @(Get-Bundles | Where-Object { $_.Id -eq $Id -and $_.Title -eq $Title }).Count) { Start-ExportAudience $Then $false $Id ''; return }
        Start-ExportAudience $Then $false $Names $Title; return
    }
    $list = @(foreach ($n in $Names.Split(',')) { Find-Change $n $script:changes })
    $item = $list[0]
    if ($list.Count -gt 1) { $item = Get-ChangeBundle $list $Title $Id }
    $script:readItem = $item; $script:readTab = 0; $script:readScroll = 0; $script:screen = 'read'
}

# --- the OpenSpec CLI ----------------------------------------------------------------------------------

# The command and how to start it (npm puts openspec.cmd on Windows: it runs through cmd.exe).
function Resolve-OpenSpec {
    $cmd = Get-Command openspec -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) { return $null }
    return [string]$cmd.Source
}
function Quote-Arg([string]$A) { if ($A -match '[\s"]') { return '"' + $A.Replace('"', '\"') + '"' } return $A }
function Start-Cli([string]$Label, [string[]]$CliArgs) {
    $tool = Resolve-OpenSpec
    New-Run $Label "openspec $($CliArgs -join ' ')"
    if (-not $tool) {
        Add-RunLog "$($g.cross) The OpenSpec CLI isn't installed (or not on PATH): npm install -g @fission-ai/openspec" $st.err
        $script:run.Done = $true; $script:run.Watch.Stop(); return
    }
    $argLine = (@($CliArgs) | ForEach-Object { Quote-Arg $_ }) -join ' '
    if ($tool -match '\.(cmd|bat)$') {
        $shell = $env:ComSpec
        if (-not $shell) { $shell = 'cmd.exe' }
        Start-RunProcess $shell "/d /s /c `"`"$tool`" $argLine`""
    } else { Start-RunProcess $tool $argLine }
}
# Export in the run screen: this script again, in a PowerShell of its own (-Export), its output shown here.
function Start-Export([string]$Format, [bool]$WithChanges, [string]$ItemName, [bool]$Friendly, [string]$Diagrams, [string]$Title) {
    $cliArgs = @('-Root', $Root, '-Export', $Format)
    if ($ItemName) { $cliArgs += @('-Item', $ItemName) }
    if ($Title) { $cliArgs += @('-Title', $Title) }
    if ($WithChanges) { $cliArgs += '-IncludeChanges' }
    if ($Friendly) { $cliArgs += '-ClientFriendly' }
    if ($Diagrams -eq 'refresh') { $cliArgs += '-RefreshDiagrams' } elseif ($Diagrams -eq 'keep') { $cliArgs += '-KeepDiagrams' }
    if (-not $harness) { $cliArgs += '-Open' }
    $label = "Export $Format"
    if ($ItemName.Contains(',')) { $label += " ($(@($ItemName.Split(',')).Count) changes as one)" }
    elseif ($ItemName) { $label += " ($ItemName)" }
    if ($WithChanges) { $label += ' (with the plan)' }
    if ($Friendly) { $label += ', client-friendly' }
    New-Run $label "lazyspec $(($cliArgs | Where-Object { $_ -ne $Root -and $_ -ne '-Root' }) -join ' ')"
    # What r (retry) runs again when it fails.
    $script:run | Add-Member -NotePropertyName Retry -NotePropertyValue ([pscustomobject]@{ Format = $Format; WithChanges = $WithChanges; Item = $ItemName; Friendly = $Friendly; Diagrams = $Diagrams; Title = $Title })
    $ps = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    Start-RunProcess $ps ("-NoProfile -ExecutionPolicy Bypass -File $(Quote-Arg $PSCommandPath) " + ((@($cliArgs) | ForEach-Object { Quote-Arg $_ }) -join ' '))
}
function New-Run([string]$Label, [string]$Command) {
    $script:run = [pscustomobject]@{
        Label = $Label; Command = $Command; Proc = $null; Out = $null; Err = $null; OutDone = $false; ErrDone = $false
        Log = (New-Object Collections.ArrayList); Version = 0; Lines = $null; LinesKey = ''; Scroll = 0; Done = $false; Code = $null
        Watch = [Diagnostics.Stopwatch]::StartNew(); ConfirmStop = $false; Stopped = $false; Back = $script:screen
    }
    $script:screen = 'run'
    Add-RunLog "$($g.caret) $Command" $st.muted
    Add-RunLog '' ''
}
function Start-RunProcess([string]$FileName, [string]$Arguments) {
    $run = $script:run
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = $FileName
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = $Root
    try { $psi.EnvironmentVariables['NO_COLOR'] = '1'; $psi.EnvironmentVariables['FORCE_COLOR'] = '0' } catch { }
    try {
        $run.Proc = [Diagnostics.Process]::Start($psi)
        $run.Proc.StandardInput.Close()
        $run.Out = $run.Proc.StandardOutput.ReadLineAsync()
        $run.Err = $run.Proc.StandardError.ReadLineAsync()
    } catch {
        Add-RunLog "$($g.cross) Can't start $(Split-Path $FileName -Leaf): $($_.Exception.Message)" $st.err
        $run.Done = $true; $run.Watch.Stop()
    }
}
function Add-RunLog([string]$Text, [string]$Style) {
    [void]$script:run.Log.Add([pscustomobject]@{ T = $Text; S = $Style })
    $script:run.Version++
}
# One line of the CLI's output, coloured by what it says.
function Add-CliLine([string]$Line, [bool]$IsErr) {
    $t = [regex]::Replace($Line, "$E\[[0-9;?]*[A-Za-z]", '')
    $t = $t.TrimEnd()
    if (-not $t.Trim()) { Add-RunLog '' ''; return }
    $first = $t.TrimStart()
    $style = $st.text
    $okMarks = @((C 0x2713), (C 0x2714), (C 0x2705))
    $errMarks = @((C 0x2717), (C 0x2718), (C 0x274C), (C 0x2716))
    $warnMarks = @((C 0x26A0))
    if ($okMarks | Where-Object { $first.StartsWith($_) }) { $style = $st.ok }
    elseif ($errMarks | Where-Object { $first.StartsWith($_) }) { $style = $st.err }
    elseif (($warnMarks | Where-Object { $first.StartsWith($_) }) -or $first -match '^\[?WARN') { $style = $st.warn }
    elseif ($first -match '^\[?(ERROR|Error)') { $style = $st.err }
    elseif ($first -match '^\[?INFO' -or $first.StartsWith((C 0x2139))) { $style = $st.muted }
    elseif ($first -match '^Totals:') { $style = $st.bold }
    elseif ($IsErr) { $style = $st.warn }
    Add-RunLog $t $style
}
function Update-Run {
    $run = $script:run
    if (-not $run -or -not $run.Proc) { return }
    $changed = $false
    while (-not $run.OutDone -and $run.Out.IsCompleted) {
        $line = $run.Out.Result
        if ($null -eq $line) { $run.OutDone = $true; break }
        Add-CliLine $line $false
        $changed = $true
        $run.Out = $run.Proc.StandardOutput.ReadLineAsync()
    }
    while (-not $run.ErrDone -and $run.Err.IsCompleted) {
        $line = $run.Err.Result
        if ($null -eq $line) { $run.ErrDone = $true; break }
        Add-CliLine $line $true
        $changed = $true
        $run.Err = $run.Proc.StandardError.ReadLineAsync()
    }
    if (-not $run.Done -and $run.OutDone -and $run.ErrDone -and $run.Proc.HasExited) {
        $run.Done = $true
        $run.Watch.Stop()
        $run.Code = $run.Proc.ExitCode
        Reload
        $changed = $true
    }
    if ($changed) { $script:dirty = $true }
}
function Stop-Run {
    $p = $script:run.Proc
    if ($p -and -not $p.HasExited) {
        Stop-ProcessTree $p
    }
    Add-RunLog "$($g.cross) Stopped." $st.err
    $script:run.Done = $true
    $script:run.Stopped = $true
    $script:run.Watch.Stop()
}
function Get-RunLines([int]$Width) {
    $run = $script:run
    $key = "$($run.Version)/$Width"
    if ($run.LinesKey -eq $key) { return , $run.Lines }
    $lines = New-Object Collections.ArrayList
    foreach ($entry in $run.Log) {
        if (-not $entry.T) { [void]$lines.Add(@()); continue }
        foreach ($l in (Wrap $entry.T $Width)) { [void]$lines.Add(@(S " $l" $entry.S)) }
    }
    $run.Lines = $lines
    $run.LinesKey = $key
    return , $lines
}
function Draw-Run([int]$W, [int]$H) {
    $run = $script:run
    $prompt = New-Object Collections.ArrayList
    if ($run.ConfirmStop) {
        [void]$prompt.Add(@((S ' ? ' $st.key), (S 'Stop it? ' $st.bold), (S ' y ' $st.chipDanger), (S ' '), (S ' n ' $st.chip)))
        $hints = @(@('y', 'stop'), @('n Esc', 'go on'))
    } elseif ($run.Done) {
        if ($run.Stopped) { [void]$prompt.Add(@((S " $($g.cross) " $st.err), (S 'Stopped.' $st.err))) }
        elseif ($run.Code -eq 0) { [void]$prompt.Add(@((S " $($g.check) " $st.ok), (S "$($run.Label): done." "1;$($st.ok)"))) }
        elseif ($null -eq $run.Code) { [void]$prompt.Add(@((S " $($g.cross) " $st.err), (S "$($run.Label): didn't start." $st.err))) }
        else { [void]$prompt.Add(@((S ' ! ' $st.warn), (S "$($run.Label): ended with exit code $($run.Code)." $st.warn))) }
        $hints = @(@('Enter Esc', 'back'), @('PgUp PgDn Home End', 'scroll'))
        if ($run.Code -ne 0 -and $run.PSObject.Properties['Retry'] -and $run.Retry) {
            [void]$prompt.Add(@((S ' r ' $st.key), (S 'retry (after closing the file, if it was open)' $st.muted)))
            $hints = @(, @('r', 'retry')) + $hints
        }
    } else {
        $spin = $spinner[$script:tick % $spinner.Count]
        [void]$prompt.Add(@((S " $spin " $st.accent), (S "working $($g.mid) $($run.Label)" $st.bold)))
        $hints = @(@('PgUp PgDn', 'scroll'), @('Esc', 'stop'))
    }
    $bodyRows = $H - 5
    $logLines = Get-RunLines ($W - 4)
    $max = [Math]::Max(0, $logLines.Count - $bodyRows)
    if ($run.Scroll -gt $max) { $run.Scroll = $max }
    $start = $max - $run.Scroll
    $body = @()
    for ($i = $start; $i -lt [Math]::Min($logLines.Count, $start + $bodyRows); $i++) { $body += , $logLines[$i] }
    $el = $run.Watch.Elapsed
    $status = "$([int]$el.TotalMinutes):$($el.Seconds.ToString('00'))"
    if ($run.Scroll) { $status = "$($g.up) $($run.Scroll) lines  $($g.mid)  $status" }
    $rows = New-Object Collections.ArrayList
    [void]$rows.Add((Border-Top $W "$projectName $($g.mid) $($run.Label)" $status 0))
    foreach ($r in (Full-Rows $bodyRows $W $body)) { [void]$rows.Add($r) }
    [void]$rows.Add((Border-Line $W $g.lt $g.h $g.rt 0 ''))
    foreach ($r in (Full-Rows 1 $W $prompt)) { [void]$rows.Add($r) }
    [void]$rows.Add((Border-Bottom $W $hints 0))
    return , $rows
}

# --- the editor ----------------------------------------------------------------------------------------

function Open-InEditor([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { $script:message = "Nothing to open: $Path"; return }
    if ($harness) { $script:message = "would open $Path"; return }
    $editor = $env:VISUAL
    if (-not $editor) { $editor = $env:EDITOR }
    if ($editor) {
        # A terminal editor gets the console: leave the UI's screen, edit, come back.
        [Console]::Out.Write("$E[0m$E[?25h$E[?1049l")
        try { & cmd.exe /c "$editor `"$Path`"" } catch { try { & $editor $Path } catch { } }
        [Console]::Out.Write("$E[?1049h$E[?25l$E[2J")
        $script:prev = @()
        Reload
        return
    }
    $code = Get-Command code -ErrorAction SilentlyContinue | Select-Object -First 1
    try {
        if ($code) {
            # -WindowStyle exists only on Windows (macOS: an error).
            if ($env:OS -eq 'Windows_NT') { Start-Process -FilePath $code.Source -ArgumentList @("`"$Path`"") -WindowStyle Hidden }
            else { Start-Process -FilePath $code.Source -ArgumentList @("`"$Path`"") }
            $script:message = "Opened in VS Code: $Path"
        }
        else { Invoke-Item -LiteralPath $Path; $script:message = "Opened: $Path" }
    } catch { $script:message = "Can't open $Path`: $($_.Exception.Message)" }
}

# --- other screens -------------------------------------------------------------------------------------

function Draw([int]$W, [int]$H) {
    if ($W -lt 70 -or $H -lt 20) {
        $rows = @()
        for ($i = 0; $i -lt $H; $i++) { $rows += , @(S '') }
        $rows[0] = Fit @(S "lazyspec needs a window of at least 70 x 20 (now $W x $H)." $st.warn) $W
        return , $rows
    }
    switch ($script:screen) {
        'none' { return Draw-None $W $H }
        'help' { return Draw-Help $W $H }
        'read' { return Draw-Read $W $H }
        'pick' { return Draw-Pick $W $H }
        'run' { return Draw-Run $W $H }
        default { return Draw-Home $W $H }
    }
}

$script:helpScroll = 0
function Draw-Help([int]$W, [int]$H) {
    $lines = New-Object Collections.ArrayList
    [void]$lines.Add(@())
    [void]$lines.Add(@((S ' '), (S $g.bar $st.brandBar), (S 'LazySpec ' $st.brandName), (S "$kitVersion  " $st.faint), (S 'by ' $st.faint), (S 'Netmedia' $st.netmedia 'https://netmedia.agency')))
    [void]$lines.Add(@((S ' '), (S $g.bar $st.brandBar), (S 'https://netmedia.agency' $st.brandLink 'https://netmedia.agency'), (S '  |  ' $st.faint), (S 'netmedia@netmedia.hr' $st.brandLink 'mailto:netmedia@netmedia.hr'), (S '  |  ' $st.faint), (S 'https://github.com/netmedia/lazyspec' $st.brandLink 'https://github.com/netmedia/lazyspec')))
    [void]$lines.Add(@())
    foreach ($l in (Wrap 'A project''s OpenSpec in one screen: the specifications (openspec/specs) with their requirements, the changes (openspec/changes) with their stage, task progress, capabilities and tasks, each readable in full. The OpenSpec CLI does validate, archive and new change; LazySpec shows its output.' ($W - 8))) { [void]$lines.Add(@(S "  $l")) }
    [void]$lines.Add(@())
    $section = {
        param([string]$Title, $Rows)
        [void]$lines.Add(@(S "  $Title" $st.title))
        foreach ($r in $Rows) { [void]$lines.Add(@((S ('    ' + (Pad $r[0] 14)) $st.key), (S $r[1] $st.text))) }
        [void]$lines.Add(@())
    }
    & $section 'HOME' @(
        @("$($g.up) $($g.down)", 'select a spec or a change (in the details: scroll)'), @('Tab', 'scope (specifications) <-> plan (changes)'),
        @("$([string][char]0x2192) l", 'into the details (then up/down scroll them)'), @("$([string][char]0x2190) Esc", 'back to the lists'),
        @('z', 'zoom: the details over the whole width (z again or Esc: the lists back)'),
        @('PgUp PgDn', 'scroll the details a page (Home, End: top, end)'), @('Enter', 'read it in full'), @('v', 'validate all (openspec validate --all --strict)'),
        @('a', 'archive the selected change (asked first; merges its delta specs into openspec/specs)'),
        @('n', 'new change (asks its name: kebab-case, e.g. add-user-login)'),
        @('x', 'export the specification for the client: PDF, Word or HTML (export\ in the project; opens it)'),
        @('m', 'changes as one: mark the ones that go to the client as one whole, read them together (x there: export)'), @('e', 'edit: open the spec or the proposal in your editor'),
        @('s', 'sort changes: name A-Z, name Z-A, recently modified'), @('h', 'show or hide archived changes'),
        @('/', 'filter specs and changes by name (Enter keeps it, Esc clears it)'), @('r', 'refresh (it also refreshes by itself when files change)'),
        @('?', 'this help'), @('q', 'quit'))
    & $section 'READ' @(
        @("$($g.up) $($g.down)", 'scroll a line'), @('PgUp PgDn', 'scroll a page'), @('Home End', 'top, end'),
        @("$([string][char]0x2190) $([string][char]0x2192)", 'the change''s documents (its workflow''s: proposal, delta specs, design, tasks...)'), @('x', 'export this spec, change or changes as one: PDF, Word or HTML'), @('e', 'edit this document'), @('Esc', 'back'))
    & $section 'RUN' @(@('PgUp PgDn', 'scroll the output (Home, End: top, bottom)'), @('Esc', 'stop (asked first); when done: back'))
    & $section 'LOOK' @(
        @("$($g.diamond) $($g.dot)", 'a platform page (platform-*: overview, costs...), a capability spec'),
        @("$($g.ring) $($g.diamond) $($g.dot) $($g.mid)", 'a change: draft (no tasks), in progress, completed, archived'),
        @('+ ~ -', 'requirements a change adds, modifies, removes in a capability'))
    & $section 'THE SAME WITHOUT THE UI' @(
        @('v', 'openspec validate --all --strict'), @('a', 'openspec archive <change> --yes'), @('n', 'openspec new change <name>'), @('x', 'lazyspec -Export Pdf|Word|Html [-IncludeChanges] [-Out <file>] [-Open]'), @('m, x', 'lazyspec -Export Word -Item <change>,<change> -Title "<the whole''s title>"'),
        @('everything', '.\tools\lazyspec\lazyspec.ps1 -Help   and   tools\lazyspec\LAZYSPEC.md'))
    $bodyRows = $H - 2
    $max = [Math]::Max(0, $lines.Count - $bodyRows)
    if ($script:helpScroll -gt $max) { $script:helpScroll = $max }
    $shown = @()
    for ($i = $script:helpScroll; $i -lt $lines.Count; $i++) { $shown += , $lines[$i] }
    $rows = New-Object Collections.ArrayList
    [void]$rows.Add((Border-Top $W 'help' 'by Netmedia' 0))
    foreach ($r in (Full-Rows $bodyRows $W $shown)) { [void]$rows.Add($r) }
    [void]$rows.Add((Border-Bottom $W @(@('PgUp PgDn', 'scroll'), @('Esc ?', 'back')) 0))
    return , $rows
}

# No openspec/ here: what this is and how to start.
function Draw-None([int]$W, [int]$H) {
    $lines = New-Object Collections.ArrayList
    [void]$lines.Add(@())
    [void]$lines.Add(@(S '  NO OPENSPEC HERE' $st.title))
    [void]$lines.Add(@())
    $where = (Get-Location).Path
    if ($Root) { $where = $Root }
    foreach ($l in (Wrap "There is no openspec folder in $where or above it (nor above $kitDir). LazySpec shows a project's OpenSpec specifications and changes; start one in the project's root:" ($W - 8))) { [void]$lines.Add(@(S "  $l")) }
    [void]$lines.Add(@())
    [void]$lines.Add(@(S '    npm install -g @fission-ai/openspec' $st.ok))
    [void]$lines.Add(@(S '    openspec init' $st.ok))
    [void]$lines.Add(@())
    foreach ($l in (Wrap 'Or point LazySpec at a project: .\tools\lazyspec\lazyspec.ps1 -Root <the project''s root>' ($W - 8))) { [void]$lines.Add(@(S "  $l" $st.muted)) }
    $rows = New-Object Collections.ArrayList
    [void]$rows.Add((Border-Top $W 'no openspec' $where 0))
    foreach ($r in (Full-Rows ($H - 2) $W $lines)) { [void]$rows.Add($r) }
    [void]$rows.Add((Border-Bottom $W @(@('?', 'help'), @('q', 'quit')) 0))
    return , $rows
}

# --- keys ----------------------------------------------------------------------------------------------

function Move-Selection([int]$Delta) {
    if ($script:focus -eq 'specs') {
        $n = @(Get-VisibleSpecs).Count
        if ($n) { $script:specIndex = ($script:specIndex + $Delta + $n) % $n }
    } else {
        $n = @(Get-VisibleChanges).Count
        if ($n) { $script:changeIndex = ($script:changeIndex + $Delta + $n) % $n }
    }
    $script:detailScroll = 0
}
function Start-Archive {
    $sel = Get-Selected
    if (-not $sel -or $sel.Type -ne 'change') { $script:message = 'Select a change first (Tab to the changes).'; return }
    if ($sel.Archived) { $script:message = "$($sel.Name) is archived already."; return }
    $text = "Archive $($sel.Name)?"
    if ($sel.Total -and $sel.Done -lt $sel.Total) { $text = "Archive $($sel.Name)? $($sel.Total - $sel.Done) of $($sel.Total) tasks are still open." }
    $name = $sel.Name
    # No GetNewClosure: its scriptblock can't see this script's functions when lazyspec.exe starts it. The question carries its data.
    $script:confirm = [pscustomobject]@{ Text = $text; Choice = 1; Name = $name; Do = { param($c) Start-Cli "Archive $($c.Name)" @('archive', $c.Name, '--yes') } }
}
function Start-NewChange {
    $script:input = [pscustomobject]@{ Label = 'New change:'; Value = ''; Hint = 'kebab-case, e.g. add-user-login'; Do = {
            param($v)
            if ($v -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { $script:message = "'$v' isn't kebab-case (lowercase words with hyphens)."; return }
            Start-Cli "New change $v" @('new', 'change', $v)
        } }
}
# x: the specification as a document for the client: the format, then (with active changes) whether the plan goes in.
function Start-ExportMenu {
    # No specs yet: the selected change alone (as x in Read), or chosen changes as one.
    if (-not $script:specs.Count) {
        $sel = Get-Selected
        $active = @($script:changes | Where-Object { -not $_.Archived }).Count
        if ($active -ge 2) {
            $name = ''
            if ($sel -and $sel.Type -eq 'change') { $name = $sel.Name }
            $script:choose = [pscustomobject]@{ Text = 'Export as'; Options = @('PDF', 'Word', 'HTML'); Keys = @('p', 'w', 'h'); Choice = 0; Item = $name; Do = {
                    param($i, $c)
                    $format = @('Pdf', 'Word', 'Html')[$i]
                    if (-not $c.Item) { Start-Pick $format; return }
                    $script:choose = [pscustomobject]@{ Text = "$($format.ToUpper()):"; Options = @("The change $($c.Item)", 'Chosen changes, as one'); Short = @('this change', 'chosen changes'); Keys = @('t', 'c'); Choice = 0; Format = $format; Item = $c.Item; Do = {
                            param($j, $c)
                            if ($j -eq 1) { Start-Pick $c.Format; return }
                            Start-ExportAudience $c.Format $false $c.Item
                        } }
                } }
            return
        }
        if ($sel -and $sel.Type -eq 'change') { Start-ItemExportMenu $sel; return }
        $script:message = 'openspec/specs has no specs yet: select a change to export it.'; return
    }
    $script:choose = [pscustomobject]@{ Text = 'Export the specification as'; Options = @('PDF', 'Word', 'HTML'); Keys = @('p', 'w', 'h'); Choice = 0; Do = {
            param($i)
            $format = @('Pdf', 'Word', 'Html')[$i]
            $active = @($script:changes | Where-Object { -not $_.Archived }).Count
            if (-not $active) { Start-ExportAudience $format $false ''; return }
            $opts = @('Specs only', "Specs + the plan ($active changes)"); $short = @('specs only', 'with the plan'); $keys = @('s', 'p')
            # Changes that go to the client as one whole: picked, alone in the document.
            if ($active -ge 2) { $opts += 'Chosen changes, as one'; $short += 'chosen changes'; $keys += 'c' }
            $script:choose = [pscustomobject]@{ Text = "$($format.ToUpper()):"; Options = $opts; Short = $short; Keys = $keys; Choice = 0; Format = $format; Do = {
                    param($j, $c)
                    if ($j -eq 2) { Start-Pick $c.Format; return }
                    Start-ExportAudience $c.Format ($j -eq 1) ''
                } }
        } }
}
# x in the read screen: what is being read, alone: the spec, or the change with all its workflow's documents.
function Start-ItemExportMenu($Item) {
    $what = 'the spec'
    if ($Item.Type -eq 'change') { $what = 'the change' }
    $name = $Item.Name
    $label = $name
    $title = ''
    if ($Item.Type -eq 'bundle') {
        $what = "$($Item.Members.Count) changes as one:"; $label = $Item.Title; $title = $Item.Title
        if ($Item.Id) { $name = $Item.Id; $title = '' }
    }
    $script:choose = [pscustomobject]@{ Text = "Export $what $label as"; Options = @('PDF', 'Word', 'HTML'); Keys = @('p', 'w', 'h'); Choice = 0; Item = $name; Title = $title; Do = {
            param($i, $c)
            Start-ExportAudience @('Pdf', 'Word', 'Html')[$i] $false $c.Item $c.Title
        } }
}
# The export's last question: for the client (scenarios as sentences) or as written.
function Start-ExportAudience([string]$Format, [bool]$WithChanges, [string]$ItemName, [string]$Title) {
    $script:choose = [pscustomobject]@{ Text = "$($Format.ToUpper()) for:"; Options = @('The client (scenarios as sentences)', 'Technical (as written)'); Short = @('client', 'technical'); Keys = @('c', 't'); Choice = 0
        Format = $Format; WithChanges = $WithChanges; Item = $ItemName; Title = $Title; Do = {
            param($k, $c)
            Start-ExportDiagrams $c.Format $c.WithChanges $c.Item ($k -eq 0) $c.Title
        } }
}
# With a Figma token and diagrams in the config: the latest from Figma, or the saved ones? Else straight on.
function Start-ExportDiagrams([string]$Format, [bool]$WithChanges, [string]$ItemName, [bool]$Friendly, [string]$Title) {
    $script:projectConfig = $null
    if (-not ((Test-Diagrams) -and (Get-FigmaToken))) { Start-Export $Format $WithChanges $ItemName $Friendly 'keep' $Title; return }
    $script:choose = [pscustomobject]@{ Text = 'Diagrams:'; Options = @('Download the latest from Figma', 'Use the saved ones'); Short = @('download', 'saved'); Keys = @('d', 's'); Choice = 0
        Format = $Format; WithChanges = $WithChanges; Item = $ItemName; Friendly = $Friendly; Title = $Title; Do = {
            param($k, $c)
            Start-Export $c.Format $c.WithChanges $c.Item $c.Friendly (@('refresh', 'keep')[$k]) $c.Title
        } }
}
function On-Key($K) {
    $name = $K.Name
    $ch = $K.Char
    $script:dirty = $true
    if ($name -eq 'CtrlC') {
        if ($script:screen -eq 'run' -and -not $script:run.Done) { $script:run.ConfirmStop = $true; return }
        $script:quit = $true; return
    }
    if ($script:screen -eq 'help') {
        if ($name -eq 'PgDn' -or $name -eq 'Down') { $script:helpScroll += 10 }
        elseif ($name -eq 'PgUp' -or $name -eq 'Up') { $script:helpScroll = [Math]::Max(0, $script:helpScroll - 10) }
        elseif ($name -eq 'Esc' -or $name -eq 'Enter' -or ([string]$ch) -in @('?', 'q')) { $script:screen = $script:helpBack }
        return
    }
    if ($script:screen -eq 'none') {
        if ([string]$ch -eq '?') { $script:helpBack = 'none'; $script:helpScroll = 0; $script:screen = 'help'; return }
        if (([string]$ch).ToLower() -eq 'q' -or $name -eq 'Esc') { $script:quit = $true }
        return
    }
    # A question at the bottom of Home: yes / no.
    if ($script:confirm) {
        $c = $script:confirm
        $lc = ([string]$ch).ToLower()
        if ($name -eq 'Left' -or $name -eq 'Right' -or $name -eq 'Tab') { $c.Choice = 1 - $c.Choice; return }
        if ($name -eq 'Esc' -or $lc -eq 'n') { $script:confirm = $null; return }
        if ($lc -eq 'y' -or ($name -eq 'Enter' -and $c.Choice -eq 0)) { $script:confirm = $null; & $c.Do $c; return }
        if ($name -eq 'Enter') { $script:confirm = $null }
        return
    }
    # A choice at the bottom of Home: left/right or its letter, Enter.
    if ($script:choose) {
        $c = $script:choose
        $lc = ([string]$ch).ToLower()
        $n = $c.Options.Count
        if ($name -eq 'Left') { $c.Choice = ($c.Choice - 1 + $n) % $n; return }
        if ($name -eq 'Right' -or $name -eq 'Tab') { $c.Choice = ($c.Choice + 1) % $n; return }
        if ($name -eq 'Esc') { $script:choose = $null; return }
        $pick = -1
        if ($name -eq 'Enter') { $pick = $c.Choice } elseif ($lc) { $pick = [array]::IndexOf($c.Keys, $lc) }
        if ($pick -ge 0) { $script:choose = $null; & $c.Do $pick $c }
        return
    }
    # A text answer at the bottom of Home.
    if ($script:input) {
        $i = $script:input
        if ($name -eq 'Esc') { $script:input = $null; return }
        # Free text (a title): as typed, and Enter on nothing goes on too. Else a name: kebab-case as typed.
        $free = [bool]$i.PSObject.Properties['Free']
        if ($name -eq 'Enter') { $script:input = $null; if ($i.Value -or $free) { & $i.Do $i.Value.Trim() $i }; return }
        if ($name -eq 'Back') { if ($i.Value.Length) { $i.Value = $i.Value.Substring(0, $i.Value.Length - 1) }; return }
        if ($name -eq 'Space' -or [string]$ch -eq ' ') { if ($free) { $i.Value += ' ' } else { $i.Value += '-' }; return }
        if ($ch -and [int][char]$ch -ge 32) { if ($free) { $i.Value += [string]$ch } else { $i.Value += ([string]$ch).ToLower() } }
        return
    }
    # Typing a filter.
    if ($script:filtering) {
        if ($name -eq 'Esc') { $script:filter = ''; $script:filtering = $false }
        elseif ($name -eq 'Enter' -or $name -eq 'Tab' -or $name -eq 'Up' -or $name -eq 'Down') { $script:filtering = $false; if ($name -eq 'Up' -or $name -eq 'Down') { On-Key $K } }
        elseif ($name -eq 'Back') { if ($script:filter.Length) { $script:filter = $script:filter.Substring(0, $script:filter.Length - 1) } }
        elseif ($ch -and [int][char]$ch -ge 32) { $script:filter += [string]$ch }
        $script:specIndex = 0; $script:changeIndex = 0; $script:detailScroll = 0
        return
    }
    if ($script:screen -eq 'pick') { On-PickKey $K; return }
    if ([string]$ch -eq '?' -and @('home', 'read') -contains $script:screen) { $script:helpBack = $script:screen; $script:helpScroll = 0; $script:screen = 'help'; return }
    if ($script:screen -eq 'home') {
        $script:message = ''
        $inDetails = $script:zoom -or $script:pane -eq 'details'
        if ($name -eq 'Up') { if ($inDetails) { $script:detailScroll = [Math]::Max(0, $script:detailScroll - 1) } else { Move-Selection -1 }; return }
        if ($name -eq 'Down') { if ($inDetails) { $script:detailScroll++ } else { Move-Selection 1 }; return }
        if ($name -eq 'Tab') {
            if ($script:zoom) { return }
            if ($script:focus -eq 'specs') { $script:focus = 'changes' } else { $script:focus = 'specs' }
            $script:pane = 'list'; $script:detailScroll = 0; return
        }
        if ($name -eq 'Right') { if (-not $script:zoom) { $script:pane = 'details' }; return }
        if ($name -eq 'Left') { if ($script:zoom) { $script:zoom = $false }; $script:pane = 'list'; return }
        if ($name -eq 'PgDn' -or $name -eq 'Space') { $script:detailScroll += 10; return }
        if ($name -eq 'PgUp') { $script:detailScroll = [Math]::Max(0, $script:detailScroll - 10); return }
        if ($name -eq 'Home') { $script:detailScroll = 0; return }
        if ($name -eq 'End') { $script:detailScroll = 1000000; return }
        if ($name -eq 'Enter') {
            $sel = Get-Selected
            if ($sel) { $script:readItem = $sel; $script:readTab = 0; $script:readScroll = 0; $script:screen = 'read' }
            return
        }
        if ($name -eq 'Esc') {
            if ($script:zoom) { $script:zoom = $false; $script:pane = 'list' }
            elseif ($script:pane -eq 'details') { $script:pane = 'list' }
            elseif ($script:filter) { $script:filter = '' }
            return
        }
        switch -CaseSensitive ([string]$ch) {
            'q' { $script:quit = $true }
            'z' { $script:zoom = -not $script:zoom; if ($script:zoom) { $script:pane = 'details' } else { $script:pane = 'list' } }
            'l' { if (-not $script:zoom) { $script:pane = 'details' } }
            'j' { if ($inDetails) { $script:detailScroll++ } else { Move-Selection 1 } }
            'k' { if ($inDetails) { $script:detailScroll = [Math]::Max(0, $script:detailScroll - 1) } else { Move-Selection -1 } }
            'v' { Start-Cli 'Validate all' @('validate', '--all', '--strict', '--no-interactive') }
            'a' { Start-Archive }
            'n' { Start-NewChange }
            'x' { Start-ExportMenu }
            'm' { Start-Pick 'read' }
            'e' { $sel = Get-Selected; if ($sel) { Open-InEditor $sel.Path } }
            's' { $script:sort = $sortModes[([array]::IndexOf($sortModes, $script:sort) + 1) % $sortModes.Count]; $script:changeIndex = 0; $script:message = "Changes sorted by $($sortLabels[$script:sort])." }
            'h' { $script:showArchived = -not $script:showArchived; $script:changeIndex = 0 }
            '/' { $script:filtering = $true; $script:zoom = $false; $script:pane = 'list' }
            'r' { Reload; $script:message = 'Refreshed.' }
        }
        return
    }
    if ($script:screen -eq 'read') {
        $tabs = @(Get-ReadTabs $script:readItem)
        $script:message = ''
        if ($name -eq 'Down') { $script:readScroll++ }
        elseif ($name -eq 'Up') { $script:readScroll = [Math]::Max(0, $script:readScroll - 1) }
        elseif ($name -eq 'PgDn' -or $name -eq 'Space') { $script:readScroll += 20 }
        elseif ($name -eq 'PgUp') { $script:readScroll = [Math]::Max(0, $script:readScroll - 20) }
        elseif ($name -eq 'Home') { $script:readScroll = 0 }
        elseif ($name -eq 'End') { $script:readScroll = 1000000 }
        elseif ($name -eq 'Right' -or $name -eq 'Tab') { $script:readTab = ($script:readTab + 1) % $tabs.Count; $script:readScroll = 0 }
        elseif ($name -eq 'Left') { $script:readTab = ($script:readTab - 1 + $tabs.Count) % $tabs.Count; $script:readScroll = 0 }
        elseif ([string]$ch -eq 'e') { Open-InEditor $tabs[[Math]::Min($script:readTab, $tabs.Count - 1)].Path }
        elseif ([string]$ch -eq 'x') { Start-ItemExportMenu $script:readItem }
        elseif ($name -eq 'Esc' -or $name -eq 'Back' -or ([string]$ch) -in @('q', 'd')) { $script:screen = 'home' }
        return
    }
    # The run.
    $run = $script:run
    if ($name -eq 'PgUp') { $run.Scroll += 10; return }
    if ($name -eq 'PgDn') { $run.Scroll = [Math]::Max(0, $run.Scroll - 10); return }
    if ($name -eq 'End') { $run.Scroll = 0; return }
    if ($name -eq 'Home') { $run.Scroll = 100000; return }
    if ($run.ConfirmStop) {
        if (([string]$ch).ToLower() -eq 'y') { $run.ConfirmStop = $false; Stop-Run }
        elseif ($name -eq 'Esc' -or ([string]$ch).ToLower() -eq 'n' -or $name -eq 'Enter') { $run.ConfirmStop = $false }
        return
    }
    if ($run.Done) {
        # A failed export: the same again (the file was open in another program, Figma didn't answer ...).
        if (([string]$ch).ToLower() -eq 'r' -and $run.Code -ne 0 -and $run.PSObject.Properties['Retry'] -and $run.Retry) {
            $r = $run.Retry
            $back = $run.Back
            Start-Export $r.Format $r.WithChanges $r.Item $r.Friendly $r.Diagrams $r.Title
            $script:run.Back = $back
            return
        }
        if ($name -eq 'Enter' -or $name -eq 'Esc' -or ([string]$ch).ToLower() -eq 'q') { $script:screen = 'home' }
        return
    }
    if ($name -eq 'Esc') { $run.ConfirmStop = $true }
}

$keyNames = @{ UpArrow = 'Up'; DownArrow = 'Down'; LeftArrow = 'Left'; RightArrow = 'Right'; Enter = 'Enter'; Escape = 'Esc'; Tab = 'Tab'; PageUp = 'PgUp'; PageDown = 'PgDn'; Home = 'Home'; End = 'End'; Backspace = 'Back' }
function Read-Keys {
    $out = @()
    while ([Console]::KeyAvailable) {
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'C' -and ($k.Modifiers -band [ConsoleModifiers]::Control)) { $out += [pscustomobject]@{ Name = 'CtrlC'; Char = $null }; continue }
        $name = $keyNames[$k.Key.ToString()]
        if ($k.Key -eq 'Spacebar') { $name = 'Space' }
        $char = $null
        if (-not $name -and $k.KeyChar -ne [char]0) { $char = $k.KeyChar }
        $out += [pscustomobject]@{ Name = $name; Char = $char }
    }
    return $out
}

# --- the screen ----------------------------------------------------------------------------------------

$script:prev = @()
$script:dirty = $true
function Show-Frame($Rows) {
    $sb = New-Object Text.StringBuilder
    for ($i = 0; $i -lt $Rows.Count; $i++) {
        $line = To-Ansi $Rows[$i]
        if ($i -lt $script:prev.Count -and $script:prev[$i] -eq $line) { continue }
        [void]$sb.Append("$E[$($i + 1);1H").Append($line)
        if ($i -lt $script:prev.Count) { $script:prev[$i] = $line }
    }
    if ($script:prev.Count -ne $Rows.Count) { $script:prev = @($Rows | ForEach-Object { To-Ansi $_ }) }
    if ($sb.Length) { [Console]::Out.Write($sb.ToString()); [Console]::Out.Flush() }
}
function Get-Size {
    if ($harness) {
        $w = 120; $h = 36
        if ($Width) { $w = $Width }
        if ($Height) { $h = $Height }
        return @($w, $h)
    }
    return @(([Console]::WindowWidth - 1), [Console]::WindowHeight)
}
function Save-Frame([string]$Why) {
    if (-not $Frames) { return }
    $size = Get-Size
    $rows = Draw $size[0] $size[1]
    $text = "----- $Why -----`n" + ((@($rows | ForEach-Object { (To-Plain $_).TrimEnd() })) -join "`n") + "`n"
    [IO.File]::AppendAllText($Frames, $text, (New-Object Text.UTF8Encoding $false))
}

# The Windows console of PowerShell 5.1 shows ANSI colours once asked to (Windows 10 and later).
function Enable-Ansi {
    if ($PSVersionTable.PSEdition -eq 'Core' -or $env:OS -ne 'Windows_NT') { return }
    try {
        Add-Type -Namespace LazySpec -Name Console -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
'@
        $h = [LazySpec.Console]::GetStdHandle(-11)
        $m = 0
        if ([LazySpec.Console]::GetConsoleMode($h, [ref]$m)) { [void][LazySpec.Console]::SetConsoleMode($h, $m -bor 4) }
    } catch { }
}

$queue = New-Object Collections.Queue
if ($Keys) { foreach ($k in $Keys.Split(',')) { if ($k -ne '') { $queue.Enqueue($k.Trim()) } } }
if ($Frames -and (Test-Path $Frames)) { Remove-Item $Frames }
# One test key (-Keys) as a key, or a wait / snapshot.
function Next-TestKey {
    if (-not $queue.Count) { return $null }
    $k = [string]$queue.Peek()
    if ($k -eq 'wait:done') { if (-not $script:run -or $script:run.Done) { [void]$queue.Dequeue() }; return $null }
    [void]$queue.Dequeue()
    if ($k -eq 'snap') { Save-Frame "snap $($script:screen)"; return $null }
    if ($k.StartsWith('text:')) { foreach ($c in $k.Substring(5).ToCharArray()) { On-Key ([pscustomobject]@{ Name = $null; Char = $c }) }; return $null }
    $names = @('Up', 'Down', 'Left', 'Right', 'Enter', 'Esc', 'Tab', 'PgUp', 'PgDn', 'Home', 'End', 'Back', 'Space', 'CtrlC')
    if ($names -contains $k) { return [pscustomobject]@{ Name = $k; Char = $null } }
    return [pscustomobject]@{ Name = $null; Char = $k[0] }
}

$code = 0
$err = $null
try {
    Reload
    if (-not $harness) {
        Enable-Ansi
        [Console]::OutputEncoding = [Text.Encoding]::UTF8
        [Console]::TreatControlCAsInput = $true
        [Console]::Out.Write("$E[?1049h$E[?25l$E[2J")
    }
    $size = Get-Size
    $lastSpin = [Diagnostics.Stopwatch]::StartNew()
    $lastPoll = [Diagnostics.Stopwatch]::StartNew()
    $limit = [Diagnostics.Stopwatch]::StartNew()
    while (-not $script:quit) {
        if ($script:run -and $script:screen -eq 'run') { Update-Run }
        if ($harness) {
            $k = Next-TestKey
            if ($k) { On-Key $k }
            if (-not $queue.Count) { break }
            if ($limit.Elapsed.TotalMinutes -gt 10) { throw 'test keys: timed out' }
            if (-not $k) { Start-Sleep -Milliseconds 20 }
            continue
        }
        foreach ($k in @(Read-Keys)) { On-Key $k }
        $now = Get-Size
        if ($now[0] -ne $size[0] -or $now[1] -ne $size[1]) { $size = $now; $script:prev = @(); [Console]::Out.Write("$E[2J"); $script:dirty = $true }
        if ($script:screen -eq 'run' -and -not $script:run.Done -and $lastSpin.ElapsedMilliseconds -gt 110) { $script:tick++; $script:dirty = $true; $lastSpin.Restart() }
        # Live refresh: the files changed (an editor, git, an agent): read them again.
        if ($hasRoot -and $script:screen -ne 'run' -and $lastPoll.ElapsedMilliseconds -gt 2000) {
            $lastPoll.Restart()
            $sig = Get-Signature
            if ($sig -ne $script:signature) { Reload; $script:dirty = $true }
        }
        if ($script:dirty) {
            Show-Frame (Draw $size[0] $size[1])
            $script:dirty = $false
        }
        Start-Sleep -Milliseconds 25
    }
    if ($harness) { Save-Frame "end $($script:screen)" }
} catch {
    $code = 1
    $err = $_
} finally {
    if ($script:run -and $script:run.Proc -and -not $script:run.Proc.HasExited) {
        Stop-ProcessTree $script:run.Proc
    }
    if (-not $harness) {
        [Console]::TreatControlCAsInput = $false
        [Console]::Out.Write("$E[0m$E[?25h$E[?1049l")
    }
}
if ($err) { Write-Host "lazyspec: $($err.Exception.Message)" -ForegroundColor Red; Write-Host $err.ScriptStackTrace -ForegroundColor DarkGray }
if (-not $harness) {
    Show-Author
    Write-Host '  .\tools\lazyspec\lazyspec.ps1 -Help: screens, keys and commands   |   tools\lazyspec\LAZYSPEC.md: everything else' -ForegroundColor DarkGray
    Write-Host ''
}
exit $code

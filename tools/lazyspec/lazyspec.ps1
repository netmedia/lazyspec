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

.PARAMETER RefreshDiagrams
-Export: the diagrams ("lazyspec: diagrams:" in openspec/config.yaml, Figma links) the latest from Figma,
through its REST API with a personal access token ("lazyspec: figmaToken:" in config.yaml, or FIGMA_TOKEN).
With a token that is what an export does anyway; when a download fails, the saved image is used.

.PARAMETER KeepDiagrams
-Export: the saved diagrams only, even with a token: no Figma. A diagram without a saved image is left out.

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
    [string]$Item,
    [switch]$IncludeChanges,
    [switch]$ClientFriendly,
    [switch]$RefreshDiagrams,
    [switch]$KeepDiagrams,
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
    & $d '  One document: a cover, the contents, a chapter per spec (in the Scope order); with'
    & $d '  -IncludeChanges the active changes too. Written to export\ in the project (-Out: elsewhere).'
    & $d '  PDF: Edge or Chrome. Word: Microsoft Word, else pandoc. The cover: lazyspec.json "export".'
    & $d '  -ClientFriendly: scenarios as sentences (When x, then y.). In the workflow schema''s language:'
    & $d '  "language: hr" in schema.yaml translates the export''s texts and OpenSpec''s English headings.'
    & $d '  Diagrams: lazyspec: diagrams: in openspec\config.yaml (FigJam links; -RefreshDiagrams, FIGMA_TOKEN).'
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

$globalDir = Join-Path $env:LOCALAPPDATA 'Programs\LazySpec'
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
    $Root = Find-Root (Get-Location).Path
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
# A document's title (its first "# " line) without the project's name in front ("RAGmatic - Costs" -> "Costs").
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
    elseif ($env:LOCALAPPDATA) { $dirs += (Join-Path $env:LOCALAPPDATA 'openspec\schemas') }
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
    if ($Item.Type -eq 'spec') { if ($Item.Title) { return $Item.Title }; return $Item.Short }
    if ($Item.Title) {
        $m = [regex]::Match($Item.Name, '^(\d+)-')
        if ($m.Success) { return "$($m.Groups[1].Value) $($Item.Title)" }
        return $Item.Title
    }
    return $Item.Name
}
function Get-Selected {
    if ($script:focus -eq 'specs') { $vs = @(Get-VisibleSpecs); if ($vs.Count) { return $vs[$script:specIndex] } }
    else { $vc = @(Get-VisibleChanges); if ($vc.Count) { return $vc[$script:changeIndex] } }
    return $null
}

# --- markdown, readable in a terminal -------------------------------------------------------------------

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
        $parts = @($t.Trim('|').Split('|') | ForEach-Object { Plain-Inline $_.Trim() })
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
        if ($table.Count -and ($n -ge $src.Count -or -not $raw.Trim().StartsWith('|'))) { Render-Table $lines $table $Width; $table = @() }
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
# A markdown document as HTML. $Shift: added to every heading's level (a document inside a chapter).
$script:docSeq = 0
function ConvertTo-HtmlBody([string]$Text, [int]$Shift = 0) {
    $out = New-Object Text.StringBuilder
    $src = $Text.Replace("`r", '').Split("`n")
    $para = New-Object Collections.Generic.List[string]
    $table = New-Object Collections.Generic.List[string]
    $quote = New-Object Collections.Generic.List[string]
    $lists = New-Object Collections.ArrayList
    $code = $null
    $gap = $false
    $inScenario = $false
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
        [void]$out.Append("<p$pc>" + (ConvertTo-HtmlInline ($para -join ' ')) + "</p>`n"); $para.Clear()
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
            $rows += , @($r.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        }
        [void]$out.Append("<table>`n")
        if ($head -and @($head | Where-Object { $_ }).Count) { [void]$out.Append('<thead><tr>' + (-join @($head | ForEach-Object { '<th>' + (ConvertTo-HtmlInline $_) + '</th>' })) + "</tr></thead>`n") }
        [void]$out.Append('<tbody>')
        foreach ($r in $rows) { [void]$out.Append('<tr>' + (-join @($r | ForEach-Object { '<td>' + (ConvertTo-HtmlInline $_) + '</td>' })) + "</tr>`n") }
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
                [void]$out.Append("<h$level class=`"$cls`"$id>$mark$(ConvertTo-HtmlInline (Get-ExportHeading $h))</h$level>`n")
                if ($hd -and $hd.Children.Count) { [void]$out.Append((Get-TocHtml $hd.Children)) }
            }
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
            else { [void]$out.Append(' ' + (ConvertTo-HtmlInline $text)) }
            continue
        }
        & $flushQuote
        $para.Add($t.Trim())
    }
    if ($null -ne $code) { [void]$out.Append((ConvertTo-HtmlPre $code)) }
    & $flushSteps
    & $flushTable; & $flushPara; & $flushQuote; & $closeLists -1
    if ($inScenario) { [void]$out.Append("</div>`n") }
    return $out.ToString()
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
    $cfg = @{ Values = @{}; Maps = @{ titles = @{ All = @{}; Groups = @{} }; diagrams = @{ All = @{}; Groups = @{} } } }
    $script:projectConfig = $cfg
    if (-not $hasRoot) { return $cfg }
    $in = $false; $keyIndent = -1; $sub = ''; $titleIndent = -1; $group = ''
    foreach ($line in (Read-Text (Join-Path $osDir 'config.yaml')).Replace("`r", '').Split("`n")) {
        if (-not $line.Trim() -or $line.TrimStart().StartsWith('#')) { continue }
        $indent = $line.Length - $line.TrimStart().Length
        if ($indent -eq 0) { $in = $line -match '^lazyspec:\s*$'; $keyIndent = -1; $sub = ''; continue }
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
    if ($t) { return $t }
    if ($exportSettings -and $exportSettings.titles -and $exportSettings.titles.$Name) { return [string]$exportSettings.titles.$Name }
    return $Default
}

# --- diagrams: a FigJam (or Figma) section, or an image file, at the top of a chapter or a capability ------
# "lazyspec: diagrams:" in config.yaml, as titles: a group per change ("change" there: the whole change's
# diagram), entries straight under diagrams for every change and for specs. A Figma link is saved as PNG in
# the change's diagrams\ folder (openspec\diagrams\ for specs), its white margins cut: commit it, and the
# export works without Figma. Downloaded (again with -RefreshDiagrams) through the Figma REST API with a
# personal access token in FIGMA_TOKEN.
$script:diagramsRefresh = $false
$script:diagramsOffline = $false
$script:figmaRefused = $false
$script:exportFormat = 'Pdf'
$script:imageTool = $false
function Initialize-ImageTool {
    if ($script:imageTool) { return }
    Add-Type -AssemblyName System.Drawing
    $refs = @('System.Drawing')
    if ($PSVersionTable.PSEdition -eq 'Core') { $refs = @('System.Drawing.Common', 'System.Drawing.Primitives', 'System.Runtime.InteropServices') }
    Add-Type -ReferencedAssemblies $refs -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
public static class LazySpecImage {
    // Cuts an image's margins off (transparent, white, or light grey without colour: a FigJam section's
    // background and its frame), keeping a border; transparency becomes white.
    public static void Trim(string path, int border) {
        Bitmap src;
        using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read)) using (Image img = Image.FromStream(fs)) { src = new Bitmap(img); }
        using (src) {
            int w = src.Width, h = src.Height;
            BitmapData data = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            int[] px = new int[w * h];
            Marshal.Copy(data.Scan0, px, 0, px.Length);
            src.UnlockBits(data);
            int minX = w, minY = h, maxX = -1, maxY = -1;
            for (int y = 0; y < h; y++) {
                int row = y * w;
                for (int x = 0; x < w; x++) {
                    int c = px[row + x];
                    int a = (c >> 24) & 255, r = (c >> 16) & 255, g = (c >> 8) & 255, b = c & 255;
                    int hi = Math.Max(r, Math.Max(g, b)), lo = Math.Min(r, Math.Min(g, b));
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
            using (Bitmap dst = new Bitmap(x1 - x0 + 1, y1 - y0 + 1, PixelFormat.Format24bppRgb)) {
                using (Graphics gr = Graphics.FromImage(dst)) {
                    gr.Clear(Color.White);
                    gr.DrawImage(src, new Rectangle(0, 0, dst.Width, dst.Height), new Rectangle(x0, y0, dst.Width, dst.Height), GraphicsUnit.Pixel);
                }
                dst.Save(path, ImageFormat.Png);
            }
        }
    }
    public static int[] Size(string path) {
        using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read)) using (Image img = Image.FromStream(fs, false, false)) { return new int[] { img.Width, img.Height }; }
    }
}
'@
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
    if ((Test-Path -LiteralPath $file) -and -not $script:diagramsRefresh) { return $file }
    # The saved ones only (-KeepDiagrams): no Figma; none saved, no diagram.
    if ($script:diagramsOffline) {
        if (Test-Path -LiteralPath $file) { return $file }
        Write-Host "  ! diagram $($Key): none saved yet"
        return ''
    }
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
# A diagram in the document, the page's width at most: Word gets the file (and embeds it), the others the image itself.
function Get-DiagramHtml([string]$Path, [string]$Caption) {
    if (-not $Path) { return '' }
    $attr = ''
    try {
        Initialize-ImageTool
        $size = [LazySpecImage]::Size($Path)
        $k = [Math]::Min(1.0, [Math]::Min(640.0 / $size[0], 860.0 / $size[1]))
        $attr = " width=`"$([int]($size[0] * $k))`" height=`"$([int]($size[1] * $k))`""
    } catch { }
    if ($script:exportFormat -eq 'Word') { $src = ([Uri]$Path).AbsoluteUri }
    else {
        $mime = @{ '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'; '.svg' = 'image/svg+xml'; '.webp' = 'image/webp' }[[IO.Path]::GetExtension($Path).ToLower()]
        if (-not $mime) { $mime = 'image/png' }
        $src = "data:$mime;base64," + [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
    }
    return "<div class=`"diagram`"><img src=`"$src`"$attr alt=`"$(Html $Caption)`"><p class=`"caption`">$(Html "$(Get-ExportText 'diagram'): $Caption")</p></div>`n"
}
# A small contents: links, one a line.
function Get-TocHtml($Entries) {
    if (-not @($Entries).Count) { return '' }
    return '<ul class="toc-list">' + (-join @($Entries | ForEach-Object { "<li><a href=`"#$($_.Id)`">$(ConvertTo-HtmlInline $_.Text)</a></li>" })) + "</ul>`n"
}
# A change's capabilities: a small contents, then each one: its title, its diagram, its delta spec.
function Get-CapabilitiesHtml($Change) {
    $sb = New-Object Text.StringBuilder
    $caps = @($Change.Caps | ForEach-Object {
            [pscustomobject]@{ Cap = $_; Id = "cap-$($Change.Name)-$($_.Name)"; Text = (Get-FriendlyTitle $_.Name $_.Name $Change.Name) } })
    [void]$sb.Append((Get-TocHtml $caps))
    foreach ($c in $caps) {
        [void]$sb.Append("<h2 class=`"cap`" id=`"$($c.Id)`"><a name=`"$($c.Id)`"></a>$(Html (Get-ExportText 'capability')): $(Html $c.Text)</h2>`n")
        [void]$sb.Append((Get-DiagramHtml (Get-Diagram $c.Cap.Name $Change.Name $Change.Dir) $c.Text))
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
    if ($Item -and $Item.Type -eq 'change') { $wf = $Item.Workflow } elseif ($hasRoot) { $wf = Get-Workflow (Join-Path $osDir 'changes\-') }
    $l = ''
    if ($wf -and $wf.Language) { $l = $wf.Language } else { $l = Get-ExportSetting 'language' '' }
    $l = ($l.ToLower() -split '[-_]')[0]
    if (-not $l) { $l = 'en' }
    return $l
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

# The whole document as HTML. Word: a [[TOC]] mark where Word puts its own table of contents.
function Get-ExportHtml([string]$Format, [bool]$WithChanges, [string]$ItemName, [bool]$Friendly) {
    $specs = @(Load-Specs)
    $changes = @()
    if ($WithChanges) { $changes = @(Load-Changes | Where-Object { -not $_.Archived } | Sort-Object Name) }
    $one = $null
    if ($ItemName) {
        $one = @($specs | Where-Object { $_.Name -eq $ItemName }) + @(Load-Changes | Where-Object { $_.Name -eq $ItemName }) | Select-Object -First 1
        if (-not $one) { throw "No spec or change named '$ItemName' in openspec/." }
    }
    Load-ExportTexts
    $script:exportLang = Get-ExportLanguage $one
    $script:exportFriendly = $Friendly
    $script:exportFormat = $Format
    $title = Get-ExportSetting 'title' $projectName
    $subtitle = Get-ExportSetting 'subtitle' (Get-ExportText 'specification')
    $client = Get-ExportSetting 'client' ''
    $author = Get-ExportSetting 'author' 'Netmedia'
    $date = Get-Date -Format (Get-ExportText 'dateFormat' 'yyyy-MM-dd')
    $reqs = 0
    $chapters = @()
    $scope = ''
    # One spec, or one change with every document of its workflow, in its order.
    if ($one) {
        $specs = @(); $changes = @()
        $subtitle = Get-ItemTitle $one
        if ($one.Type -eq 'spec') {
            $specs = @($one)
            $subtitle = "$(Get-ExportText 'specification'): $subtitle"
        }
        else {
            # A link to one of its documents ("open-questions.md") goes to that document's chapter.
            $script:docAnchors = @{}
            foreach ($d in $one.Docs) { foreach ($f in $d.Files) { $script:docAnchors[(Split-Path $f -Leaf)] = "doc-$($d.Id)" } }
            $n = 0
            foreach ($d in $one.Docs) {
                $sb = New-Object Text.StringBuilder
                if ($d.IsSpecs) {
                    if (-not $one.Caps.Count) { continue }
                    # The whole change's diagram first, then its capabilities.
                    [void]$sb.Append((Get-DiagramHtml (Get-Diagram 'change' $one.Name $one.Dir) (Get-ItemTitle $one)))
                    [void]$sb.Append((Get-CapabilitiesHtml $one))
                }
                else {
                    if (-not $d.Files.Count) { continue }
                    foreach ($f in $d.Files) {
                        if ($d.Files.Count -gt 1) { [void]$sb.Append("<h2>$(Html (Split-Path $f -Leaf))</h2>`n"); [void]$sb.Append((ConvertTo-HtmlBody (Remove-DocTitle (Read-Text $f)) 1)) }
                        else { [void]$sb.Append((ConvertTo-HtmlBody (Remove-DocTitle (Read-Text $f)))) }
                    }
                }
                $n++
                # The chapter's title: export-texts.json's for the workflow's usual documents, else the document's own "# Title".
                $dt = Get-ExportText $d.Id "`0"
                if ($dt -eq "`0") {
                    $dt = $d.Title
                    $h1 = [regex]::Match((Read-Text $d.Files[0]), '(?m)^#\s+(.+?)\s*$')
                    if ($d.Files.Count -eq 1 -and $h1.Success) { $dt = $h1.Groups[1].Value }
                }
                if ($d.IsSpecs) { $dt = Get-ExportText 'specs' }
                $chapters += [pscustomobject]@{ Id = "doc-$($d.Id)"; Title = "$n. $dt"; Part = 'specs'; Body = $sb.ToString() }
            }
            foreach ($cap in $one.Caps) { $reqs += $cap.Added + $cap.Modified }
            $scope = "$($chapters.Count) $(Get-ExportText 'nDocuments'), $($one.Caps.Count) $(Get-ExportText 'nCapabilities'), $($one.Total) $(Get-ExportText 'nTasks')"
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
        $chapters += [pscustomobject]@{ Id = "spec-$($s.Name)"; Title = "$n. $name"; Part = 'specs'; Body = $body }
    }
    foreach ($c in $changes) {
        $sb = New-Object Text.StringBuilder
        [void]$sb.Append((Get-DiagramHtml (Get-Diagram 'change' $c.Name $c.Dir) (Get-ItemTitle $c)))
        $proposal = Join-Path $c.Dir 'proposal.md'
        if (Test-Path -LiteralPath $proposal) { [void]$sb.Append((ConvertTo-HtmlBody (Remove-DocTitle (Read-Text $proposal)))) }
        [void]$sb.Append((Get-CapabilitiesHtml $c))
        $chapters += [pscustomobject]@{ Id = "change-$($c.Name)"; Title = (Get-ItemTitle $c); Part = 'changes'; Body = $sb.ToString() }
    }

    # The page's footer (title, page / pages): Edge and Chrome. Word drops a stylesheet with these; it numbers the pages itself.
    $pageCss = ''
    if ($Format -ne 'Word') {
        $pageCss = @"
@page { size: A4; margin: 20mm 18mm 22mm 18mm;
  @bottom-left { content: "$(("$title - $subtitle") -replace '["\\<>]', '')"; font: 8pt 'Segoe UI', Arial, sans-serif; color: #8a96a3; }
  @bottom-right { content: counter(page) " / " counter(pages); font: 8pt 'Segoe UI', Arial, sans-serif; color: #8a96a3; } }
@page :first { @bottom-left { content: none; } @bottom-right { content: none; } }

"@
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
.diagram { margin: 6pt 0 16pt; text-align: center; page-break-inside: avoid; break-inside: avoid; }
.diagram img { max-width: 100%; max-height: 230mm; height: auto; }
.diagram .caption { font-size: 8.5pt; color: #8a96a3; margin: 3pt 0 0; }
ul.toc-list { margin: 4pt 0 14pt; padding-left: 16pt; }
ul.toc-list li { font-size: 10pt; margin: 1.5pt 0; }
p.toc-scn { font-size: 9pt; color: #52606d; margin: 2pt 0 8pt; }
p.toc-scn .lbl { font-weight: 600; }
table { border-collapse: collapse; width: 100%; margin: 6pt 0 12pt; font-size: 9pt; }
th, td { border: 1px solid #c9d3dc; padding: 3pt 6pt; margin: 0; text-align: left; vertical-align: top; }
th { background: #eaf1f7; font-weight: 600; }
tr { page-break-inside: avoid; }
code { font-family: Consolas, 'Courier New', monospace; font-size: 9pt; background: #f1f3f5; padding: 0 2pt; }
pre { font-family: Consolas, 'Courier New', monospace; font-size: 8.5pt; background: #f6f8fa; border: 1px solid #e1e4e8; padding: 6pt; white-space: pre; overflow: hidden; }
pre code { background: none; padding: 0; }
pre.wrap, pre.wrap code { font-size: 9pt; white-space: pre-wrap; overflow-wrap: anywhere; word-wrap: break-word; }
/* Numbered questions at the margin, their answers lettered (a, b, c), a proposal at the answers' level. */
ol.top { margin-left: 0; padding-left: 1.8em; }
ol.top > li { margin: 10pt 0 4pt; }
ol.options { margin: 4pt 0; padding-left: 1.8em; }
ol.options > li { margin: 2pt 0; }
li > p { margin: 6pt 0; }
p.proposal { margin: 6pt 0 10pt; }
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
</style></head><body>
<div class="cover">
<div class="bar"></div>
<p class="title">$(Html $title)</p>
<p class="subtitle">$(Html $subtitle)</p>

"@)
    if ($client) { [void]$h.Append("<p class=`"meta`">$(Html (Get-ExportText 'client')): <strong>$(Html $client)</strong></p>`n") }
    [void]$h.Append("<p class=`"meta`">$(Html (Get-ExportText 'date')): $date</p>`n")
    if ($author) { [void]$h.Append("<p class=`"meta`">$(Html (Get-ExportText 'preparedBy')): $(Html $author)</p>`n") }
    if (-not $scope) {
        $scope = "$($specs.Count) $(Get-ExportText 'nChapters'), $reqs $(Get-ExportText 'nRequirements')"
        if ($changes.Count) { $scope += ", $($changes.Count) $(Get-ExportText 'nChanges')" }
    }
    [void]$h.Append("<p class=`"meta`">$(Html (Get-ExportText 'scope')): $(Html $scope)</p>`n</div>`n")

    [void]$h.Append("<p class=`"toc-title`">$(Html (Get-ExportText 'contents'))</p>`n")
    if ($Format -eq 'Word') { [void]$h.Append("<p>[[TOC]]</p>`n") }
    else {
        [void]$h.Append("<div class=`"toc`">`n")
        $part = 'specs'
        foreach ($ch in $chapters) {
            if ($ch.Part -ne $part) { $part = $ch.Part; [void]$h.Append("<p class=`"part`">$(Html (Get-ExportText 'plannedChanges'))</p>`n") }
            [void]$h.Append("<p><a href=`"#$($ch.Id)`">$(Html $ch.Title)</a></p>`n")
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
    return [pscustomobject]@{ Html = $h.ToString(); Specs = $specs.Count; Changes = $changes.Count; Reqs = $reqs; Item = $one; Chapters = $chapters.Count; Scope = $scope }
}

function Find-Browser {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'), (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'), (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'))
    foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    return $null
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
function Export-Pdf([string]$HtmlPath, [string]$Target) {
    $browser = Find-Browser
    if (-not $browser) { throw 'PDF needs Microsoft Edge or Google Chrome (neither was found).' }
    Write-Host "  $($g.caret) printing with $(Split-Path $browser -Leaf)"
    $profileDir = Join-Path (Split-Path $HtmlPath -Parent) 'browser'
    $argLine = "--headless=new --disable-gpu --no-first-run --no-default-browser-check --disable-extensions --user-data-dir=`"$profileDir`" " +
        "--no-pdf-header-footer --print-to-pdf-no-header --print-to-pdf=`"$Target`" `"$(([Uri]$HtmlPath).AbsoluteUri)`""
    $p = Start-Process -FilePath $browser -ArgumentList $argLine -WindowStyle Hidden -PassThru
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
    if (-not $p.HasExited) { & taskkill.exe /T /F /PID $p.Id 2>&1 | Out-Null }
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
                [void]$doc.TablesOfContents.Add($range, $true, 1, 1)
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
    & $pandoc.Source $HtmlPath -f html -t docx --toc --toc-depth=1 -o $Target
    if ($LASTEXITCODE) { throw "pandoc ended with exit code $LASTEXITCODE." }
}

function Invoke-Export([string]$Format, [string]$Target, [bool]$WithChanges, [bool]$OpenIt, [string]$ItemName, [bool]$Friendly) {
    if (-not $hasRoot) { throw "No openspec folder in $((Get-Location).Path) or above it: nothing to export." }
    $ext = @{ Pdf = 'pdf'; Word = 'docx'; Html = 'html' }[$Format]
    $doc = Get-ExportHtml $Format $WithChanges $ItemName $Friendly
    if ($doc.Item) {
        if (-not $doc.Chapters) { throw "$($doc.Item.Name) has none of its documents yet: nothing to export." }
        $what = "$($doc.Item.Type) $($doc.Item.Name): $($doc.Scope)"
        if ($doc.Item.Type -eq 'spec') { $what = "spec $($doc.Item.Name): $($doc.Reqs) requirements" }
    }
    else {
        if (-not $doc.Specs) { throw 'openspec/specs has no specs yet: nothing to export.' }
        $what = "$($doc.Specs) specs, $($doc.Reqs) requirements"
        if ($WithChanges) { $what += ", $($doc.Changes) active changes" }
    }
    if (-not $Target) {
        $slug = ($projectName.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
        if (-not $slug) { $slug = 'project' }
        $part = 'specification'
        if ($doc.Item) { $part = ($doc.Item.Name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-') }
        $Target = Join-Path $Root "export\$slug-$part-$(Get-Date -Format 'yyyy-MM-dd').$ext"
    }
    $Target = [IO.Path]::GetFullPath($Target)
    [void](New-Item -ItemType Directory -Force -Path (Split-Path $Target -Parent))
    Write-Host "  $($g.caret) $projectName`: $what"
    $how = "language $($script:exportLang)"
    if ($Friendly) { $how += ', client-friendly (scenarios as sentences)' }
    Write-Host "  $($g.caret) $how"
    $utf8 = New-Object Text.UTF8Encoding $false
    if ($Format -eq 'Html') { [IO.File]::WriteAllText($Target, $doc.Html, $utf8) }
    else {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('lazyspec-export-' + [guid]::NewGuid().ToString('N'))
        [void](New-Item -ItemType Directory -Path $tmp)
        try {
            $htmlPath = Join-Path $tmp 'specification.html'
            [IO.File]::WriteAllText($htmlPath, $doc.Html, $utf8)
            if (Test-Path -LiteralPath $Target) { Remove-Item -LiteralPath $Target -Force }
            if ($Format -eq 'Pdf') { Export-Pdf $htmlPath $Target } else { Export-Word $htmlPath $Target }
        }
        finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-Host "$($g.check) Written: $Target"
    if ($OpenIt) { Invoke-Item -LiteralPath $Target }
}

if ($Export) {
    # Shown in LazySpec's run screen too (it reads this as UTF-8).
    try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
    # The diagrams: the latest from Figma when there is a token (the saved ones when that fails), unless
    # -KeepDiagrams; -RefreshDiagrams: the latest in any case (and says so when there is no token).
    $script:diagramsRefresh = $RefreshDiagrams.IsPresent -or (-not $KeepDiagrams.IsPresent -and [bool](Get-FigmaToken))
    $script:diagramsOffline = $KeepDiagrams.IsPresent -and -not $RefreshDiagrams.IsPresent
    try { Invoke-Export $Export $Out $IncludeChanges.IsPresent $Open.IsPresent $Item $ClientFriendly.IsPresent; exit 0 }
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
    return , @(@("$($g.up)$($g.down)", 'select'), @('Enter', 'open'), @('Tab', 'scope/plan'), @('v', 'validate'), @('a', 'archive'), @('n', 'new'), @('x', 'export'), @('e', 'edit'), @('s', 'sort'), @('/', 'filter'), @('?', 'help'), @('q', 'quit'))
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
function Start-Export([string]$Format, [bool]$WithChanges, [string]$ItemName, [bool]$Friendly, [string]$Diagrams) {
    $cliArgs = @('-Root', $Root, '-Export', $Format)
    if ($ItemName) { $cliArgs += @('-Item', $ItemName) }
    if ($WithChanges) { $cliArgs += '-IncludeChanges' }
    if ($Friendly) { $cliArgs += '-ClientFriendly' }
    if ($Diagrams -eq 'refresh') { $cliArgs += '-RefreshDiagrams' } elseif ($Diagrams -eq 'keep') { $cliArgs += '-KeepDiagrams' }
    if (-not $harness) { $cliArgs += '-Open' }
    $label = "Export $Format"
    if ($ItemName) { $label += " ($ItemName)" }
    if ($WithChanges) { $label += ' (with the plan)' }
    if ($Friendly) { $label += ', client-friendly' }
    New-Run $label "lazyspec $(($cliArgs | Where-Object { $_ -ne $Root -and $_ -ne '-Root' }) -join ' ')"
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
        if ($env:OS -eq 'Windows_NT') { & taskkill.exe /T /F /PID $p.Id 2>&1 | Out-Null } else { try { $p.Kill() } catch { } }
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
        if ($code) { Start-Process -FilePath $code.Source -ArgumentList @("`"$Path`"") -WindowStyle Hidden; $script:message = "Opened in VS Code: $Path" }
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
        @('x', 'export the specification for the client: PDF, Word or HTML (export\ in the project; opens it)'), @('e', 'edit: open the spec or the proposal in your editor'),
        @('s', 'sort changes: name A-Z, name Z-A, recently modified'), @('h', 'show or hide archived changes'),
        @('/', 'filter specs and changes by name (Enter keeps it, Esc clears it)'), @('r', 'refresh (it also refreshes by itself when files change)'),
        @('?', 'this help'), @('q', 'quit'))
    & $section 'READ' @(
        @("$($g.up) $($g.down)", 'scroll a line'), @('PgUp PgDn', 'scroll a page'), @('Home End', 'top, end'),
        @("$([string][char]0x2190) $([string][char]0x2192)", 'the change''s documents (its workflow''s: proposal, delta specs, design, tasks...)'), @('x', 'export this spec or change alone: PDF, Word or HTML'), @('e', 'edit this document'), @('Esc', 'back'))
    & $section 'RUN' @(@('PgUp PgDn', 'scroll the output (Home, End: top, bottom)'), @('Esc', 'stop (asked first); when done: back'))
    & $section 'LOOK' @(
        @("$($g.diamond) $($g.dot)", 'a platform page (platform-*: overview, costs...), a capability spec'),
        @("$($g.ring) $($g.diamond) $($g.dot) $($g.mid)", 'a change: draft (no tasks), in progress, completed, archived'),
        @('+ ~ -', 'requirements a change adds, modifies, removes in a capability'))
    & $section 'THE SAME WITHOUT THE UI' @(
        @('v', 'openspec validate --all --strict'), @('a', 'openspec archive <change> --yes'), @('n', 'openspec new change <name>'), @('x', 'lazyspec -Export Pdf|Word|Html [-IncludeChanges] [-Out <file>] [-Open]'),
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
    # No specs yet: the selected change alone (as x in Read).
    if (-not $script:specs.Count) {
        $sel = Get-Selected
        if ($sel -and $sel.Type -eq 'change') { Start-ItemExportMenu $sel; return }
        $script:message = 'openspec/specs has no specs yet: select a change to export it.'; return
    }
    $script:choose = [pscustomobject]@{ Text = 'Export the specification as'; Options = @('PDF', 'Word', 'HTML'); Keys = @('p', 'w', 'h'); Choice = 0; Do = {
            param($i)
            $format = @('Pdf', 'Word', 'Html')[$i]
            $active = @($script:changes | Where-Object { -not $_.Archived }).Count
            if (-not $active) { Start-ExportAudience $format $false ''; return }
            $script:choose = [pscustomobject]@{ Text = "$($format.ToUpper()):"; Options = @('Specs only', "Specs + the plan ($active changes)"); Short = @('specs only', 'with the plan'); Keys = @('s', 'p'); Choice = 0; Format = $format; Do = {
                    param($j, $c)
                    Start-ExportAudience $c.Format ($j -eq 1) ''
                } }
        } }
}
# x in the read screen: what is being read, alone: the spec, or the change with all its workflow's documents.
function Start-ItemExportMenu($Item) {
    $what = 'the spec'
    if ($Item.Type -eq 'change') { $what = 'the change' }
    $name = $Item.Name
    $script:choose = [pscustomobject]@{ Text = "Export $what $name as"; Options = @('PDF', 'Word', 'HTML'); Keys = @('p', 'w', 'h'); Choice = 0; Item = $name; Do = {
            param($i, $c)
            Start-ExportAudience @('Pdf', 'Word', 'Html')[$i] $false $c.Item
        } }
}
# The export's last question: for the client (scenarios as sentences) or as written.
function Start-ExportAudience([string]$Format, [bool]$WithChanges, [string]$ItemName) {
    $script:choose = [pscustomobject]@{ Text = "$($Format.ToUpper()) for:"; Options = @('The client (scenarios as sentences)', 'Technical (as written)'); Short = @('client', 'technical'); Keys = @('c', 't'); Choice = 0
        Format = $Format; WithChanges = $WithChanges; Item = $ItemName; Do = {
            param($k, $c)
            Start-ExportDiagrams $c.Format $c.WithChanges $c.Item ($k -eq 0)
        } }
}
# With a Figma token and diagrams in the config: the latest from Figma, or the saved ones? Else straight on.
function Start-ExportDiagrams([string]$Format, [bool]$WithChanges, [string]$ItemName, [bool]$Friendly) {
    $script:projectConfig = $null
    if (-not ((Test-Diagrams) -and (Get-FigmaToken))) { Start-Export $Format $WithChanges $ItemName $Friendly 'keep'; return }
    $script:choose = [pscustomobject]@{ Text = 'Diagrams:'; Options = @('Download the latest from Figma', 'Use the saved ones'); Short = @('download', 'saved'); Keys = @('d', 's'); Choice = 0
        Format = $Format; WithChanges = $WithChanges; Item = $ItemName; Friendly = $Friendly; Do = {
            param($k, $c)
            Start-Export $c.Format $c.WithChanges $c.Item $c.Friendly (@('refresh', 'keep')[$k])
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
        if ($name -eq 'Enter') { $script:input = $null; if ($i.Value) { & $i.Do $i.Value }; return }
        if ($name -eq 'Back') { if ($i.Value.Length) { $i.Value = $i.Value.Substring(0, $i.Value.Length - 1) }; return }
        if ($name -eq 'Space') { $i.Value += '-'; return }
        if ([string]$ch -eq ' ') { $i.Value += '-'; return }
        if ($ch -and [int][char]$ch -ge 32) { $i.Value += ([string]$ch).ToLower() }
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
        if ($env:OS -eq 'Windows_NT') { & taskkill.exe /T /F /PID $script:run.Proc.Id 2>&1 | Out-Null } else { try { $script:run.Proc.Kill() } catch { } }
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

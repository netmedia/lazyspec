#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  initintoproject.ps1                                       |
#  |   Puts LazySpec into a project, updates it there, or removes it          |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Puts LazySpec into a project (tools\lazyspec\ and lazyspec.exe in its root), updates the kit there, or
    removes it (-Remove: LazySpec installed on the PC runs the project instead).

.AUTHOR
    Netmedia  |  https://netmedia.agency  |  netmedia@netmedia.hr

.DESCRIPTION
    LazySpec shows a project's OpenSpec (openspec\specs, openspec\changes) in a terminal UI and runs the
    OpenSpec CLI for validate, archive and new change.

    New project:
      Copies the kit (tools\lazyspec\ of this repository: the files kit.json lists) into
      <Target>\tools\lazyspec\ and lazyspec.exe into <Target>. Then, from the project's root:
      .\lazyspec.exe. The project's openspec\ is never touched (openspec init makes it).

    Update (-Update):
      Replaces the kit's files in a project that has LazySpec.

    Remove (-Remove):
      Takes the kit out of the project (tools\lazyspec\ and lazyspec.exe in its root) for LazySpec
      installed on the PC (install.exe in this repository). The project's settings move from
      tools\lazyspec\lazyspec.json to lazyspec.json in its root, where installed LazySpec reads them.
      openspec\ is never touched.

.PARAMETER Target
    (Required) The project's root (the folder with openspec\, or where openspec init will make it),
    e.g. D:\Development\Netmedia\MyProject.

.PARAMETER Update
    Update the kit's files of a project that has LazySpec.

.PARAMETER Remove
    Take LazySpec out of the project (its settings stay, in lazyspec.json in the project's root).

.PARAMETER DryRun
    Show what would be copied or removed, change nothing.

.PARAMETER Help
    Display the usage guide and exit.

.EXAMPLE
    # A new project
    .\initintoproject.ps1 D:\Development\Netmedia\MyProject

.EXAMPLE
    # A project's kit up to date with this repository
    .\initintoproject.ps1 D:\Development\Netmedia\MyProject -Update

.EXAMPLE
    # The project without its own copy: LazySpec installed on the PC runs it
    .\initintoproject.ps1 D:\Development\Netmedia\MyProject -Remove

.NOTES
    LazySpec is a Netmedia product: https://netmedia.agency, netmedia@netmedia.hr,
    https://github.com/netmedia/lazyspec. Documentation: tools\lazyspec\LAZYSPEC.md.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Target,
    [Alias('h')]
    [switch]$Help,
    [switch]$Update,
    [switch]$Remove,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$kit = Join-Path $PSScriptRoot 'tools\lazyspec'
$manifest = Get-Content (Join-Path $kit 'kit.json') -Raw -Encoding UTF8 | ConvertFrom-Json

# --- OUTPUT HELPERS ---------------------------------------------------------------------------------------

function Write-Banner([string]$msg) {
    $pad = 60
    $line = [string]::new([char]0x2500, $pad)
    Write-Host "`n  $([char]0x256D)$line$([char]0x256E)" -ForegroundColor Cyan
    Write-Host "  $([char]0x2502)  $($msg.PadRight($pad - 2))$([char]0x2502)" -ForegroundColor Cyan
    Write-Host "  $([char]0x2570)$line$([char]0x256F)`n" -ForegroundColor Cyan
}
function Write-OK([string]$msg) { Write-Host "  $([char]0x2713) $msg" -ForegroundColor Green }
function Write-Skip([string]$msg) { Write-Host "  $([char]0x00B7) $msg" -ForegroundColor DarkGray }
function Write-Info([string]$msg) { Write-Host "  $([char]0x2139) $msg" -ForegroundColor Cyan }
function Write-Warn([string]$msg) { Write-Host "  $([char]0x26A0) $msg" -ForegroundColor Magenta }
function Write-Err([string]$msg) { Write-Host "  $([char]0x2717) $msg" -ForegroundColor Red }

function Show-Author {
    $width = 64
    $hLine = [string]::new([char]0x2500, $width)
    $v = [char]0x2502
    $esc = [char]27
    function Row([string]$display, [string]$measure = $display, [string]$color = 'White') {
        $pad = [Math]::Max(0, $width - $measure.Length)
        $left = [Math]::Floor($pad / 2)
        Write-Host "  $v" -NoNewline -ForegroundColor Cyan
        Write-Host "$(' ' * $left)$display$(' ' * ($pad - $left))" -NoNewline -ForegroundColor $color
        Write-Host $v -ForegroundColor Cyan
    }
    $title = 'LazySpec  -  initintoproject.ps1'
    Write-Host ''
    Write-Host "  $([char]0x256D)$hLine$([char]0x256E)" -ForegroundColor Cyan
    Row ''
    Row "$esc[1m$title$esc[0m" $title 'Cyan'
    Row 'A project''s OpenSpec specs and changes in one screen' -color 'White'
    Row 'puts the kit into a project, updates it, or removes it' -color 'White'
    Row ''
    Row "by Netmedia  |  LazySpec $($manifest.version)" -color 'DarkGray'
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
    & $g '  .\initintoproject.ps1  <Target>  [-Update | -Remove]  [-DryRun]'
    Write-Host ''
    & $b 'ARGUMENTS'
    & $y '  <Target>  (required)'
    & $d '    The project''s root, e.g. D:\Development\Netmedia\MyProject. The kit goes into'
    & $d '    <Target>\tools\lazyspec\ and lazyspec.exe into <Target>.'
    Write-Host ''
    & $b 'OPTIONS'
    & $y '  -Update'
    & $d '    The project has LazySpec: replace the kit''s files (kit.json lists them).'
    & $y '  -Remove'
    & $d '    Take the kit out of the project (tools\lazyspec\, lazyspec.exe): LazySpec installed on'
    & $d '    the PC (install.exe) runs it. Its settings move to lazyspec.json in the project''s root.'
    & $y '  -DryRun'
    & $d '    Show what would be copied or removed; change nothing.'
    & $y '  -Help  (-h)'
    & $d '    Show this usage guide and exit.'
    Write-Host ''
    & $b 'EXAMPLES'
    & $g '  # A new project'
    & $g '  .\initintoproject.ps1  D:\Development\Netmedia\MyProject'
    Write-Host ''
    & $g '  # A project''s kit up to date with this repository'
    & $g '  .\initintoproject.ps1  D:\Development\Netmedia\MyProject  -Update'
    Write-Host ''
    & $g '  # The project without its own copy (LazySpec installed on the PC instead)'
    & $g '  .\initintoproject.ps1  D:\Development\Netmedia\MyProject  -Remove'
    Write-Host ''
    & $b 'THEN, FROM THE PROJECT''S ROOT'
    & $d '  1. openspec init                 (once, if the project has no openspec\ yet)'
    & $d '  2. .\lazyspec.exe                (or .\tools\lazyspec\lazyspec.ps1)'
    & $d '  3. commit tools\lazyspec\ and lazyspec.exe: everyone gets it with the project'
    Write-Host ''
    & $d '  Everything about it: tools\lazyspec\LAZYSPEC.md'
    Write-Host $hr -ForegroundColor Cyan
    Write-Host ''
}

# ==========================================================================================================
# MAIN EXECUTION
# ==========================================================================================================

Show-Author
if ($Help -or [string]::IsNullOrWhiteSpace($Target)) {
    if (-not $Help) { Write-Host "`n  ERROR: <Target> is required." -ForegroundColor Red }
    Show-Usage
    exit 0
}

$Target = [IO.Path]::GetFullPath($Target).TrimEnd('\', '/')
# Given tools\lazyspec (or tools) by mistake: the project's root is above it.
if ((Split-Path $Target -Leaf) -ieq 'lazyspec' -and (Split-Path (Split-Path $Target -Parent) -Leaf) -ieq 'tools') { $Target = Split-Path (Split-Path $Target -Parent) -Parent }
$dest = Join-Path $Target 'tools\lazyspec'
$has = Test-Path (Join-Path $dest 'lazyspec.ps1')
if ($Update -and $Remove) { Write-Err '-Update or -Remove, not both.'; exit 1 }

# --- -Remove: the kit out of the project ----------------------------------------------------------------
if ($Remove) {
    if (-not $has -and -not (Test-Path (Join-Path $Target 'lazyspec.exe'))) { Write-Err "$Target has no LazySpec to remove."; exit 1 }
    if ($DryRun) { Write-Host "`n  == DRY RUN - nothing is removed ==" -ForegroundColor Cyan }
    Write-Banner '[1/2] LazySpec -> out of the project'
    Write-Info "project: $Target"
    Write-Host ''
    $failed = 0
    # The project's settings: to its root, where LazySpec installed on the PC reads them.
    foreach ($f in @($manifest.projectFiles)) {
        if (-not $f) { continue }
        $from = Join-Path $dest $f
        $to = Join-Path $Target $f
        if (-not (Test-Path $from)) { continue }
        if (Test-Path $to) {
            if ((Get-FileHash $from).Hash -eq (Get-FileHash $to).Hash) {
                if ($DryRun) { Write-Skip "would remove tools\lazyspec\$f (the same as $f in the root)"; continue }
                Remove-Item -LiteralPath $from -Force; Write-OK "tools\lazyspec\$f removed (the same as $f in the root)"; continue
            }
            Write-Warn "tools\lazyspec\$f kept: the project's root has a different $f (merge them, then delete it)"
            $failed++
            continue
        }
        if ($DryRun) { Write-Skip "would move tools\lazyspec\$f to $f (the project's root)"; continue }
        Move-Item -LiteralPath $from -Destination $to
        Write-OK "tools\lazyspec\$f -> $f (the project's root)"
    }
    # The kit's files (kit.json lists them), and lazyspec.exe in the root.
    $targets = @($manifest.files | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ Path = (Join-Path $dest $_); Name = "tools\lazyspec\$_" } })
    $targets += @($manifest.rootFiles | Where-Object { $_ } | ForEach-Object { [pscustomobject]@{ Path = (Join-Path $Target $_); Name = "$_ in the project's root" } })
    foreach ($t in $targets) {
        if (-not (Test-Path $t.Path)) { continue }
        if ($DryRun) { Write-Skip "would remove $($t.Name)"; continue }
        try { Remove-Item -LiteralPath $t.Path -Recurse -Force; Write-OK "$($t.Name) removed" }
        catch { Write-Warn "$($t.Name): $($_.Exception.Message) (is it running? close it and run this again)"; $failed++ }
    }
    # The folders, when nothing else is in them.
    foreach ($d in @($dest, (Join-Path $Target 'tools'))) {
        if (-not (Test-Path $d)) { continue }
        $rel = $d.Substring($Target.Length + 1)
        if ($DryRun) { Write-Skip "would remove $rel\ when it's empty"; continue }
        $left = @(Get-ChildItem -LiteralPath $d -Force)
        if ($left.Count) { if ($d -eq $dest) { Write-Warn "$rel\ kept: it has files the kit doesn't list ($(@($left | ForEach-Object { $_.Name }) -join ', '))" }; continue }
        Remove-Item -LiteralPath $d -Force
        Write-OK "$rel\ removed (empty)"
    }

    Write-Banner '[2/2] Next'
    if ($DryRun) { Write-Info 'Run it again without -DryRun to remove.'; exit 0 }
    if ($failed) { Write-Warn "Done, with $failed thing(s) left (above)." } else { Write-OK "LazySpec is out of $Target." }
    # Installed on this PC? Else lazyspec doesn't start in the project any more.
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $installed = Test-Path (Join-Path $env:LOCALAPPDATA 'Programs\LazySpec\lazyspec.exe')
    foreach ($pp in @((Join-Path $docs 'WindowsPowerShell\profile.ps1'), (Join-Path $docs 'PowerShell\profile.ps1'))) {
        if ((Test-Path $pp) -and (Select-String -LiteralPath $pp -SimpleMatch '# >>> LazySpec (Netmedia) >>>' -Quiet)) { $installed = $true }
    }
    Write-Host ''
    if ($installed) { Write-Host '  In the project, in a new terminal:  lazyspec' -ForegroundColor Green }
    else {
        Write-Warn 'LazySpec isn''t installed on this PC: install it to run the project now.'
        Write-Host "    $(Join-Path $PSScriptRoot 'install.exe') Profile      (or Global, Both)" -ForegroundColor Green
    }
    Write-Host ''
    Write-Host '  Commit the removal (tools\lazyspec\, lazyspec.exe, the moved lazyspec.json): the team then' -ForegroundColor DarkGray
    Write-Host '  uses LazySpec installed on their PCs too (install.exe in the LazySpec repository).' -ForegroundColor DarkGray
    Write-Host ''
    exit 0
}
if ($has -and -not $Update) { Write-Err "$Target has LazySpec already: -Update replaces the kit's files there."; exit 1 }
if (-not $has -and $Update) { Write-Err "$Target has no LazySpec to update: leave -Update out to put it there."; exit 1 }

if ($DryRun) { Write-Host "`n  == DRY RUN - nothing is copied ==" -ForegroundColor Cyan }
$mode = 'new project'
if ($Update) { $mode = 'update' }
Write-Banner "[1/2] LazySpec $($manifest.version) -> $mode"
Write-Info "kit:     $kit"
Write-Info "project: $Target"
$before = $null
if ($Update -and (Test-Path (Join-Path $dest 'kit.json'))) { $before = (Get-Content (Join-Path $dest 'kit.json') -Raw -Encoding UTF8 | ConvertFrom-Json).version }
if ($before) { Write-Info "the project has LazySpec $before" }
if (-not (Test-Path (Join-Path $Target 'openspec') -PathType Container)) { Write-Warn "$Target has no openspec\ yet: run 'openspec init' there (npm i -g @fission-ai/openspec)." }
Write-Host ''

if (-not $DryRun) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }
foreach ($f in @($manifest.files)) {
    $from = Join-Path $kit $f
    $to = Join-Path $dest $f
    if (-not (Test-Path $from)) { Write-Warn "$f isn't in the kit (for the .exe: .\build-exe.ps1)"; continue }
    if ($DryRun) { Write-Skip "would copy tools\lazyspec\$f"; continue }
    try {
        if (Test-Path $from -PathType Container) {
            New-Item -ItemType Directory -Force -Path $to | Out-Null
            Copy-Item -Path (Join-Path $from '*') -Destination $to -Recurse -Force
        } else { Copy-Item -Path $from -Destination $to -Force }
        Write-OK "tools\lazyspec\$f"
    } catch { Write-Warn "tools\lazyspec\$f`: $($_.Exception.Message) (is it running? close it and run this again)" }
}
# lazyspec.exe in the project's root as well: it starts tools\lazyspec\lazyspec.ps1, so lazyspec runs from there.
foreach ($f in @($manifest.rootFiles)) {
    if (-not $f -or -not (Test-Path (Join-Path $kit $f))) { continue }
    if ($DryRun) { Write-Skip "would copy $f to the project's root ($Target)"; continue }
    try {
        Copy-Item -Path (Join-Path $kit $f) -Destination (Join-Path $Target $f) -Force
        Write-OK "$f in the project's root"
    } catch { Write-Warn "$f in the project's root: $($_.Exception.Message) (is it running? close it and run this again)" }
}

Write-Banner '[2/2] Next'
if ($DryRun) { Write-Info 'Run it again without -DryRun to copy.'; exit 0 }
if ($Update) { Write-OK "LazySpec $before -> $($manifest.version) in $Target." }
else { Write-OK "LazySpec $($manifest.version) is in $Target." }
Write-Host ''
Write-Host '  From the project''s root:' -ForegroundColor White
Write-Host '    .\lazyspec.exe                       (cmd: lazyspec; also .\tools\lazyspec\lazyspec.ps1)' -ForegroundColor Green
Write-Host '    .\tools\lazyspec\lazyspec.ps1 -Help  screens, keys, commands' -ForegroundColor Green
Write-Host ''
Write-Host '  Commit tools\lazyspec\ and lazyspec.exe: everyone gets it with the project.' -ForegroundColor DarkGray
Write-Host ''
exit 0

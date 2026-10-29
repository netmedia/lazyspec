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
    # The overview first, then the other platform pages, then the capabilities.
    return @($list | Sort-Object @{ Expression = { if ($_.Short -eq 'overview') { 0 } elseif ($_.Platform) { 1 } else { 2 } } }, Name)
}
function Get-ChangeInfo($Dir, [bool]$Archived) {
    $tasks = Read-Text (Join-Path $Dir.FullName 'tasks.md')
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
    $title = ''
    $m = [regex]::Match((Read-Text (Join-Path $Dir.FullName 'proposal.md')), '(?m)^#\s+(.+?)\s*$')
    if ($m.Success) { $title = $m.Groups[1].Value -replace '^(Change|Proposal)\s*:\s*', '' }
    return [pscustomobject]@{
        Type = 'change'; Name = $Dir.Name; Title = $title; Stage = $stage; Archived = $Archived; Done = $done; Total = $total
        Modified = (Last-Write $Dir.FullName); Dir = $Dir.FullName; Path = (Join-Path $Dir.FullName 'proposal.md'); Caps = $caps; Tasks = $tasks
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
            $mark = $g.bullet
            if ($Matches[2] -match '\d') { $mark = $Matches[2] }
            Add-Wrapped $lines "  $ind$mark " $st.accent (Plain-Inline $Matches[3]) $st.text $Width
            continue
        }
        if ($t -match '^>\s?(.*)$') { Add-Wrapped $lines "  $($g.v) " $st.faint (Plain-Inline $Matches[1]) $st.muted $Width; continue }
        if ($t -match '^(-{3,}|\*{3,})$') { [void]$lines.Add(@(S ($g.h * [Math]::Min(60, $Width)) $st.faint)); continue }
        Add-Wrapped $lines '' '' (Plain-Inline $t.Trim()) $st.text $Width
    }
    while ($lines.Count -and @($lines[$lines.Count - 1]).Count -eq 0) { $lines.RemoveAt($lines.Count - 1) }
    return , $lines
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
    $docs = @((S ' ') )
    foreach ($f in @(@('proposal', 'proposal.md'), @('design', 'design.md'), @('tasks', 'tasks.md'))) {
        if (Test-Path -LiteralPath (Join-Path $Change.Dir $f[1])) { $docs += (S "$($g.check) $($f[0])   " $st.ok) } else { $docs += (S "$($g.ring) $($f[0])   " $st.faint) }
    }
    $docs += (S "$($Change.Caps.Count) delta spec$(if ($Change.Caps.Count -ne 1) { 's' })" $st.muted)
    Section-Head $lines 'DOCUMENTS' ''
    [void]$lines.Add($docs)
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
    if ($script:input) { return , @(@('Enter', 'ok'), @('Esc', 'cancel')) }
    if ($script:filtering) { return , @(@('type', 'filter'), @('Enter', 'keep'), @('Esc', 'clear')) }
    if ($script:zoom) { return , @(@("$($g.up)$($g.down) PgUp PgDn", 'scroll'), @('z Esc', 'show the lists'), @('Enter', 'read'), @('e', 'edit'), @('?', 'help'), @('q', 'quit')) }
    if ($script:pane -eq 'details') { return , @(@("$($g.up)$($g.down) PgUp PgDn", 'scroll'), @("$([string][char]0x2190) Esc", 'lists'), @('z', 'zoom'), @('Enter', 'read'), @('e', 'edit'), @('?', 'help'), @('q', 'quit')) }
    return , @(@("$($g.up)$($g.down)", 'select'), @('Enter', 'open'), @('Tab', 'specs/changes'), @('v', 'validate'), @('a', 'archive'), @('n', 'new'), @('e', 'edit'), @('s', 'sort'), @('/', 'filter'), @('?', 'help'), @('q', 'quit'))
}

function Home-Status([int]$Active, [int]$Lines, [int]$Rows) {
    $status = "openspec/  $($g.mid)  $($script:specs.Count) specs  $($g.mid)  $Active changes"
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
    [void]$left.Add(@((S ' SPECIFICATIONS ' $st.title), (S "$($g.mid) $($vs.Count)" $st.muted)))
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
    [void]$left.Add(@((S ' CHANGES ' $st.title), (S "$($g.mid) $note" $st.muted)))
    if (-not $vc.Count) { [void]$left.Add(@(S '   none yet  (n: new)' $st.faint)) }
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
    $tabs = @()
    foreach ($f in @(@('Proposal', 'proposal.md'), @('Design', 'design.md'), @('Tasks', 'tasks.md'))) {
        $p = Join-Path $Item.Dir $f[1]
        if (Test-Path -LiteralPath $p) { $tabs += [pscustomobject]@{ Title = $f[0]; Path = $p; Text = (Read-Text $p) } }
    }
    if ($Item.Caps.Count) {
        $sb = New-Object Text.StringBuilder
        foreach ($c in $Item.Caps) {
            [void]$sb.AppendLine("# $($c.Name)")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine((Read-Text $c.Path))
            [void]$sb.AppendLine('')
        }
        $tabs += [pscustomobject]@{ Title = "Specs ($($Item.Caps.Count))"; Path = $Item.Caps[0].Path; Text = $sb.ToString() }
    }
    if (-not $tabs.Count) { $tabs += [pscustomobject]@{ Title = 'Empty'; Path = $Item.Dir; Text = 'This change has no proposal, design, tasks or specs yet.' } }
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
    $bodyRows = $H - 3 - $head.Count
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
    foreach ($r in (Full-Rows ($H - 3) $W $lines)) { [void]$rows.Add($r) }
    [void]$rows.Add((Border-Line $W $g.lt $g.h $g.rt 0 ''))
    $hints = @(@("$($g.up)$($g.down) PgUp PgDn", 'scroll'), @('Home End', 'top, end'))
    if ($tabs.Count -gt 1) { $hints += , @("$([string][char]0x2190)$([string][char]0x2192)", 'document') }
    $hints += , @('e', 'edit'); $hints += , @('?', 'help'); $hints += , @('Esc', 'back')
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
    $run = [pscustomobject]@{
        Label = $Label; Command = "openspec $($CliArgs -join ' ')"; Proc = $null; Out = $null; Err = $null; OutDone = $false; ErrDone = $false
        Log = (New-Object Collections.ArrayList); Version = 0; Lines = $null; LinesKey = ''; Scroll = 0; Done = $false; Code = $null
        Watch = [Diagnostics.Stopwatch]::StartNew(); ConfirmStop = $false; Stopped = $false; Back = $script:screen
    }
    $script:run = $run
    $script:screen = 'run'
    Add-RunLog "$($g.caret) $($run.Command)" $st.muted
    Add-RunLog '' ''
    if (-not $tool) {
        Add-RunLog "$($g.cross) The OpenSpec CLI isn't installed (or not on PATH): npm install -g @fission-ai/openspec" $st.err
        $run.Done = $true; $run.Watch.Stop(); return
    }
    $psi = New-Object Diagnostics.ProcessStartInfo
    $argLine = (@($CliArgs) | ForEach-Object { Quote-Arg $_ }) -join ' '
    if ($tool -match '\.(cmd|bat)$') {
        $psi.FileName = $env:ComSpec
        if (-not $psi.FileName) { $psi.FileName = 'cmd.exe' }
        $psi.Arguments = "/d /s /c `"`"$tool`" $argLine`""
    } else {
        $psi.FileName = $tool
        $psi.Arguments = $argLine
    }
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
        Add-RunLog "$($g.cross) Can't start openspec: $($_.Exception.Message)" $st.err
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
        @("$($g.up) $($g.down)", 'select a spec or a change (in the details: scroll)'), @('Tab', 'specifications <-> changes'),
        @("$([string][char]0x2192) l", 'into the details (then up/down scroll them)'), @("$([string][char]0x2190) Esc", 'back to the lists'),
        @('z', 'zoom: the details over the whole width (z again or Esc: the lists back)'),
        @('PgUp PgDn', 'scroll the details a page (Home, End: top, end)'), @('Enter', 'read it in full'), @('v', 'validate all (openspec validate --all --strict)'),
        @('a', 'archive the selected change (asked first; merges its delta specs into openspec/specs)'),
        @('n', 'new change (asks its name: kebab-case, e.g. add-user-login)'), @('e', 'edit: open the spec or the proposal in your editor'),
        @('s', 'sort changes: name A-Z, name Z-A, recently modified'), @('h', 'show or hide archived changes'),
        @('/', 'filter specs and changes by name (Enter keeps it, Esc clears it)'), @('r', 'refresh (it also refreshes by itself when files change)'),
        @('?', 'this help'), @('q', 'quit'))
    & $section 'READ' @(
        @("$($g.up) $($g.down)", 'scroll a line'), @('PgUp PgDn', 'scroll a page'), @('Home End', 'top, end'),
        @("$([string][char]0x2190) $([string][char]0x2192)", 'proposal, design, tasks, delta specs (a change)'), @('e', 'edit this document'), @('Esc', 'back'))
    & $section 'RUN' @(@('PgUp PgDn', 'scroll the output (Home, End: top, bottom)'), @('Esc', 'stop (asked first); when done: back'))
    & $section 'LOOK' @(
        @("$($g.diamond) $($g.dot)", 'a platform page (platform-*: overview, costs...), a capability spec'),
        @("$($g.ring) $($g.diamond) $($g.dot) $($g.mid)", 'a change: draft (no tasks), in progress, completed, archived'),
        @('+ ~ -', 'requirements a change adds, modifies, removes in a capability'))
    & $section 'THE SAME WITHOUT THE UI' @(
        @('v', 'openspec validate --all --strict'), @('a', 'openspec archive <change> --yes'), @('n', 'openspec new change <name>'),
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
    $script:confirm = [pscustomobject]@{ Text = $text; Choice = 1; Do = { Start-Cli "Archive $name" @('archive', $name, '--yes') }.GetNewClosure() }
}
function Start-NewChange {
    $script:input = [pscustomobject]@{ Label = 'New change:'; Value = ''; Hint = 'kebab-case, e.g. add-user-login'; Do = {
            param($v)
            if ($v -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { $script:message = "'$v' isn't kebab-case (lowercase words with hyphens)."; return }
            Start-Cli "New change $v" @('new', 'change', $v)
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
        if ($lc -eq 'y' -or ($name -eq 'Enter' -and $c.Choice -eq 0)) { $script:confirm = $null; & $c.Do; return }
        if ($name -eq 'Enter') { $script:confirm = $null }
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
        if ($name -eq 'Down') { $script:readScroll++ }
        elseif ($name -eq 'Up') { $script:readScroll = [Math]::Max(0, $script:readScroll - 1) }
        elseif ($name -eq 'PgDn' -or $name -eq 'Space') { $script:readScroll += 20 }
        elseif ($name -eq 'PgUp') { $script:readScroll = [Math]::Max(0, $script:readScroll - 20) }
        elseif ($name -eq 'Home') { $script:readScroll = 0 }
        elseif ($name -eq 'End') { $script:readScroll = 1000000 }
        elseif ($name -eq 'Right' -or $name -eq 'Tab') { $script:readTab = ($script:readTab + 1) % $tabs.Count; $script:readScroll = 0 }
        elseif ($name -eq 'Left') { $script:readTab = ($script:readTab - 1 + $tabs.Count) % $tabs.Count; $script:readScroll = 0 }
        elseif ([string]$ch -eq 'e') { Open-InEditor $tabs[[Math]::Min($script:readTab, $tabs.Count - 1)].Path }
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

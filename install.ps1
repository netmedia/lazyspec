#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  install.ps1                                               |
#  |   Installs LazySpec on this PC, without putting it into a project        |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Installs LazySpec from this repository on this PC: `lazyspec` then works in every project with an
    openspec\ folder, without copying anything into the project.

.AUTHOR
    Netmedia  |  https://netmedia.agency  |  netmedia@netmedia.hr

.DESCRIPTION
    Two ways, alone or together:

      Profile  A lazyspec function in your PowerShell profiles. It runs the project's own copy when the
               project has one (initintoproject), else this repository's tools\lazyspec\lazyspec.exe:
               a git pull here updates it.
      Global   A copy in %LOCALAPPDATA%\Programs\LazySpec, on your user PATH (like lazygit): works in
               cmd and other shells too. A fixed version: install again to update.
      Both     Both: the function runs the project's own copy, else the global one.

    The projects' settings (specOrder, export) go into lazyspec.json in the project's root.
    Same as tools\lazyspec\lazyspec.ps1 -Install / -Uninstall, which this calls.

.PARAMETER Mode
    Profile, Global or Both.

.PARAMETER Uninstall
    Removes the profile function and the global copy with its PATH entry.

.PARAMETER Help
    Display the usage guide and exit.

.EXAMPLE
    .\install.exe Profile

.EXAMPLE
    .\install.exe Both

.EXAMPLE
    .\install.exe -Uninstall

.NOTES
    LazySpec is a Netmedia product: https://netmedia.agency, netmedia@netmedia.hr,
    https://github.com/netmedia/lazyspec.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Mode,
    [switch]$Uninstall,
    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$lazyspec = Join-Path $PSScriptRoot 'tools\lazyspec\lazyspec.ps1'
$manifest = Get-Content (Join-Path $PSScriptRoot 'tools\lazyspec\kit.json') -Raw -Encoding UTF8 | ConvertFrom-Json

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
    $title = 'LazySpec  -  install.ps1'
    Write-Host ''
    Write-Host "  $([char]0x256D)$hLine$([char]0x256E)" -ForegroundColor Cyan
    Row ''
    Row "$esc[1m$title$esc[0m" $title 'Cyan'
    Row 'Installs LazySpec on this PC, not into a project' -color 'White'
    Row ''
    Row "by Netmedia  |  LazySpec $($manifest.version)" -color 'DarkGray'
    Row 'https://netmedia.agency  |  netmedia@netmedia.hr' -color 'DarkGray'
    Row ''
    Write-Host "  $([char]0x2570)$hLine$([char]0x256F)" -ForegroundColor Cyan
}

function Show-Usage {
    $b = { param($t) Write-Host "  $t" -ForegroundColor White }
    $d = { param($t) Write-Host "  $t" -ForegroundColor DarkGray }
    $g = { param($t) Write-Host "  $t" -ForegroundColor Green }
    Write-Host ''
    & $b 'USAGE'
    & $g '  .\install.exe Profile      # a lazyspec function: the project''s copy, else this repository''s'
    & $g '  .\install.exe Global       # a copy on your PATH, like lazygit (install again to update)'
    & $g '  .\install.exe Both         # both: the project''s copy, else the global one'
    & $g '  .\install.exe -Uninstall   # removes them'
    Write-Host ''
    & $d '  Nothing goes into the projects: run lazyspec anywhere inside one (a folder with openspec\).'
    & $d '  A project''s settings (specOrder, export): lazyspec.json in its root.'
    & $d '  To put LazySpec into a project instead (committed with it): .\initintoproject.exe <project>'
    Write-Host ''
}

Show-Author
if ($Help -or (-not $Mode -and -not $Uninstall)) { Show-Usage; exit 0 }

if ($Uninstall) { & $lazyspec -Uninstall }
else {
    $m = $Mode.Trim()
    if ($m -notin 'Profile', 'Global', 'Both') { Write-Host "  Profile, Global or Both, not '$Mode'." -ForegroundColor Red; Show-Usage; exit 1 }
    & $lazyspec -Install $m
}
exit $LASTEXITCODE

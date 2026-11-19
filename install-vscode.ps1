#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  install-vscode.ps1                                        |
#  |   Installs the LazySpec extension in VS Code, Cursor, Windsurf           |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Installs vscode\lazyspec.vsix from this repository in every editor built on VS Code found on this PC
    (VS Code, VS Code Insiders, Cursor, Windsurf, VSCodium), or in the ones named.

.DESCRIPTION
    The same as <editor> --install-extension vscode\lazyspec.vsix --force, for each editor found on the PATH
    or in its usual install folder. After a git pull: run it again to update the extension.

.PARAMETER Editor
    Only these: code, code-insiders, cursor, windsurf, codium.

.PARAMETER Uninstall
    Removes the extension (netmedia.lazyspec) instead.

.PARAMETER Help
    Display the usage guide and exit.

.EXAMPLE
    .\install-vscode.exe

.EXAMPLE
    .\install-vscode.exe -Editor cursor

.EXAMPLE
    .\install-vscode.exe -Uninstall

.NOTES
    LazySpec is a Netmedia product: https://netmedia.agency, netmedia@netmedia.hr,
    https://github.com/netmedia/lazyspec.
#>
[CmdletBinding()]
param(
    [ValidateSet('code', 'code-insiders', 'cursor', 'windsurf', 'codium')]
    [string[]]$Editor,
    [switch]$Uninstall,
    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$vsix = Join-Path $PSScriptRoot 'vscode\lazyspec.vsix'
$id = 'netmedia.lazyspec'

Write-Host ''
Write-Host '  LazySpec for VS Code, Cursor, Windsurf' -ForegroundColor Cyan
Write-Host '  by Netmedia  |  https://netmedia.agency' -ForegroundColor DarkGray
Write-Host ''
if ($Help) {
    Write-Host '  USAGE' -ForegroundColor White
    Write-Host '    .\install-vscode.exe                      # every editor found' -ForegroundColor Green
    Write-Host '    .\install-vscode.exe -Editor cursor       # only these (code, code-insiders, cursor, windsurf, codium)' -ForegroundColor Green
    Write-Host '    .\install-vscode.exe -Uninstall' -ForegroundColor Green
    Write-Host ''
    Write-Host '    After a git pull: run it again to update the extension.' -ForegroundColor DarkGray
    Write-Host ''
    exit 0
}
if (-not $Uninstall -and -not (Test-Path -LiteralPath $vsix)) { Write-Host "  ERROR: $vsix isn't there (cd vscode; npm install; npm run package)." -ForegroundColor Red; exit 1 }

# An editor's command line: on the PATH, else in its usual install folders (Windows, macOS).
$known = [ordered]@{
    'code'          = @{ Name = 'VS Code'; Paths = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd", "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd", '/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code') }
    'code-insiders' = @{ Name = 'VS Code Insiders'; Paths = @("$env:LOCALAPPDATA\Programs\Microsoft VS Code Insiders\bin\code-insiders.cmd", '/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code-insiders') }
    'cursor'        = @{ Name = 'Cursor'; Paths = @("$env:LOCALAPPDATA\Programs\cursor\resources\app\bin\cursor.cmd", '/Applications/Cursor.app/Contents/Resources/app/bin/cursor') }
    'windsurf'      = @{ Name = 'Windsurf'; Paths = @("$env:LOCALAPPDATA\Programs\Windsurf\bin\windsurf.cmd", '/Applications/Windsurf.app/Contents/Resources/app/bin/windsurf') }
    'codium'        = @{ Name = 'VSCodium'; Paths = @("$env:LOCALAPPDATA\Programs\VSCodium\bin\codium.cmd", "$env:ProgramFiles\VSCodium\bin\codium.cmd", '/Applications/VSCodium.app/Contents/Resources/app/bin/codium') }
}
$found = 0; $failed = 0
foreach ($cmd in $known.Keys) {
    if ($Editor -and $Editor -notcontains $cmd) { continue }
    $exe = $null
    $c = Get-Command $cmd -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { $exe = $c.Source }
    else { foreach ($p in $known[$cmd].Paths) { if ($p -and (Test-Path -LiteralPath $p)) { $exe = $p; break } } }
    if (-not $exe) { if ($Editor) { Write-Host "  - $($known[$cmd].Name): not found" -ForegroundColor Yellow }; continue }
    $found++
    if ($Uninstall) { $out = & $exe --uninstall-extension $id 2>&1 | Out-String }
    else { $out = & $exe --install-extension $vsix --force 2>&1 | Out-String }
    if ($LASTEXITCODE -eq 0) { Write-Host "  $([char]0x2713) $($known[$cmd].Name)" -ForegroundColor Green }
    else { $failed++; Write-Host "  $([char]0x2717) $($known[$cmd].Name): $($out.Trim())" -ForegroundColor Red }
}
Write-Host ''
if (-not $found) { Write-Host '  No VS Code, Cursor, Windsurf or VSCodium found. In the editor: Extensions: Install from VSIX... and pick vscode\lazyspec.vsix.' -ForegroundColor Yellow; Write-Host ''; exit 1 }
if (-not $Uninstall -and -not $failed) { Write-Host '  Done: reload the editor''s window (Developer: Reload Window); the checklist icon in the activity bar opens LazySpec.' -ForegroundColor DarkGray; Write-Host '' }
exit [int]($failed -gt 0)

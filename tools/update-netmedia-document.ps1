#Requires -Version 5.1
<#
.SYNOPSIS
    Copies the netmedia-document plugin's generator and template from AIToolbelt into tools\lazyspec\netmedia-document\,
    the copy LazySpec's Word and PDF exports use when no netmedia-document is installed (LazySpec works on its own).

.DESCRIPTION
    LazySpec makes Word and PDF exports with netmedia-document's netmedia_document.py, as every Netmedia document
    (the Netmedia cover, contents, styles). It uses the installed plugin when there is one (the latest template);
    this copy is for everyone else. Run it after netmedia-document changes in AIToolbelt, then commit the folder.
    A generated copy: never edit it here.

.PARAMETER AIToolbelt
    The AIToolbelt clone (default: next to this repository, or NETMEDIA_AITOOLBELT).

.EXAMPLE
    .\tools\update-netmedia-document.ps1
#>
[CmdletBinding()]
param([string]$AIToolbelt)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not $AIToolbelt) { $AIToolbelt = $env:NETMEDIA_AITOOLBELT }
if (-not $AIToolbelt) { $AIToolbelt = Join-Path (Split-Path $repo -Parent) 'AIToolbelt' }
$from = Join-Path $AIToolbelt 'plugins/netmedia-document'
if (-not (Test-Path -LiteralPath (Join-Path $from 'scripts/netmedia_document.py'))) { throw "No netmedia-document in $from (-AIToolbelt <the clone>)." }
$to = Join-Path $repo 'tools/lazyspec/netmedia-document'
if (Test-Path -LiteralPath $to) { Remove-Item -LiteralPath $to -Recurse -Force }
$files = @(
    'scripts/netmedia_document.py', 'scripts/docx_render.py', 'scripts/docx_tools.py', 'scripts/html_source.py',
    'scripts/render_images.py', 'scripts/word-finish.ps1', 'scripts/word-finish.applescript',
    'theme/Document template.docx', 'theme/brand.json', 'theme/images/logo.png', 'LICENSE'
)
foreach ($f in $files) {
    $target = Join-Path $to $f
    [void](New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent))
    Copy-Item -LiteralPath (Join-Path $from $f) -Destination $target -Force
}
$head = (& git -C $AIToolbelt rev-parse --short HEAD 2>$null)
if (& git -C $AIToolbelt status --porcelain -- plugins/netmedia-document/scripts plugins/netmedia-document/theme 2>$null) { $head = "$head + uncommitted changes" }
$version = (Get-Content -Raw -Encoding UTF8 (Join-Path $from 'theme/brand.json') | ConvertFrom-Json).version
$note = "Copied from AIToolbelt $head (plugins/netmedia-document, theme $version) by tools/update-netmedia-document.ps1; do not edit.`n"
[IO.File]::WriteAllText((Join-Path $to 'SOURCE.txt'), $note, (New-Object Text.UTF8Encoding $false))
Write-Host "  netmedia-document -> $to (AIToolbelt $head, theme $version)" -ForegroundColor Green

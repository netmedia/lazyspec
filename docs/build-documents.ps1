#Requires -Version 5.1
<#
.SYNOPSIS
Builds the Word documents (and PDFs) docs/documents.json lists, with the netmedia-document plugin - the Netmedia
cover, contents, styles and document history, the same in every Netmedia repository.

.DESCRIPTION
The documents, their sources, titles, versions and history are in docs/documents.json; this script only finds
the tools and runs:

    python <netmedia-document>/scripts/netmedia_document.py --documents docs/documents.json

netmedia-document: -Plugin, else NETMEDIA_DOCUMENT_PLUGIN, else the AIToolbelt clone next to this repository
(plugins/netmedia-document), else the newest installed copy under ~/.claude/plugins. Python: the Netmedia
environment (~/.netmedia/python), else python on the PATH, with python-docx. Word (Windows or macOS) fills in
the contents' page numbers and writes the PDFs.

.PARAMETER Only
Only these documents (their output names, with or without .docx).

.PARAMETER Pdf
PDFs of every document too (a document with "pdf": true in documents.json always gets one).

.EXAMPLE
.\docs\build-documents.ps1
.\docs\build-documents.ps1 -Only LazySpec-Reference -Pdf
#>
[CmdletBinding()]
param([string[]]$Only, [switch]$Pdf, [string]$Plugin)

$ErrorActionPreference = 'Stop'
$docs = $PSScriptRoot
$repo = Split-Path $docs -Parent

function Test-Plugin([string]$Dir) { return $Dir -and (Test-Path -LiteralPath (Join-Path $Dir 'scripts/netmedia_document.py')) }
$candidates = @($Plugin, $env:NETMEDIA_DOCUMENT_PLUGIN, (Join-Path (Split-Path $repo -Parent) 'AIToolbelt/plugins/netmedia-document'))
$found = $candidates | Where-Object { Test-Plugin $_ } | Select-Object -First 1
if (-not $found) {
    $installed = Join-Path $HOME '.claude/plugins'
    if (Test-Path -LiteralPath $installed) {
        $script = Get-ChildItem -LiteralPath $installed -Recurse -Filter netmedia_document.py -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match 'netmedia-document' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($script) { $found = Split-Path (Split-Path $script.FullName -Parent) -Parent }
    }
}
if (-not $found) { throw 'netmedia-document not found: /plugin install netmedia-document --marketplace netmedia/aitoolbelt, or -Plugin <its folder>.' }

$python = @((Join-Path $HOME '.netmedia/python/Scripts/python.exe'), (Join-Path $HOME '.netmedia/python/bin/python3')) |
    Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $python) { $python = @('python', 'python3', 'py') | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1 }
if (-not $python) { throw 'Python 3.10+ is needed (the Netmedia environment ~/.netmedia/python, or python on the PATH).' }

$arguments = @((Join-Path $found 'scripts/netmedia_document.py'), '--documents', (Join-Path $docs 'documents.json'))
if ($Pdf) { $arguments += '--pdf' }
if ($Only) { $arguments += '--only'; $arguments += $Only }
Write-Host "  netmedia-document: $found" -ForegroundColor Cyan
& $python @arguments
if ($LASTEXITCODE) { throw "netmedia_document.py ended with exit code $LASTEXITCODE" }

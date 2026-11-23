#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  docs\build-examples.ps1                                   |
#  |   The demo project's exports in docs\examples\, made by LazySpec itself  |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Exports the demo project (examples\acme-portal) into docs\examples\: what a client gets - the specification
    with the plan, one change, a saved bundle. Word and PDF are Netmedia documents (netmedia-document); PDF
    needs Microsoft Word.

.DESCRIPTION
    LazySpec's own documents (the guide, the reference, the README) are built by docs\build-documents.ps1
    from docs\documents.json, as in every Netmedia repository.

.EXAMPLE
    .\docs\build-examples.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$shell = (Get-Process -Id $PID).Path
$demo = Join-Path $repo 'examples\acme-portal'
$out = Join-Path $PSScriptRoot 'examples'
[void](New-Item -ItemType Directory -Force -Path $out)

# lazyspec in a PowerShell of its own (it ends with exit), in the demo project; stops on a failed export.
function Invoke-Export([string[]]$Arguments) {
    Push-Location $demo
    try {
        & $shell -NoProfile -File $lazyspec @Arguments -KeepDiagrams | ForEach-Object { Write-Host "    $_" }
        if ($LASTEXITCODE) { throw "lazyspec $($Arguments -join ' ') failed (exit code $LASTEXITCODE)" }
    }
    finally { Pop-Location }
}

Write-Host ''
Write-Host '  examples: the specification with the plan, one change, a saved bundle' -ForegroundColor Cyan
Invoke-Export @('-Export', 'Pdf', '-IncludeChanges', '-ClientFriendly', '-Out', (Join-Path $out 'Acme-Portal-Specification.pdf'))
Invoke-Export @('-Export', 'Pdf', '-Item', '01-add-user-signup', '-ClientFriendly', '-Out', (Join-Path $out 'Acme-Portal-Add-user-sign-up.pdf'))
Invoke-Export @('-Export', 'Word', '-Item', '01-add-user-signup', '-ClientFriendly', '-Out', (Join-Path $out 'Acme-Portal-Add-user-sign-up.docx'))
Invoke-Export @('-Export', 'Pdf', '-Item', 'accounts-and-orders', '-ClientFriendly', '-Out', (Join-Path $out 'Acme-Portal-Accounts-and-orders.pdf'))
Write-Host ''
Write-Host "  Done: $out" -ForegroundColor Green

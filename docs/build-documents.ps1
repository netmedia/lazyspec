#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  docs\build-documents.ps1                                  |
#  |   The documents in docs\, made by LazySpec itself                        |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Makes the documents in docs\ from the repository's Markdown and the demo project, in a document theme
    (Netmedia's: the templates\ folder of the AIToolbelt repository).

.DESCRIPTION
    - docs\LazySpec-Developer-Guide.docx / .pdf   from docs\developer-guide.md
    - docs\LazySpec-Reference.docx / .pdf         from tools\lazyspec\LAZYSPEC.md
    - docs\LazySpec-README.docx / .pdf            from README.md
    - docs\examples\                              exports of the demo project (examples\acme-portal): the
                                                  specification with the plan, one change, a saved bundle

    The reference and the README get their cover's subtitle and contents from front matter added to a copy
    next to them (removed afterwards): the Markdown files stay as GitHub shows them.

.PARAMETER Theme
    The document theme (.yaml). Default: ..\AIToolbelt\templates\document-theme.yaml next to this repository.

.EXAMPLE
    .\docs\build-documents.ps1
    .\docs\build-documents.ps1 -Theme D:\Development\Netmedia\AIToolbelt\templates\document-theme.yaml
#>
[CmdletBinding()]
param([string]$Theme)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
if (-not $Theme) { $Theme = Join-Path (Split-Path $repo -Parent) 'AIToolbelt\templates\document-theme.yaml' }
if (-not (Test-Path -LiteralPath $Theme)) { throw "The document theme isn't there: $Theme (-Theme <path>)" }
$Theme = (Resolve-Path -LiteralPath $Theme).Path
$docs = Join-Path $repo 'docs'
$shell = (Get-Process -Id $PID).Path
$utf8 = New-Object Text.UTF8Encoding $false

# lazyspec in a PowerShell of its own (it ends with exit), in $Dir; stops on a failed export.
function Invoke-Export([string]$Dir, [string[]]$Arguments) {
    Push-Location $Dir
    try {
        & $shell -NoProfile -ExecutionPolicy Bypass -File $lazyspec @Arguments -Theme $Theme -KeepDiagrams | ForEach-Object { Write-Host "    $_" }
        if ($LASTEXITCODE) { throw "lazyspec $($Arguments -join ' ') failed (exit code $LASTEXITCODE)" }
    }
    finally { Pop-Location }
}
# A Markdown file in both formats; $FrontMatter: a copy with it, next to the file (its links still work).
function Export-Markdown([string]$Source, [string]$Name, [string]$FrontMatter) {
    $md = $Source
    if ($FrontMatter) {
        $md = Join-Path (Split-Path $Source -Parent) ".$Name.md"
        [IO.File]::WriteAllText($md, "---`n$FrontMatter`n---`n`n" + [IO.File]::ReadAllText($Source), $utf8)
    }
    try {
        foreach ($f in 'Word', 'Pdf') {
            $ext = @{ Word = 'docx'; Pdf = 'pdf' }[$f]
            Write-Host "  $Name.$ext" -ForegroundColor Cyan
            Invoke-Export $repo @('-Export', $f, '-Markdown', $md, '-Out', (Join-Path $docs "$Name.$ext"))
        }
    }
    finally { if ($FrontMatter) { Remove-Item -LiteralPath $md -Force -ErrorAction SilentlyContinue } }
}

Write-Host ''
Write-Host "  LazySpec documents, theme: $Theme" -ForegroundColor Cyan
Export-Markdown (Join-Path $docs 'developer-guide.md') 'LazySpec-Developer-Guide' ''
Export-Markdown (Join-Path $repo 'tools\lazyspec\LAZYSPEC.md') 'LazySpec-Reference' "subtitle: Reference`nauthor: Netmedia`nlanguage: en`ntoc: true"
Export-Markdown (Join-Path $repo 'README.md') 'LazySpec-README' "subtitle: Overview, install and use`nauthor: Netmedia`nlanguage: en`ntoc: true"

# The demo project's exports: what a client gets.
$demo = Join-Path $repo 'examples\acme-portal'
$out = Join-Path $docs 'examples'
[void](New-Item -ItemType Directory -Force -Path $out)
Write-Host '  examples: the specification with the plan, one change, a saved bundle' -ForegroundColor Cyan
Invoke-Export $demo @('-Export', 'Pdf', '-IncludeChanges', '-ClientFriendly', '-Out', (Join-Path $out 'Acme-Portal-Specification.pdf'))
Invoke-Export $demo @('-Export', 'Pdf', '-Item', '01-add-user-signup', '-ClientFriendly', '-Out', (Join-Path $out 'Acme-Portal-Add-user-sign-up.pdf'))
Invoke-Export $demo @('-Export', 'Word', '-Item', '01-add-user-signup', '-ClientFriendly', '-Out', (Join-Path $out 'Acme-Portal-Add-user-sign-up.docx'))
Invoke-Export $demo @('-Export', 'Pdf', '-Item', 'accounts-and-orders', '-ClientFriendly', '-Out', (Join-Path $out 'Acme-Portal-Accounts-and-orders.pdf'))
Write-Host ''
Write-Host "  Done: $docs" -ForegroundColor Green

#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-Translation.ps1                                |
#  |   -Language (DeepL), -AddLanguage, the Hasek check of Croatian           |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests the export in another language: no network (LAZYSPEC_DEEPL_FAKE and LAZYSPEC_HASEK_FAKE stand in for
    DeepL and ispravi.me). It builds its own project in %TEMP%.

.DESCRIPTION
    1. Not set up (no translation: provider: deepl): -Language another than the documents' fails clearly.
    2. A key in config.yaml (in git): refused.
    3. en -> de (stable, markup handling): the body translated, code and LazySpec's labels kept, German labels.
    4. hr source (DeepL beta): without -Beta a clear error; with -Beta translated piece by piece.
    5. en -> hr with translation: hasek: always: a Hasek report next to the document.
    6. The cache: a second export sends nothing to DeepL.
    7. -AddLanguage: a new block in export-texts.json (a copy of the kit), refused when it exists, -Force replaces it.

.PARAMETER Keep
    Keep the test files in %TEMP%.
#>
[CmdletBinding()]
param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
$ps = (Get-Process -Id $PID).Path
$work = Join-Path ([IO.Path]::GetTempPath() -replace '^/var/', '/private/var/') ('lazyspec-translation-' + [guid]::NewGuid().ToString('N'))
$kit = Join-Path $work 'kit'
[void](New-Item -ItemType Directory -Force -Path $kit)
foreach ($f in @('lazyspec.ps1', 'export-texts.json', 'kit.json')) { Copy-Item (Join-Path (Join-Path $repo 'tools') (Join-Path 'lazyspec' $f)) $kit }
$lazyspec = Join-Path $kit 'lazyspec.ps1'
$utf8 = New-Object Text.UTF8Encoding $false
$cacheHome = Join-Path $work 'cache'

function New-Project([string]$Name, [string]$Translation, [string]$Lang = 'en') {
    $dir = Join-Path $work $Name
    $spec = Join-Path (Join-Path (Join-Path $dir 'openspec') 'specs') 'user-login'
    [void](New-Item -ItemType Directory -Force -Path $spec)
    [IO.File]::WriteAllText((Join-Path (Join-Path $dir 'openspec') 'config.yaml'), "schema: spec-driven`n$Translation`nlazyspec:`n  name: Acme Portal`n  language: $Lang`n", $utf8)
    $text = "# User login`n`n## Purpose`nLets users sign in with a password and see greska.`n`n## Requirements`n`n### Requirement: Password sign-in`nThe system SHALL let a user sign in with ``secret-code`` only.`n`n#### Scenario: Good password`n- **WHEN** the user enters the right password`n- **THEN** the dashboard opens`n"
    [IO.File]::WriteAllText((Join-Path $spec 'spec.md'), $text, $utf8)
    return $dir
}
function Invoke-Export([string]$Dir, [string[]]$More) {
    Push-Location $Dir
    try {
        $env:LOCALAPPDATA = $cacheHome
        $out = $null | & $ps -NoProfile -File $lazyspec -Export Html -KeepDiagrams -Out (Join-Path $Dir 'out.html') @More 2>&1 | Out-String
        return [pscustomobject]@{ Code = $LASTEXITCODE; Out = $out; Html = $(if (Test-Path (Join-Path $Dir 'out.html')) { [IO.File]::ReadAllText((Join-Path $Dir 'out.html')) } else { '' }) }
    } finally { Pop-Location }
}

$oldFake = $env:LAZYSPEC_DEEPL_FAKE; $oldHasek = $env:LAZYSPEC_HASEK_FAKE; $oldLocal = $env:LOCALAPPDATA
try {
    $env:LAZYSPEC_DEEPL_FAKE = '1'; $env:LAZYSPEC_HASEK_FAKE = '1'
    Write-Host "`n  LazySpec translation`n"

    $p = New-Project 'plain' ''
    $r = Invoke-Export $p @('-Language', 'de')
    Check ($r.Code -eq 1 -and $r.Out -match 'set up DeepL first') '1 not set up: a clear error' $r.Out

    $p = New-Project 'leak' "translation:`n  provider: deepl`n  authKey: abc:fx"
    $r = Invoke-Export $p @('-Language', 'de')
    Check ($r.Code -eq 1 -and $r.Out -match 'config.yaml is in git') '2 a key in config.yaml is refused' $r.Out

    $p = New-Project 'de' "translation:`n  provider: deepl"
    $r = Invoke-Export $p @('-Language', 'de')
    Check ($r.Code -eq 0) '3 en -> de exports' $r.Out
    Check ($r.Html -match '\[DE\] Lets users sign in') '3 the body is translated' ($r.Html.Substring(0, [Math]::Min(400, $r.Html.Length)))
    Check ($r.Html -match '<code>secret-code</code>') '3 code is kept'
    Check ($r.Html -notmatch 'translate="no"') '3 the markers are removed'
    Check ($r.Html -match '<span class="tag">Anforderung</span>') '3 German labels, not translated again'
    Check ($r.Out -match 'translated en -> de \(DeepL\)') '3 says it is translated' $r.Out

    $p = New-Project 'hr' "translation:`n  provider: deepl" 'hr'
    $r = Invoke-Export $p @('-Language', 'en')
    Check ($r.Code -eq 1 -and $r.Out -match 'Croatian: DeepL beta' -and $r.Out -match '-Beta') '4 beta source without -Beta: a clear error' $r.Out
    $r = Invoke-Export $p @('-Language', 'en', '-Beta')
    Check ($r.Code -eq 0 -and $r.Html -match '\[EN\] Lets users sign in' -and $r.Out -match 'piece by piece') '4 with -Beta: piece by piece' $r.Out
    Check ($r.Html -match '<code>secret-code</code>') '4 code is kept piece by piece'

    $p = New-Project 'tohr' "translation:`n  provider: deepl`n  hasek: always"
    $r = Invoke-Export $p @('-Language', 'hr', '-Beta')
    $report = Join-Path $p 'out.hasek.md'
    Check ($r.Code -eq 0 -and (Test-Path $report)) '5 Croatian translation: a Hasek report' $r.Out
    if (Test-Path $report) { Check ([IO.File]::ReadAllText($report) -match '\*\*greska\*\*') '5 the report lists the finding' }

    $p = New-Project 'cache' "translation:`n  provider: deepl"
    $r1 = Invoke-Export $p @('-Language', 'de')
    $cache = Get-ChildItem -Recurse -File $cacheHome | Where-Object { $_.Name -eq 'en-de.json' }
    Check ([bool]$cache) '6 the cache is written' ''
    $before = [IO.File]::ReadAllText($cache[0].FullName)
    $r2 = Invoke-Export $p @('-Language', 'de')
    Check ($r2.Code -eq 0 -and [IO.File]::ReadAllText($cache[0].FullName) -eq $before -and $r2.Html -eq $r1.Html) '6 a second export uses the cache' ''

    $p = New-Project 'addlang' "translation:`n  provider: deepl"
    Push-Location $p
    try {
        $out = $null | & $ps -NoProfile -File $lazyspec -AddLanguage it 2>&1 | Out-String
        $j = [IO.File]::ReadAllText((Join-Path $kit 'export-texts.json')) | ConvertFrom-Json
        Check ($LASTEXITCODE -eq 0 -and $j.it.labels.proposal -eq '[IT] Proposal' -and $j.it.labels.dateFormat -eq 'yyyy-MM-dd') '7 -AddLanguage adds the block' $out
        Check (@($j.it.headings.PSObject.Properties).Count -gt 0) '7 headings translated too'
        $out = $null | & $ps -NoProfile -File $lazyspec -AddLanguage it 2>&1 | Out-String
        Check ($LASTEXITCODE -eq 1 -and $out -match 'already has') '7 refused when it exists' $out
        $out = $null | & $ps -NoProfile -File $lazyspec -AddLanguage it -Force 2>&1 | Out-String
        $raw = [IO.File]::ReadAllText((Join-Path $kit 'export-texts.json'))
        Check ($LASTEXITCODE -eq 0 -and ([regex]::Matches($raw, '"it"\s*:')).Count -eq 1) '7 -Force replaces it' $out
        $j = $raw | ConvertFrom-Json
        Check ([bool]$j.hr.labels.proposal -and [bool]$j.de.labels.proposal) '7 the other languages stay'
    } finally { Pop-Location }
}
finally {
    $env:LAZYSPEC_DEEPL_FAKE = $oldFake; $env:LAZYSPEC_HASEK_FAKE = $oldHasek; $env:LOCALAPPDATA = $oldLocal
    if (-not $Keep) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-TestSummary $(if ($Keep) { $work })
if ($script:failed) { exit 1 }

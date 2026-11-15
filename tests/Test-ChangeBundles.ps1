#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-ChangeBundles.ps1                              |
#  |   Several changes as one whole: m, x (chosen changes), -Item a,b,c       |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests changes as one whole: read and exported together, saved as named wholes in openspec\config.yaml.
    No modules: it builds its own project in %TEMP%.

.DESCRIPTION
    1. -Item a,b -Title: one document, a chapter per kind of document, each change's part under its title;
       the title on the cover and in the file's name (without accents).
    2. The cover's counts in the language's form (hr: 1 promjena, 2 promjene, 5 promjena).
    3. An archived change by its name; an unknown name: an error, exit code 1.
    4. m: mark changes, a title, saved in config.yaml (the rest of the file as it was); read together.
    5. m: a saved whole first; Enter reads it; d removes it (config.yaml back as it was).
    6. -Item <a saved whole's key>: its changes, its title, the file named by its key.
    7. x with no specs: chosen changes, as one.
    8. A heading left with nothing under it (a comment only) isn't shown.
    9. PDF: the contents with page numbers.
   10. A table's columns as wide as their words and identifiers; the rest to the longest text.
   11. The changes' diagrams at the top of the specifications, before their capabilities.

.PARAMETER Keep
    Keep the test files in %TEMP%.

.EXAMPLE
    .\tests\Test-ChangeBundles.ps1
#>
[CmdletBinding()]
param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$work = Join-Path ([IO.Path]::GetTempPath() -replace '^/var/', '/private/var/') ('lazyspec-bundle-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

$utf8 = New-Object Text.UTF8Encoding $false
function Write-File([string]$Path, [string]$Text) { [void](New-Item -ItemType Directory -Force -Path (Split-Path $Path)); [IO.File]::WriteAllText($Path, $Text, $utf8) }
function New-Change([string]$Dir, [string]$Title, [string]$Cap, [int]$Tasks) {
    Write-File (Join-Path $Dir 'proposal.md') "# Proposal: $Title`n`n## Why`nBecause of $Title.`n`n## What Changes`n- $Title`n`n## Capabilities`n### New Capabilities`n- ``$Cap```n`n### Modified Capabilities`n<!-- none -->`n`n## Impact`n- Code`n"
    Write-File (Join-Path $Dir 'design.md') "# Design: $Title`n`n## Decisions`nThe $Title way.`n`n| Change | Field | Type | Description |`n|---|---|---|---|`n| + | ``BackofficeUserId`` | ``int?`` | the employee who erased the guest's personal data from an enquiry or a reservation; empty for every other event |`n"
    $t = "# Tasks`n`n## 1. Work`n"
    for ($i = 1; $i -le $Tasks; $i++) { $t += "- [ ] 1.$i Task $i of $Title`n" }
    Write-File (Join-Path $Dir 'tasks.md') $t
    Write-File (Join-Path $Dir "specs\$Cap\spec.md") "## ADDED Requirements`n### Requirement: $Title works`nThe system SHALL do $Title.`n`n#### Scenario: It works`n- **WHEN** asked`n- **THEN** $Title happens`n"
}
# The TUI with test keys in $Dir: its frames (snap).
function Invoke-Keys([string]$Dir, [string]$Keys) {
    $frames = Join-Path $work ('frames-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.txt')
    & $script:shell -NoProfile -ExecutionPolicy Bypass -File $lazyspec -Root $Dir -Width 110 -Height 32 -Keys $Keys -Frames $frames 2>&1 | Out-Null
    if (Test-Path -LiteralPath $frames) { return [IO.File]::ReadAllText($frames, $utf8) }
    return ''
}

$c = [string][char]0x10D
$proj = Join-Path $work 'proj'
$cfgPath = Join-Path $proj 'openspec\config.yaml'
$cfgText = "schema: spec-driven`n`nlazyspec:`n  name: Acme Portal`n  language: hr`n  titles:`n    add-alpha:`n      cap-alpha: Alpha capability`n  diagrams:`n    add-alpha:`n      change: flow.png`n`nrules:`n  proposal:`n    - Keep it short`n"
Write-File $cfgPath $cfgText
New-Change (Join-Path $proj 'openspec\changes\add-alpha') 'Alpha' 'cap-alpha' 1
[IO.File]::WriteAllBytes((Join-Path $proj 'openspec\changes\add-alpha\flow.png'), (Get-Png 120 80 'SteelBlue'))
New-Change (Join-Path $proj 'openspec\changes\add-beta') 'Beta' 'cap-beta' 2
New-Change (Join-Path $proj 'openspec\changes\add-gamma') 'Gamma' 'cap-gamma' 2
New-Change (Join-Path $proj 'openspec\changes\archive\2026-01-01-add-old') 'Old' 'cap-old' 1

Write-Host ''
Write-Host '  Changes as one' -ForegroundColor Cyan

try {
    # 1. -Item a,b -Title: one document.
    $out = Join-Path $work 'two.html'
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Item', 'add-alpha,add-beta', '-Title', 'Alpha and Beta', '-Out', $out)
    Check ($r.Code -eq 0) '-Item a,b: exported' $r.Out
    $h = [IO.File]::ReadAllText($out, $utf8)
    $h1 = @([regex]::Matches($h, '<h1 id="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    Check (($h1 -join ',') -eq 'doc-proposal,doc-specs,doc-design,doc-tasks') 'a chapter per kind of document, in the workflow''s order' ($h1 -join ',')
    $prop = [regex]::Match($h, '(?s)<h1 id="doc-proposal">.*?(?=<h1 )').Value
    Check ($prop -match '<h2>Alpha</h2>' -and $prop -match '<h2>Beta</h2>' -and $prop.IndexOf('<h2>Alpha</h2>') -lt $prop.IndexOf('<h2>Beta</h2>')) 'each change''s part under its title, in the given order'
    Check ($prop -match 'Because of Alpha' -and $prop -match 'Because of Beta') 'both proposals in the chapter'
    Check ($prop -match 'New Capabilities|Nove funkcionalnosti' -and $prop -notmatch 'Modified Capabilities|Izmijenjene funkcionalnosti') 'a heading with nothing under it (a comment only): not shown'
    Check ($h -match '<p class="subtitle">Alpha and Beta</p>') '-Title on the cover'
    Check ($h -match 'Alpha capability' -and $h -match 'cap-beta') 'both changes'' capabilities (their titles from config.yaml)'
    Check ($h -match '<ul class="toc-list"><li><a href="#cap-add-alpha-cap-alpha">[^<]*</a></li><li><a href="#cap-add-beta-cap-beta">') 'one contents of all their capabilities'

    # 11. The changes' diagrams: at the top of the specifications, before their contents and capabilities.
    $specsCh = [regex]::Match($h, '(?s)<h1 id="doc-specs">.*?(?=<h1 )').Value
    $at = $specsCh.IndexOf('class="diagram"')
    Check ($at -gt 0 -and $at -lt $specsCh.IndexOf('class="toc-list"') -and $prop -notmatch 'class="diagram"') 'the changes'' diagrams at the top of the specifications' "at $at"

    # 10. A table's columns: each as wide as its longest word or identifier, the rest to the description.
    $cols = @([regex]::Matches([regex]::Match($h, '(?s)<table class="sized">\s*<colgroup>(.*?)</colgroup>').Groups[1].Value, 'width: ([\d.]+)%') | ForEach-Object { [double]::Parse($_.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) })
    Check ($cols.Count -eq 4 -and $cols[3] -gt 45 -and $cols[1] -gt $cols[2] -and $cols[1] -gt 15 -and $cols[2] -gt 8) 'a table''s columns: as wide as their words, the rest to the description' ($cols -join ', ')

    # 2. The cover's counts in Croatian forms: 2 changes, 4 documents, 2 capabilities, 3 tasks.
    Check ($h -match '2 planirane promjene, 4 dokumenta, 2 funkcionalnosti, 3 zadatka') 'counts in the language''s form (few)' ([regex]::Match($h, 'Opseg: [^<]*').Value)
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Item', 'add-alpha', '-Out', (Join-Path $work 'one.html'))
    $h = [IO.File]::ReadAllText((Join-Path $work 'one.html'), $utf8)
    Check ($h -match '4 dokumenta, 1 funkcionalnost, 1 zadatak') 'counts in the language''s form (one)' ([regex]::Match($h, 'Opseg: [^<]*').Value)

    # 1. The file's name: the title without accents.
    $exp = Join-Path $proj 'export'
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Item', 'add-alpha,add-gamma', '-Title', "Ra${c}un i rezervacije")
    $f = @(Get-ChildItem -LiteralPath $exp -Filter '*.html' | Where-Object { $_.Name -like 'proj-racun-i-rezervacije-*' })
    Check ($r.Code -eq 0 -and $f.Count -eq 1) 'the file named by the title, without accents' (@(Get-ChildItem -LiteralPath $exp -Name) -join ', ')

    # 9. PDF: the contents' page numbers (read from a first print, then printed again).
    $r = Invoke-LazySpec $lazyspec $proj 'Pdf' @('-Item', 'add-alpha,add-beta', '-Out', (Join-Path $work 'two.pdf'))
    Check ($r.Code -eq 0 -and $r.Out -match "contents' page numbers: printing again" -and $r.Out -notmatch 'without page numbers') 'PDF: the contents with page numbers' $r.Out

    # 3. An archived change by its name; an unknown one.
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Item', 'add-alpha,add-old', '-Out', (Join-Path $work 'old.html'))
    Check ($r.Code -eq 0 -and [IO.File]::ReadAllText((Join-Path $work 'old.html'), $utf8) -match 'Because of Old') 'an archived change by its name'
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Item', 'add-alpha,add-nothing', '-Out', (Join-Path $work 'x.html'))
    Check ($r.Code -eq 1 -and $r.Out -match "add-nothing") 'an unknown change: an error, exit code 1' $r.Out

    # 4. m: mark beta and gamma, a title, save it.
    $fr = Invoke-Keys $proj 'm,snap,Space,Down,Space,Down,Space,snap,Enter,text:Beta Gamma,Enter,snap,s,snap'
    Check ($fr -match '\[.\] . Beta' -and $fr -match '2 marked') 'm: the changes to mark' ([regex]::Match($fr, '(?s)----- snap pick -----.*?(?=-----)').Value)
    Check ($fr -match "Save it as 'beta-gamma' in openspec/config.yaml\?") 'a new whole: save it?'
    Check ($fr -match 'Proposal \(2\)' -and $fr -match 'Beta Gamma') 'read together: a tab per kind of document, the title'
    $saved = [IO.File]::ReadAllText($cfgPath, $utf8)
    $want = "schema: spec-driven`n`nlazyspec:`n  name: Acme Portal`n  language: hr`n  titles:`n    add-alpha:`n      cap-alpha: Alpha capability`n  diagrams:`n    add-alpha:`n      change: flow.png`n  bundles:`n    beta-gamma:`n      title: `"Beta Gamma`"`n      changes: add-beta, add-gamma`n`nrules:`n  proposal:`n    - Keep it short`n"
    Check ($saved -eq $want) 'saved under lazyspec: bundles:, the rest of config.yaml as it was' $saved

    # 6. -Item <key>: its changes and title, the file named by its key.
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Item', 'beta-gamma')
    $f = @(Get-ChildItem -LiteralPath $exp -Filter 'proj-beta-gamma-*.html')
    Check ($r.Code -eq 0 -and $f.Count -eq 1) '-Item <a saved whole>: exported, named by its key' $r.Out
    if ($f.Count) {
        $h = [IO.File]::ReadAllText($f[0].FullName, $utf8)
        Check ($h -match '<p class="subtitle">Beta Gamma</p>' -and $h -match 'Because of Gamma' -and $h -notmatch 'Because of Alpha') '-Item <a saved whole>: its title, its changes'
    }

    # 5. m: the saved whole first; Enter reads it; d removes it.
    $fr = Invoke-Keys $proj 'm,snap,Enter,snap'
    Check ($fr -match 'SAVED' -and $fr -match 'Beta Gamma\s+2 changes') 'm: the saved wholes first'
    Check ($fr -match '(?s)----- snap read -----.*Beta Gamma.*Proposal \(2\)') 'Enter on a saved whole: read it'
    # A second whole, then the first one removed: the other stays.
    $fr = Invoke-Keys $proj 'm,Down,Down,Space,Enter,text:Alpha Beta,Enter,s'
    $fr = Invoke-Keys $proj 'm,d,snap,y,snap'
    Check ($fr -match "Remove the saved whole 'Beta Gamma'") 'd: asked first'
    $saved = [IO.File]::ReadAllText($cfgPath, $utf8)
    Check ($saved -notmatch 'beta-gamma' -and $saved -match '    alpha-beta:\n      title: "Alpha Beta"\n      changes: add-alpha, add-beta\n\nrules:') 'd: removed, the other one stays' $saved
    [void](Invoke-Keys $proj 'm,d,y')
    Check ([IO.File]::ReadAllText($cfgPath, $utf8) -eq $cfgText) 'the last one removed: config.yaml as it was'

    # 7. x with no specs: chosen changes, as one (up to the audience question: nothing is exported).
    $fr = Invoke-Keys $proj 'x,snap,h,snap,c,snap,a,Enter,text:All three,Enter,n,snap,Esc'
    Check ($fr -match '\? Export as\s+PDF\s+Word\s+HTML') 'x, no specs: the format'
    Check ($fr -match 'Chosen changes, as one') 'x, no specs: this change or chosen changes'
    Check ($fr -match 'HTML for:') 'chosen changes: then for the client or technical'
}
finally {
    if (-not $Keep) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-TestSummary $(if ($Keep) { $work })
exit [int]($script:failed -gt 0)

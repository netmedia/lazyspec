#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-Groups.ps1                                     |
#  |   Groups of changes: the plan by group, chosen groups, their export      |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests groups of changes (openspec/config.yaml groups:, groupLabel; a change's x-group: <id>). No modules:
    it builds its own projects in %TEMP%.

.DESCRIPTION
    1. A change's group: x-group, else the "<label>: <id>" line under its title, else the folder's g<id>-,
       else ungrouped; the plan by group (by id, ungrouped last), the project's word for a group.
    2. A change's number and title without g<id>-, "Proposal:" and "G1 -".
    3. A group's details: its description, what it requires and what requires it, its changes, the changes
       that name another group's.
    4. Space chooses groups, the ones they require come too (+); Esc unchooses; c folds; g flat.
    5. Find: g2 / phase 1 with the words: only that group's.
    6. -Groups 2: a part per group (the required one first), the names on the cover; -Item group:2 alone; a
       saved whole with groups:.
    7. A schema with grouping: [group] groups by the folders' g<id>- too; without it (and no x-group): flat.

.PARAMETER Keep
    Keep the test files in %TEMP%.

.EXAMPLE
    .\tests\Test-Groups.ps1
#>
[CmdletBinding()]
param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$work = Join-Path ([IO.Path]::GetTempPath() -replace '^/var/', '/private/var/') ('lazyspec-groups-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

$utf8 = New-Object Text.UTF8Encoding $false
$dash = [string][char]0x2013; $mid = [string][char]0x00B7; $ok = [string][char]0x2713
$open = [string][char]0x25BE; $shut = [string][char]0x25B9
function Write-File([string]$Path, [string]$Text) { [void](New-Item -ItemType Directory -Force -Path (Split-Path $Path)); [IO.File]::WriteAllText($Path, $Text, $utf8) }
function New-Change([string]$Dir, [string]$H1, [string]$Under, [string]$Group, [string]$Cap, [int]$Tasks, [string]$Note) {
    Write-File (Join-Path $Dir 'proposal.md') "# $H1`n`n$Under`n`n## Why`nBecause. $Note`n`n## What Changes`n- It`n"
    $t = "# Tasks`n`n## 1. Work`n"
    for ($i = 1; $i -le $Tasks; $i++) { $t += "- [ ] 1.$i Task $i works`n" }
    Write-File (Join-Path $Dir 'tasks.md') $t
    Write-File (Join-Path $Dir "specs\$Cap\spec.md") "## ADDED Requirements`n### Requirement: $Cap works`nThe system SHALL do it.`n`n#### Scenario: It works`n- **WHEN** asked`n- **THEN** it happens`n"
    $y = "schema: spec-driven`ncreated: 2026-11-19`n"
    if ($Group) { $y += "x-group: $Group`n" }
    Write-File (Join-Path $Dir '.openspec.yaml') $y
}
function Invoke-Keys([string]$Dir, [string]$Keys) {
    $frames = Join-Path $work ('frames-' + [guid]::NewGuid().ToString('N').Substring(0, 6) + '.txt')
    & $script:shell -NoProfile -ExecutionPolicy Bypass -File $lazyspec -Root $Dir -Width 120 -Height 40 -Keys $Keys -Frames $frames 2>&1 | Out-Null
    $t = ''
    if (Test-Path -LiteralPath $frames) { $t = [IO.File]::ReadAllText($frames, $utf8) }
    # The snaps (not the last screen, "end").
    return , @([regex]::Split($t, '(?m)^----- ') | Where-Object { $_ -and $_ -notmatch '^end ' })
}

# A project: phases 1 (Launch), 2 (Loyalty, requires 1), 3 (Reports); a change in each way of naming its group.
$proj = Join-Path $work 'proj'
Write-File (Join-Path $proj 'openspec\config.yaml') @"
schema: spec-driven

groupLabel: "Phase"
groupLabelPlural: "Phases"
groups:
  - id: 1
    name: "Launch"
    description: "Sign-up and orders live"
    requires: []
  - id: 2
    name: "Loyalty"
    description: >
      Points for every order,
      redeemed at checkout
    requires:
      - 1
  - id: 3
    name: "Reports"

lazyspec:
  name: Demo Shop
  bundles:
    phase-two:
      title: "Phase two"
      groups: 2
"@
New-Change (Join-Path $proj 'openspec\changes\g1-01-add-signup') "Proposal: G1 $mid Add sign-up" '' '1' 'accounts' 2 ''
New-Change (Join-Path $proj 'openspec\changes\add-orders') 'Add orders' "Phase: 1 $dash Launch" '' 'orders' 3 ''
New-Change (Join-Path $proj 'openspec\changes\g2-01-add-points') "G2 $mid Add points" '' '' 'points' 4 'Needs g1-01-add-signup first.'
New-Change (Join-Path $proj 'openspec\changes\add-report') 'Add sales report' '' '3' 'reports' 1 ''
New-Change (Join-Path $proj 'openspec\changes\fix-typo') 'Fix a typo' '' '' 'texts' 1 ''

Write-Host ''
Write-Host '  Groups of changes' -ForegroundColor Cyan
try {
    # 1, 2. The plan by group.
    $f = Invoke-Keys $proj 'snap'
    $home0 = $f[0]
    $order = @('Phase 1 . Launch \(2\)', 'Phase 2 . Loyalty \(1\)', 'Phase 3 . Reports \(1\)', 'Ungrouped \(1\)') | ForEach-Object { $m = [regex]::Match($home0, $_); if ($m.Success) { $m.Index } else { -1 } }
    Check (-not ($order -contains -1) -and $order[0] -lt $order[1] -and $order[1] -lt $order[2] -and $order[2] -lt $order[3]) 'the plan by group: by id, ungrouped last, the project''s word' $home0
    Check ($home0 -match "$open Phase 1 . Launch \(2\)\s+0/5") 'a group''s row: its changes'' count and tasks' $home0
    $p1 = $home0.Substring($order[0], $order[1] - $order[0])
    Check ($p1 -match '01 Add sign-up' -and $p1 -match 'Add orders') 'x-group, and the label line under the title (Phase: 1)' $p1
    $p2 = $home0.Substring($order[1], $order[2] - $order[1])
    Check ($p2 -match 'Add points') 'the folder''s g2- when there is nothing else' $p2
    Check ($home0 -notmatch 'G1 ' -and $home0 -notmatch 'Proposal:' -and $home0 -notmatch 'g1-01') 'a change''s number and title without g1-, Proposal: and G1' $home0
    Check ($home0 -match 'PHASE\s+Phase 1 . Launch' -and $home0 -match 'Sign-up and orders live' -and $home0 -match 'REQUIRED BY' -and $home0 -match 'Phase 2 . Loyalty') 'a group''s details: description, required by' $home0

    # 3. Phase 2's details; 4. choose it: phase 1 comes too.
    $f = Invoke-Keys $proj 'Down,Down,Down,snap,Space,snap,Esc,snap'
    Check ($f[0] -match 'Points for every order, redeemed at checkout' -and $f[0] -match 'REQUIRES' -and $f[0] -match 'ON OTHER PHASES' -and $f[0] -match 'Add points' -and $f[0] -match '01 Add sign-up \(Phase 1 . Launch\)') 'a group''s details: requires, the changes naming another group''s' $f[0]
    Check ($f[1] -match "PLAN [^\n]*$ok 1 \+1" -and $f[1] -match "$ok Phase 2 . Loyalty" -and $f[1] -match '\+ Phase 1 . Launch' -and $f[1] -match 'CHOSEN') 'Space chooses a group; the one it requires comes too (+)' $f[1]
    Check ($f[2] -notmatch "$ok Phase 2" -and $f[2] -notmatch '\+ Phase 1') 'Esc unchooses them' $f[2]
    $f = Invoke-Keys $proj 'c,snap,g,snap'
    Check ($f[0] -match "$shut Phase 1 . Launch \(2\)" -and $f[0] -notmatch '(?m)^\S\s+\S Add orders') 'c folds a group' $f[0]
    Check ($f[1] -notmatch 'Phase 1 . Launch \(' -and $f[1] -match 'Add orders' -and $f[1] -match 'plan: flat') 'g: the plan flat' $f[1]

    # 4. Enter on the chosen: read as one.
    $f = Invoke-Keys $proj 'Down,Down,Down,Space,Enter,snap'
    Check ($f[0] -match '^snap read' -and $f[0] -match 'Phase 1 . Launch, Phase 2 . Loyalty') 'Enter: the chosen groups (and the required) read as one' $f[0]

    # 5. Find in one group.
    $f = @(Invoke-Keys $proj 't,text:g2 works,snap') + @(Invoke-Keys $proj 't,text:phase 1 works,snap')
    Check ($f[0] -match 'Add points' -and $f[0] -notmatch 'Add orders' -and $f[0] -notmatch 'sign-up') 'find g2 <words>: that group''s only' $f[0]
    Check ($f[1] -match 'Add orders' -and $f[1] -match 'sign-up' -and $f[1] -notmatch 'Add points') 'find phase 1 <words>: the project''s word' $f[1]

    # 6. Export.
    $out = Join-Path $work 'g2.html'
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Groups', '2', '-Out', $out)
    Check ($r.Code -eq 0) '-Groups 2: exported' $r.Out
    $h = [IO.File]::ReadAllText($out, $utf8)
    $parts = @([regex]::Matches($h, '<h1 class="part">([^<]+)</h1>') | ForEach-Object { $_.Groups[1].Value })
    Check (($parts -join '|') -eq "Phase 1 $dash Launch|Phase 2 $dash Loyalty") 'a part per group, the required one first' ($parts -join '|')
    Check ($h -match "<p class=`"subtitle`">Phase 1 $dash Launch, Phase 2 $dash Loyalty</p>") 'the groups'' names on the cover'
    Check ($h -match "Requires: Phase 1 $dash Launch" -and $h -match 'Points for every order') 'a part''s description and what it requires'
    Check ($h -match '<h1 id="g1-doc-proposal">' -and $h -match '<h1 id="g2-doc-proposal">' -and $h -match '2 phases, 3 planned changes') 'each group''s changes under it; the scope' ([regex]::Match($h, 'Scope: [^<]*').Value)
    $ids = @([regex]::Matches($h, ' id="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    Check (@($ids | Group-Object | Where-Object { $_.Count -gt 1 }).Count -eq 0) 'no anchor twice'
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Item', 'group:2')
    $file = @(Get-ChildItem -LiteralPath (Join-Path $proj 'openspec\exports') -Filter 'proj-phase-2-*.html')
    Check ($r.Code -eq 0 -and $file.Count -eq 1) '-Item group:2: the file named by the project''s word' (@(Get-ChildItem -LiteralPath (Join-Path $proj 'openspec\exports') -Name) -join ', ')
    if ($file.Count) {
        $h = [IO.File]::ReadAllText($file[0].FullName, $utf8)
        Check (@([regex]::Matches($h, '<h1 class="part">')).Count -eq 1 -and $h -match "Phase 2 $dash Loyalty</h1>") '-Item group:2: that group alone'
    }
    $out = Join-Path $work 'saved.html'
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Item', 'phase-two', '-Out', $out)
    $h = ''
    if (Test-Path -LiteralPath $out) { $h = [IO.File]::ReadAllText($out, $utf8) }
    Check ($r.Code -eq 0 -and $h -match '<p class="subtitle">Phase two</p>' -and @([regex]::Matches($h, '<h1 class="part">')).Count -eq 2) 'a saved whole with groups: those groups and the required, its title' $r.Out

    # 7. A schema with grouping: [group]: the folders' g<id>-; without it and without x-group: flat.
    foreach ($kind in 'grouped', 'flat') {
        $p = Join-Path $work $kind
        $schema = 'spec-driven'
        if ($kind -eq 'grouped') {
            $schema = 'grouped'
            Write-File (Join-Path $p 'openspec\schemas\grouped\schema.yaml') "name: grouped`nversion: 1`ngrouping:`n  - group`nartifacts:`n  - id: proposal`n    generates: proposal.md`n  - id: tasks`n    generates: tasks.md`n    requires: [proposal]`napply:`n  tracks: tasks.md`n"
        }
        Write-File (Join-Path $p 'openspec\config.yaml') "schema: $schema`n"
        foreach ($n in 'g1-add-a', 'g2-add-b') {
            New-Change (Join-Path $p "openspec\changes\$n") "Add $n" '' '' 'cap' 1 ''
            Remove-Item -LiteralPath (Join-Path $p "openspec\changes\$n\.openspec.yaml")
        }
        $f = Invoke-Keys $p 'snap'
        if ($kind -eq 'grouped') { Check ($f[0] -match 'Group 1 \(1\)' -and $f[0] -match 'Group 2 \(1\)') 'grouping: [group] in the schema: by the folders'' g<id>- (Group: the default word)' $f[0] }
        else { Check ($f[0] -notmatch 'Group 1' -and $f[0] -notmatch 'Ungrouped' -and $f[0] -match 'Add g1-add-a') 'no grouping, no x-group: the plan flat, as before' $f[0] }
    }
}
finally {
    if ($Keep) { Write-Host "  kept: $work" } else { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-TestSummary
exit [int]($script:failed -gt 0)

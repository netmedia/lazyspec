#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-ItemIds.ps1                                    |
#  |   Item ids (OSN-T-04): find by id or its beginning, keys.yaml            |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests item ids on a project that has them (vscode\test\fixtures\ids, the same as the extension's tests),
    with test keys: nothing is written into the project.

.DESCRIPTION
    1. An id's beginning (OSN-T-0): those tasks, in id order; the id a label of its own.
    2. An exact id (OSN-T-04) first, then OSN-T-040, OSN-T-041.
    3. Requirements and scenarios under hr headings (Zahtjev:, Scenarij:), open questions, decisions.
    4. openspec/project-tasks.md: its tasks found, as "Project tasks".
    5. A retired id (keys.yaml): what became of it, then its successors; removed: just that.
    6. No id: as before (a task number, words).
    7. Read: a task's and a scenario's id stays in the text.

.EXAMPLE
    .\tests\Test-ItemIds.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$proj = Join-Path $repo 'vscode\test\fixtures\ids'
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
$frames = Join-Path ([IO.Path]::GetTempPath()) ('lazyspec-ids-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')

function Invoke-Keys([string]$Keys) {
    if (Test-Path -LiteralPath $frames) { Remove-Item -LiteralPath $frames }
    & $script:shell -NoProfile -ExecutionPolicy Bypass -File $lazyspec -Root $proj -Width 130 -Height 40 -Keys $Keys -Frames $frames 2>&1 | Out-Null
    $t = ''
    if (Test-Path -LiteralPath $frames) { $t = [IO.File]::ReadAllText($frames, (New-Object Text.UTF8Encoding $false)) }
    return , @([regex]::Split($t, '(?m)^----- ') | Where-Object { $_ -and $_ -notmatch '^end ' })
}
# The order the ids are in on a screen.
# The order the ids are in on a screen: each row's first.
function Get-Ids([string]$Frame, [string]$Rx = '[A-Z]{3}-[A-Z]-\d+') {
    $ids = foreach ($l in $Frame.Split("`n")) { $m = [regex]::Match($l, '(?<=\s)[A-Z]{3}-[A-Z]-\d+(?= )'); if ($m.Success -and $m.Value -match "^$Rx$") { $m.Value } }
    return (@($ids) -join ' ')
}
$clear = (@('Back') * 12) -join ','

Write-Host ''
Write-Host '  LazySpec: item ids' -ForegroundColor Cyan
Write-Host ''
try {
    $f = Invoke-Keys "t,text:OSN-T-0,snap,$clear,text:osn-t-04,snap,$clear,text:OSN-T,snap"
    Check ((Get-Ids $f[0]) -eq 'OSN-T-01 OSN-T-04 OSN-T-09 OSN-T-040 OSN-T-041' -and $f[0] -match '5 found') 'OSN-T-0: its tasks, in id order' $f[0]
    Check ($f[0] -match 'OSN-T-01 1\.1 Dodati klase' -and $f[0] -notmatch 'OSN-T-01 1\.1 OSN-T-01') 'the id a label of its own, not twice' $f[0]
    Check ((Get-Ids $f[1]) -eq 'OSN-T-04 OSN-T-040 OSN-T-041') 'osn-t-04: the exact id first, then 040, 041' $f[1]
    Check ((Get-Ids $f[2]) -eq 'OSN-T-01 OSN-T-04 OSN-T-09 OSN-T-040 OSN-T-041 OSN-T-73 OSN-T-74') 'OSN-T: every OSN task' $f[2]

    $f = Invoke-Keys "t,text:OSN-R,snap,$clear,text:osn-s-07,snap,$clear,text:OSN-Q,snap,$clear,text:OSN-D,snap"
    Check ((Get-Ids $f[0]) -eq 'OSN-R-01 OSN-R-03') 'requirements by id (Zahtjev: too)' $f[0]
    Check ((Get-Ids $f[1]) -eq 'OSN-S-07' -and $f[1] -match 'OSN-S-07 Plaćeno karticom') 'a scenario under Scenarij:' $f[1]
    Check ((Get-Ids $f[2]) -eq 'OSN-Q-02' -and $f[2] -match 'Open ques') 'an open question' $f[2]
    Check ((Get-Ids $f[3]) -eq 'OSN-D-04' -and $f[3] -match 'Design' -and $f[3] -notmatch 'not a decision') 'a decision; a list line without an id is none' $f[3]

    $f = Invoke-Keys "t,text:osn,snap,$clear,text:zaj,snap"
    $o = Get-Ids $f[0]
    Check ($o.StartsWith('OSN-D-04 OSN-Q-02 OSN-R-01 OSN-R-03 OSN-S-01 OSN-S-07 OSN-T-01') -and $f[0] -match 'Osnova') 'osn: every OSN item by id, then text (Osnova)' $f[0]
    Check ((Get-Ids $f[1]) -eq 'ZAJ-T-01 ZAJ-T-02' -and $f[1] -match 'Project tasks') 'project-tasks.md: its tasks, as Project tasks' $f[1]

    $f = Invoke-Keys "t,text:OSN-T-11,snap,$clear,text:osn-t-20,snap"
    Check ($f[0] -match 'OSN-T-11 - split into OSN-T-73, OSN-T-74' -and (Get-Ids $f[0] 'OSN-T-7\d') -eq 'OSN-T-73 OSN-T-74' -and $f[0] -match '3 found') 'a retired id: split into, then its successors' $f[0]
    Check ($f[1] -match 'OSN-T-20 - removed' -and $f[1] -match '1 found') 'a removed id: just that' $f[1]

    $f = Invoke-Keys "t,text:1.8,snap,$clear,text:plain task,Tab,snap"
    Check ($f[0] -match '1 found' -and $f[0] -match '1\.8 Plain task without an id') 'no id: a task number as before' $f[0]
    Check ($f[1] -match '1 found' -and $f[1] -match '1\.8 Plain task') 'no id: words as before' $f[1]

    $f = Invoke-Keys "t,text:OSN-T-04,Enter,snap,Esc,$clear,text:OSN-S-07,Enter,snap"
    Check ($f[0] -match '^snap read' -and $f[0] -match '1\.2 OSN-T-04 Online plaćanje') 'Read: the task with its id' $f[0]
    Check ($f[1] -match '^snap read' -and $f[1] -match 'OSN-S-07 Plaćeno karticom') 'Read: the scenario with its id' $f[1]
}
finally {
    if (Test-Path -LiteralPath $frames) { Remove-Item -LiteralPath $frames -Force }
}
Write-TestSummary
if ($script:failed) { exit 1 }

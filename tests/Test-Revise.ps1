#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-Revise.ps1                                     |
#  |   Revise (find, mark, remove/change/redo), out of date (y), undo (u)     |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests revising the documents from the find screen, the out-of-date check with the agent, and undo, on a copy
    of the demo project (examples\acme-portal) in %TEMP%, a git repository of its own. The agent is a stand-in
    (LAZYSPEC_AGENT): Claude Code is never run. Needs git and the OpenSpec CLI (the validation after a removal).

.DESCRIPTION
    1. Remove a task (find, Right, x): out of tasks.md, then validated.
    2. Remove a scenario of a delta spec: its requirement changed, so the tasks are out of date; asked once
       whether to watch for it (remembered: lazyspec: syncCheck: on).
    3. y: update with the agent, the prompt saved (lazyspec: agent: prompt remembered, the requirement before and
       now in it); y again: run it (the stand-in agent gets the prompt).
    4. Remove a requirement of a main spec: a new change with REMOVED Requirements, valid.
    5. g marks a task's group; Enter: what to do with them; change with a note: the prompt.
    7. Read: a task picked, edited in the window (Ctrl+S), ticked (Space), deleted (Del).
    8. A main spec's requirement edited: through a change (MODIFIED).
    6. u: the changes since the commit; a piece undone, a new file deleted; nothing of them left.

.PARAMETER Keep
    Keep the test files in %TEMP%.

.EXAMPLE
    .\tests\Test-Revise.ps1
#>
[CmdletBinding()]
param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('lazyspec-revise-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
$utf8 = New-Object Text.UTF8Encoding $false

# The screens (snap) after the keys, one list item each.
function Invoke-Keys([string]$Keys) {
    $frames = Join-Path $work 'frames.txt'
    if (Test-Path -LiteralPath $frames) { Remove-Item -LiteralPath $frames }
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $lazyspec -Root $proj -Width 120 -Height 34 -Keys $Keys -Frames $frames 2>&1 | Out-Null
    $t = ''
    if (Test-Path -LiteralPath $frames) { $t = [IO.File]::ReadAllText($frames, $utf8) }
    return @([regex]::Split($t, '(?m)^----- ') | Where-Object { $_ })
}
function Read-File([string]$Rel) { $f = Join-Path $proj $Rel; if (Test-Path -LiteralPath $f) { return [IO.File]::ReadAllText($f, $utf8) }; return '' }
# git's warnings (on stderr) aren't errors here.
function Invoke-Git([string[]]$GitArgs) { $ErrorActionPreference = 'Continue'; Push-Location $proj; try { return (& git -c core.autocrlf=false @GitArgs 2>&1 | Out-String) } finally { Pop-Location } }

Write-Host ''
Write-Host "  LazySpec: revise, out of date, undo ($work)" -ForegroundColor Cyan
Write-Host ''
try {
    $proj = Join-Path $work 'acme'
    [void](New-Item -ItemType Directory -Force -Path $proj)
    Copy-Item -Recurse -LiteralPath (Join-Path $repo 'examples\acme-portal\openspec') -Destination $proj
    [void](Invoke-Git @('init', '-q'))
    [void](Invoke-Git @('add', '-A'))
    [void](Invoke-Git @('-c', 'user.name=test', '-c', 'user.email=test@example.com', 'commit', '-qm', 'base'))
    $agent = Join-Path $work 'agent.cmd'
    [IO.File]::WriteAllText($agent, "@echo STAND-IN AGENT %*`r`n")
    $env:LAZYSPEC_AGENT = $agent
    $tasks = 'openspec\changes\01-add-user-signup\tasks.md'

    # 1. A task removed.
    $f = Invoke-Keys 't,text:1.4,Right,Del,snap,y,wait:done,snap'
    Check ($f[0] -match 'Delete the task "1\.4 Nightly') 'Del: asked first' $f[0]
    Check ((Read-File $tasks) -notmatch '1\.4 Nightly' -and (Read-File $tasks) -match '1\.3 Verification endpoint') 'a task removed from tasks.md, the others kept'
    Check ($f[1] -match '- task 1\.4' -and $f[1] -match 'Totals: 8 passed, 0 failed') 'then validated' $f[1]

    # 2. A scenario of a delta spec removed: the tasks out of date; asked once, remembered.
    $f = Invoke-Keys 't,text:link expired,Right,Del,y,wait:done,Esc,Esc,snap,y,Tab,snap'
    Check ((Read-File 'openspec\changes\01-add-user-signup\specs\user-accounts\spec.md') -notmatch 'Link expired') 'a scenario removed from its delta spec'
    Check ($f[0] -match 'Out of date: documents of 01-add-user-signup older than their specs\. Watch for this in this project\?') 'out of date: asked once whether to watch for it' $f[0]
    Check ((Read-File 'openspec\config.yaml') -match '(?m)^  syncCheck: on$') 'the answer remembered (lazyspec: syncCheck: on)'
    Check ($f[1] -match 'OUT OF DATE' -and $f[1] -match '! Tasks is older than' -and $f[1] -match '~ specs/user-accounts/spec\.md . E-mail verification' -and $f[1] -match '! 5/7') 'the change: ! in the plan, what changed in its details' $f[1]

    # 3. y: the agent - the prompt saved, then run.
    $f = Invoke-Keys 'Tab,y,snap,u,snap,s,snap'
    Check ($f[0] -match 'Update them \(the agent\)' -and $f[0] -match 'Mark them as in sync') 'y: update or mark as in sync' $f[0]
    Check ($f[2] -match 'Prompt saved: \.lazyspec/prompts/\d{8}-\d{6}-sync-01-add-user-signup\.md - give it to the agent: claude') 'the prompt saved, the command for the agent' $f[2]
    $prompt = @(Get-ChildItem -LiteralPath (Join-Path $proj '.lazyspec\prompts') -Filter '*sync*' | Select-Object -First 1)
    $pt = ''
    if ($prompt.Count) { $pt = [IO.File]::ReadAllText($prompt[0].FullName, $utf8) }
    Check ($pt -match 'requirement "E-mail verification" changed' -and $pt -match '(?s)Before:.*Link expired.*Now:' -and $pt -match 'openspec validate 01-add-user-signup') 'the prompt: what changed, before and now'
    Check ((Read-File 'openspec\config.yaml') -match '(?m)^  agent: prompt$') 'the choice remembered (lazyspec: agent: prompt)'
    $f = Invoke-Keys 'Tab,y,u,snap,r,wait:done,snap'
    Check ($f[0] -match 'Save the prompt for later') 'asked again, the remembered one first' $f[0]
    Check ($f[1] -match 'STAND-IN AGENT -p "Read the file \.lazyspec/prompts/' -and $f[1] -match 'acceptEdits') 'run: the agent gets the prompt' $f[1]
    $f = Invoke-Keys 'Tab,y,m,snap'
    Check ($f[0] -match 'marked as in sync' -and $f[0] -notmatch 'OUT OF DATE') 'mark as in sync: no longer out of date' $f[0]

    # 4. A requirement of a main spec: a new change with REMOVED Requirements.
    $f = Invoke-Keys 't,text:password reset,Right,Del,snap,y,wait:done,snap'
    Check ($f[0] -match 'in the main specs: through a new change') 'a main spec: through a new change (said first)' $f[0]
    $rc = @(Get-ChildItem -LiteralPath (Join-Path $proj 'openspec\changes') -Directory -Filter 'remove-from-specs-*')
    $delta = ''
    if ($rc.Count) { $delta = [IO.File]::ReadAllText((Join-Path $rc[0].FullName 'specs\user-accounts\spec.md'), $utf8) }
    Check ($delta -match '## REMOVED Requirements' -and $delta -match '### Requirement: Password reset' -and (Read-File 'openspec\specs\user-accounts\spec.md') -match 'Password reset') 'the change: REMOVED, the main spec untouched' $delta
    Check ($f[1] -match 'remove-from-specs-' -and $f[1] -match 'Totals: 9 passed, 0 failed') 'the new change valid' $f[1]

    # 5. g: a task's group; c with a note.
    $f = Invoke-Keys 't,text:front end,Tab,Right,g,snap,Enter,snap,c,text:Use the design system,Enter,s,snap'
    Check (([regex]::Matches($f[0], [string][char]0x2022)).Count -eq 2) 'g: the task''s whole group marked' $f[0]
    Check ($f[1] -match '2 marked:\s+Delete them\s+Change them') 'Enter with marks: what to do with them' $f[1]
    $cp = @(Get-ChildItem -LiteralPath (Join-Path $proj '.lazyspec\prompts') -Filter '*-change.md' | Select-Object -First 1)
    $ct = ''
    if ($cp.Count) { $ct = [IO.File]::ReadAllText($cp[0].FullName, $utf8) }
    Check ($ct -match '> Use the design system' -and $ct -match '2\.1 Sign-up page' -and $ct -match '2\.2 "Check your e-mail"' -and $ct -match 'tasks\.md \(line \d+\)') 'c: the prompt with the note and each item'

    # 7. Read: a task picked (Up, Down), edited in the window (Ctrl+S), ticked (Space), deleted (Del).
    $f = Invoke-Keys 'Tab,Enter,Right,Right,Right,Down,Down,snap,Enter,snap,End,text: (also the API),CtrlS,snap,Down,Space,Down,Del,y,snap'
    Check ($f[0] -match ([string][char]0x25B8 + ' ' + [string][char]0x2713 + ' 1\.3 Verification endpoint') -and $f[0] -match 'Enter edit it') 'Read: Down picks the next task, marked' $f[0]
    Check ($f[1] -match '^snap edit' -and $f[1] -match '1 - \[x\] 1\.3 Verification endpoint' -and $f[1] -match 'Ctrl\+S save') 'Enter: the task alone in the editor' $f[1]
    $t = Read-File $tasks
    Check ($f[2] -match 'Saved\. u: undo' -and $t -match '- \[x\] 1\.3 Verification endpoint \(also the API\)') 'Ctrl+S: the line saved in tasks.md' $t
    Check ($t -match '- \[ \] 2\.1 Sign-up page') 'Space: the next task (done) unticked' $t
    Check ($t -notmatch '2\.2 ' -and $t -match '3\.1 ') 'Del: the picked task deleted' $t

    # 8. A main spec's requirement edited (the last result: the specs come after the changes): through a change
    #    (MODIFIED), the spec itself untouched.
    $f = Invoke-Keys 't,text:password reset,Tab,Tab,Tab,End,Enter,Enter,Down,End,text: Within an hour.,CtrlS,snap,c,snap'
    Check ($f[0] -match 'A main spec:\s+Through a change \(MODIFIED\)') 'a main spec: asked how' $f[0]
    $mc = @(Get-ChildItem -LiteralPath (Join-Path $proj 'openspec\changes') -Directory -Filter 'modify-specs-*')
    $mt = ''
    if ($mc.Count) { $mt = [IO.File]::ReadAllText((Join-Path $mc[0].FullName 'specs\user-accounts\spec.md'), $utf8) }
    Check ($mt -match '## MODIFIED Requirements' -and $mt -match 'e-mail address\. Within an hour\.' -and $mt -match 'Scenario: Reset link' -and (Read-File 'openspec\specs\user-accounts\spec.md') -notmatch 'Within an hour') 'through a change: the whole requirement as edited, the spec untouched' $mt

    # 6. u: undo a piece, delete the new files (an export, in openspec/exports, isn't one of them).
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $lazyspec -Root $proj -Export Html -Item 01-add-user-signup -KeepDiagrams 2>&1 | Out-Null
    Check (@(Get-ChildItem -LiteralPath (Join-Path $proj 'openspec\exports') -Filter '*.html' -ErrorAction SilentlyContinue).Count -eq 1) 'an export: in openspec/exports by default'
    $f = Invoke-Keys 'u,snap'
    Check ($f[0] -notmatch 'exports') 'undo: not the exports' $f[0]
    Check ($f[0] -match 'undo' -and $f[0] -match 'tasks\.md  changed' -and $f[0] -match '-\d+\s+\+\d+' -and $f[0] -match 'remove-from-specs-.+  new') 'u: the changes since the commit, piece by piece' $f[0]
    # Each piece and each new file, undone (Enter, y) until none is left.
    $f = Invoke-Keys ('u' + (',Enter,y' * 30) + ',snap')
    $left = Invoke-Git @('status', '--porcelain', '--untracked-files=all', '--', 'openspec', ':(exclude)openspec/exports')
    Check ((Read-File $tasks) -match '1\.4 Nightly' -and (Read-File $tasks) -notmatch 'also the API' -and (Read-File 'openspec\changes\01-add-user-signup\specs\user-accounts\spec.md') -match 'Link expired') 'undone: the task and the scenario back'
    Check (-not @(Get-ChildItem -LiteralPath (Join-Path $proj 'openspec\changes') -Directory -Filter 'remove-from-specs-*').Count -and -not @(Get-ChildItem -LiteralPath (Join-Path $proj 'openspec\changes') -Directory -Filter 'modify-specs-*').Count) 'undone: the new changes deleted'
    Check (-not $left.Trim()) 'nothing left to undo: as committed' $left
}
finally {
    Remove-Item Env:\LAZYSPEC_AGENT -ErrorAction SilentlyContinue
    if (-not $Keep) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-TestSummary $(if ($Keep) { $work })
exit [int]($script:failed -gt 0)

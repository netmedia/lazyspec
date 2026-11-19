#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-SyncAgent.ps1                                  |
#  |   y, update them: the agent done, the change marked as in sync           |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests marking a change as in sync after the agent brings its out-of-date documents up to date, on a copy of
    the demo project (examples\acme-portal) in %TEMP%. The agent is a stand-in (LAZYSPEC_AGENT) that does what
    agent-mode.txt says: Claude Code is never run. The OpenSpec CLI validates after a successful run.

.DESCRIPTION
    1. Background, exit code 0: validated, marked as in sync - also a document the agent left unchanged.
    2. Background, exit code 1: not marked; said so.
    3. A spec edited while the agent ran: marked against the specs it was given - out of date for that edit.
    4. Here: asked on return (yes first); Enter marks it.
    5. The prompt saved (s): not marked; when the agent (outside LazySpec) has changed one of the documents it
       names and left another as it was, offered; y marks it.

.PARAMETER Keep
    Keep the test files in %TEMP%.

.EXAMPLE
    .\tests\Test-SyncAgent.ps1
#>
[CmdletBinding()]
param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$work = Join-Path ([IO.Path]::GetTempPath()) ('lazyspec-syncagent-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
$utf8 = New-Object Text.UTF8Encoding $false

function Invoke-Keys([string]$Keys) {
    $frames = Join-Path $work 'frames.txt'
    if (Test-Path -LiteralPath $frames) { Remove-Item -LiteralPath $frames }
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $lazyspec -Root $proj -Width 130 -Height 44 -Keys $Keys -Frames $frames 2>&1 | Out-Null
    $t = ''
    if (Test-Path -LiteralPath $frames) { $t = [IO.File]::ReadAllText($frames, $utf8) }
    return , @([regex]::Split($t, '(?m)^----- ') | Where-Object { $_ -and $_ -notmatch '^end ' })
}
function Add-Text([string]$Rel, [string]$Text) { $f = Join-Path $proj $Rel; [IO.File]::WriteAllText($f, [IO.File]::ReadAllText($f, $utf8).TrimEnd() + "`n`n$Text`n", $utf8) }
function Read-File([string]$Rel) { $f = Join-Path $proj $Rel; if (Test-Path -LiteralPath $f) { return [IO.File]::ReadAllText($f, $utf8) }; return '' }
function Set-AgentMode([string]$Mode) { [IO.File]::WriteAllText((Join-Path $work 'agent-mode.txt'), $Mode) }
function Get-SyncFiles { return @(Get-ChildItem -LiteralPath (Join-Path $proj '.lazyspec\prompts') -Filter '*.sync.json' -ErrorAction SilentlyContinue) }

$ch = 'openspec\changes\01-add-user-signup'
$req = { param($n) "### Requirement: $n`nThe system SHALL keep the $($n.ToLower()) of an account.`n`n#### Scenario: $n set`n- **WHEN** the customer sets it`n- **THEN** it is kept" }

Write-Host ''
Write-Host "  LazySpec: the agent's sync marked as in sync ($work)" -ForegroundColor Cyan
Write-Host ''
try {
    $proj = Join-Path $work 'acme'
    [void](New-Item -ItemType Directory -Force -Path $proj)
    Copy-Item -Recurse -LiteralPath (Join-Path $repo 'examples\acme-portal\openspec') -Destination $proj
    $cfg = Join-Path $proj 'openspec\config.yaml'
    [IO.File]::WriteAllText($cfg, ([IO.File]::ReadAllText($cfg, $utf8) -replace '(?m)^lazyspec:\r?\n', "lazyspec:`n  syncCheck: on`n"), $utf8)
    # The stand-in agent: agent-mode.txt says what it does - ok (design.md updated, exit 0), fail (exit 1),
    # spec (design.md and tasks.md updated, and a requirement added to a delta spec meanwhile, exit 0).
    $fake = Join-Path $work 'fake-agent.ps1'
    [IO.File]::WriteAllText($fake, @"
`$mode = ([IO.File]::ReadAllText('$(Join-Path $work 'agent-mode.txt')')).Trim()
`$c = Join-Path (Get-Location) '$ch'
Write-Host "STAND-IN AGENT (`$mode)"
function Add([string]`$f, [string]`$t) { [IO.File]::AppendAllText((Join-Path `$c `$f), "``n`$t``n") }
if (`$mode -eq 'fail') { exit 1 }
Add 'design.md' 'Updated by the stand-in agent.'
if (`$mode -eq 'spec') {
    Add 'tasks.md' '- [ ] 3.3 Updated by the stand-in agent'
    Add 'specs\user-accounts\spec.md' "### Requirement: Avatar``nThe system SHALL keep the avatar of an account.``n``n#### Scenario: Avatar set``n- **WHEN** the customer sets it``n- **THEN** it is kept"
}
exit 0
"@, $utf8)
    $agent = Join-Path $work 'agent.cmd'
    [IO.File]::WriteAllText($agent, "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"$fake`" %*`r`nexit /b %ERRORLEVEL%`r`n")
    $env:LAZYSPEC_AGENT = $agent
    [void](Invoke-Keys 'snap')

    # 1. The proposal changed: the design and the delta specs out of date. In the background, exit code 0: the
    # design updated, the specs left as they are - validated, then all of it marked as in sync.
    Add-Text "$ch\proposal.md" 'A late note in the proposal.'
    $f = Invoke-Keys 'Tab,snap'
    Check ($f[0] -match '! Design is older than' -and $f[0] -match '! Specs is older than') 'the proposal changed: the design and the specs out of date' $f[0]
    Set-AgentMode 'ok'
    $f = Invoke-Keys 'Tab,y,u,b,wait:done,snap,Enter,snap'
    Check ($f[0] -match 'STAND-IN AGENT \(ok\)' -and $f[0] -match 'openspec validate 01-add-user-signup --strict --no-interactive' -and $f[0] -match '01-add-user-signup: updated by the agent, marked as in sync') 'background, exit code 0: validated, marked as in sync' $f[0]
    Check ((Read-File "$ch\design.md") -match 'Updated by the stand-in agent') 'the agent updated the design'
    Check ($f[1] -notmatch 'OUT OF DATE' -and $f[1] -notmatch '! \d+/\d+') 'in sync - the specs, which the agent left unchanged, too' $f[1]
    Check ((Get-SyncFiles).Count -eq 0) 'the prompt''s snapshot used up'

    # 2. Exit code 1: not marked.
    Add-Text "$ch\proposal.md" 'Another note in the proposal.'
    Set-AgentMode 'fail'
    $f = Invoke-Keys 'Tab,y,u,b,wait:done,snap,Enter,snap'
    Check ($f[0] -match '01-add-user-signup: not marked as in sync - the agent ended with exit code 1') 'background, exit code 1: not marked, said so' $f[0]
    Check ($f[1] -match 'OUT OF DATE' -and $f[1] -match '! Design is older than') 'still out of date' $f[1]
    [void](Invoke-Keys 'Tab,y,m')
    Get-SyncFiles | Remove-Item

    # 3. A requirement added to a delta spec: the tasks out of date. The agent updates them, and meanwhile
    # another requirement is added: marked against what it was given - out of date for the later one only.
    Add-Text "$ch\specs\user-accounts\spec.md" (& $req 'Nickname')
    Set-AgentMode 'spec'
    $f = Invoke-Keys 'Tab,y,u,b,wait:done,snap,Enter,snap'
    Check ($f[0] -match '01-add-user-signup: updated by the agent, marked as in sync') 'background, exit code 0: validated, marked' $f[0]
    Check ($f[1] -match 'OUT OF DATE' -and $f[1] -match '! Tasks is older than' -and $f[1] -match '\+ specs/user-accounts/spec\.md . Avatar' -and $f[1] -notmatch 'Nickname') 'a spec edited during the run: still out of date, for that edit only' $f[1]
    [void](Invoke-Keys 'Tab,y,m')

    # 4. Here: Claude Code in the terminal; back: asked, yes first.
    Add-Text "$ch\proposal.md" 'A third note in the proposal.'
    Set-AgentMode 'ok'
    $f = Invoke-Keys 'Tab,y,u,h,snap,Enter,snap'
    Check ($f[0] -match '01-add-user-signup: mark as in sync\?\s+Yes\s+No') 'here: asked on return' $f[0]
    Check ($f[1] -match '01-add-user-signup: updated by the agent, marked as in sync' -and $f[1] -notmatch 'OUT OF DATE') 'Enter (yes): marked as in sync' $f[1]

    # 5. The prompt saved: nothing marked. Given to the agent outside LazySpec, which updates the design and
    # rightly leaves the specs as they are: the specs still out of date - offered, y marks it.
    Add-Text "$ch\proposal.md" 'A fourth note in the proposal.'
    $f = Invoke-Keys 'Tab,y,u,s,snap'
    Check ((Get-SyncFiles).Count -eq 1 -and $f[0] -match 'OUT OF DATE') 'saved: the snapshot next to the prompt, nothing marked' $f[0]
    $f = Invoke-Keys 'Tab,snap'
    Check ($f[0] -notmatch 'changed since the saved sync prompt') 'nothing done yet: not offered' $f[0]
    Add-Text "$ch\design.md" 'Updated outside LazySpec.'
    $f = Invoke-Keys 'snap,y,snap,Tab,snap'
    Check ($f[0] -match '01-add-user-signup: its documents changed since the saved sync prompt\. Mark them as in sync\?' -and $f[0] -match '01 Add user sign-up\s+! \d+/\d+') 'the design updated, the specs left (still out of date): offered' $f[0]
    Check ($f[1] -match 'marked as in sync \(against the saved prompt''s specs\)') 'y: marked as in sync' $f[1]
    Check ($f[2] -notmatch 'OUT OF DATE' -and $f[2] -notmatch '! \d+/\d+') 'no longer out of date' $f[2]
    Check ((Get-SyncFiles).Count -eq 0) 'the snapshot used up'
}
finally {
    Remove-Item Env:\LAZYSPEC_AGENT -ErrorAction SilentlyContinue
    if ($Keep) { Write-Host "  kept: $work" } else { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-TestSummary
exit [int]($script:failed -gt 0)

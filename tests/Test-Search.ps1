#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-Search.ps1                                     |
#  |   t on Home: find a task, a requirement, a scenario                      |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests the find screen (t on Home) on the demo project (examples\acme-portal), with test keys: nothing is
    written into the project.

.DESCRIPTION
    1. t: the find screen, with what to type.
    2. A task number (1.3): that task in every change; a change and a number (01 1.3): that change's.
    3. Enter: Read on the tasks tab, the task marked; Esc: back to the results.
    4. Words: tasks, requirements and scenarios that contain them all; Tab: only requirements, only open tasks.
    5. A requirement of a delta spec and of a spec: Read at it, marked.
    6. Archived changes only with h, as on Home; Esc: back to Home.
    7. From any screen: t (Read, changes as one), Ctrl+F (help); Esc comes back there; not while asked.

.EXAMPLE
    .\tests\Test-Search.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$demo = Join-Path $repo 'examples\acme-portal'
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')
$frames = Join-Path ([IO.Path]::GetTempPath()) ('lazyspec-search-' + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')

# The screens (snap) after the keys, as text.
function Invoke-Keys([string]$Keys) {
    if (Test-Path -LiteralPath $frames) { Remove-Item -LiteralPath $frames }
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $lazyspec -Root $demo -Width 110 -Height 30 -Keys $Keys -Frames $frames 2>&1 | Out-Null
    $t = ''
    if (Test-Path -LiteralPath $frames) { $t = [IO.File]::ReadAllText($frames, (New-Object Text.UTF8Encoding $false)) }
    # One snapshot a list item.
    return @([regex]::Split($t, '(?m)^----- ') | Where-Object { $_ })
}
$ok = [string][char]0x2713; $ring = [string][char]0x25CB; $dia = [string][char]0x25C6; $tri = [string][char]0x25B8

Write-Host ''
Write-Host '  LazySpec: find (t)' -ForegroundColor Cyan
Write-Host ''
try {
    $f = Invoke-Keys 't,snap,text:1.3,snap,Enter,snap,Esc,snap,Back,Back,Back,text:01 1.3,snap,Esc,snap'
    Check ($f[0] -match '^snap search' -and $f[0] -match 'Type a task number') 't: the find screen, what to type' $f[0]
    Check ($f[1] -match '2 found' -and $f[1] -match "$ok 01 Add user sign-up\s+1\.3 Verification endpoint" -and $f[1] -match "$ok 03 Add order history\s+1\.3 Empty state") 'a task number: that task in every change' $f[1]
    Check ($f[2] -match '^snap read' -and $f[2] -match 'tasks\.md' -and $f[2] -match "\$tri $ok 1\.3 Verification endpoint") 'Enter: Read on the tasks tab, the task marked' $f[2]
    Check ($f[3] -match '^snap search' -and $f[3] -match 'find 1\.3') 'Esc in Read: back to the results'
    Check ($f[4] -match '1 found' -and $f[4] -match '01 Add user sign-up\s+1\.3 Verification endpoint') 'a change and a number (01 1.3): that change''s task' $f[4]
    Check ($f[5] -match '^snap home') 'Esc: back to Home'

    $f = Invoke-Keys 't,text:verif,snap,Tab,Tab,Tab,snap,Down,Enter,snap'
    Check ($f[0] -match '9 found' -and $f[0] -match "$ok 01 Add user sign-up\s+1\.2 Verification token" -and $f[0] -match "$dia 01 Add user sign-up" -and $f[0] -match "$tri 01 Add user sign-up .*Link expired") 'words: tasks, requirements and scenarios' $f[0]
    Check ($f[1] -match '2 found' -and $f[1] -match 'kind: requirements' -and $f[1] -notmatch "$ok ") 'Tab: requirements only' $f[1]
    Check ($f[2] -match '^snap read' -and $f[2] -match "\$tri $dia E-mail verification") 'a delta spec''s requirement: Read at it, marked' $f[2]

    $f = Invoke-Keys 't,text:password reset,snap,Enter,snap'
    Check ($f[0] -match "$dia User accounts\s+Password reset") 'a spec''s requirement' $f[0]
    Check ($f[1] -match '^snap read' -and $f[1] -match 'specs/user-accounts/spec\.md' -and $f[1] -match "\$tri $dia Password reset") 'a spec''s requirement: Read at it, marked' $f[1]

    $f = Invoke-Keys 't,text:01,Tab,Tab,snap'
    Check ($f[0] -match 'kind: open tasks' -and $f[0] -match '3 found' -and $f[0] -match "$ring 01 Add user sign-up\s+1\.4" -and $f[0] -notmatch "$ok ") 'Tab: open tasks only' $f[0]

    # From any screen: t (Read, changes as one), Ctrl+F (help); Esc comes back there; not while asked.
    $f = Invoke-Keys 'Tab,Enter,t,snap,Esc,snap,?,CtrlF,snap,Esc,snap'
    Check ($f[0] -match '^snap search' -and $f[1] -match '^snap read') 't in Read: find, Esc back to Read' (($f | ForEach-Object { $_.Split("`n")[0] }) -join ' / ')
    Check ($f[2] -match '^snap search' -and $f[3] -match '^snap help') 'Ctrl+F in help: find, Esc back to help'
    $f = Invoke-Keys 'Tab,m,t,snap,Esc,snap,Esc,x,snap'
    Check ($f[0] -match '^snap search' -and $f[1] -match '^snap pick') 't in changes as one: find, Esc back there'
    Check ($f[2] -match '^snap home' -and $f[2] -notmatch 'find') 'a question open (x: the format): t isn''t find' $f[2]

    $f = Invoke-Keys 't,text:sign-in endpoint,snap,Esc,h,t,snap'
    Check ($f[0] -match 'nothing found') 'archived changes hidden, as on Home' $f[0]
    Check ($f[1] -match '1 found' -and $f[1] -match 'add-email-login|Add e-mail login') 'h on Home: archived changes found too' $f[1]
}
finally {
    Remove-Item -LiteralPath $frames -Force -ErrorAction SilentlyContinue
}
Write-TestSummary
exit [int]($script:failed -gt 0)

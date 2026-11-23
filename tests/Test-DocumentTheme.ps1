#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-DocumentTheme.ps1                              |
#  |   The export with a document theme (documentTheme): PDF, Word, HTML      |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests the export with a document theme (lazyspec: documentTheme: in openspec/config.yaml, or -Theme):
    the look of HTML, its fonts from fonts\ next to it. Word and PDF are Netmedia documents (netmedia-document,
    on the Netmedia template or the project's copy of it): the theme doesn't change them. No modules: it builds
    its own project and theme in %TEMP% (the fonts: copies of the system's Georgia, Windows or macOS).

.DESCRIPTION
    1. Without a theme: the HTML is the same as before themes (-Baseline: that lazyspec.ps1; default: git
       HEAD's when it has no themes yet; else skipped).
    2. HTML: the theme's fonts inside (@font-face from fonts\), its styles, the cover's logo.
    3. PDF (Word exports it; skipped without Word): a Netmedia document, the theme not in it (A4, no Georgia).
    4. Word: a Netmedia document (the Netmedia cover with the title, the contents, the template's header logo
       and Montserrat), the theme not in it.
    5. A theme path with spaces, relative to the project's root (lazyspec started in a subfolder).
    6. Missing theme, broken YAML, missing logo: a clear error, exit code 1, no document.
    7. -Theme wins over the config's documentTheme.
    8. A template and a theme in the config: Word on the template; -Theme on the command line doesn't change
       Word (still the template).

.PARAMETER Baseline
    A lazyspec.ps1 from before document themes, for test 1.

.PARAMETER Keep
    Keep the test project in %TEMP% (to look at the documents).

.EXAMPLE
    .\tests\Test-DocumentTheme.ps1
#>
[CmdletBinding()]
param(
    [string]$Baseline,
    [switch]$Keep
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$work = Join-Path ([IO.Path]::GetTempPath() -replace '^/var/', '/private/var/') ('lazyspec-theme-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

# A theme in a folder with a space: fonts\ (Georgia's four files), images\ (the logos), the YAML.
function New-FixtureTheme([string]$Dir, [string]$Yaml) {
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $Dir 'fonts'), (Join-Path $Dir 'images'))
    foreach ($f in (Get-GeorgiaFiles)) { Copy-Item -LiteralPath $f -Destination (Join-Path $Dir 'fonts') }
    [IO.File]::WriteAllBytes((Join-Path $Dir 'images\logo.png'), (Get-Png 120 40 'Red'))
    [IO.File]::WriteAllBytes((Join-Path $Dir 'images\cover.png'), (Get-Png 300 100 'Blue'))
    [IO.File]::WriteAllText((Join-Path $Dir 'document-theme.yaml'), $Yaml)
}
$themeYaml = @'
# Acme: the look of client documents
page:
  size: Letter
  margins: { top: 38mm, right: 22mm, bottom: 24mm, left: 24mm }
colors:
  text: "#222222"
  accent: "#C2185B"
styles:
  body:     { font: Georgia, size: 10pt, color: text }
  title:    { size: 30pt, bold: true, color: accent }
  subtitle: { size: 18pt, italic: true }
  heading1: { size: 20pt, color: accent }
  heading2: { size: 14pt, underline: true }
  table:    { borderColor: "#999999", headerBackground: "#EEEEEE" }
  code:     { font: Consolas, size: 8pt }
header: { left: logo, logo: images/logo.png, logoHeight: 8mm, right: "{title}" }
footer: { left: "{title} - {subtitle}", right: "{page} / {pages}" }
cover:  { logo: images/cover.png, logoHeight: 20mm }
'@

Write-Host ''
Write-Host "  LazySpec: the export with a document theme ($work)" -ForegroundColor Cyan
Write-Host ''
$hasWord = Test-WordInstalled
try {
    $proj = Join-Path $work 'acme'
    $themeDir = Join-Path $proj 'design\company theme'
    New-FixtureTheme $themeDir $themeYaml
    $themeSetting = 'documentTheme: design/company theme/document-theme.yaml'
    New-FixtureProject $proj @('# documentTheme: the look of every generated document', $themeSetting)
    $sub = Join-Path $proj 'src\deep'

    # 1. Without a theme: the HTML as before.
    $plain = Join-Path $work 'plain'
    New-FixtureProject $plain @()
    if (-not $Baseline) { $Baseline = Get-Baseline $repo $work 'Get-DocumentTheme' }
    if (-not $Baseline -or -not (Test-Path -LiteralPath $Baseline)) { Skip 'without a theme: as before' 'no lazyspec.ps1 from before themes (-Baseline)' }
    else {
        Copy-KitFiles $lazyspec $Baseline
        $a = Invoke-LazySpec $Baseline $plain 'Html' @('-Out', (Join-Path $work 'before.html'))
        $b = Invoke-LazySpec $lazyspec $plain 'Html' @('-Out', (Join-Path $work 'now.html'))
        # The document as before (LazySpec's own stylesheet may have grown since: it isn't compared), and no theme in the styles.
        # The cover's counts aren't compared either: their words now have singular forms ("1 chapter"); nor the
        # tables' column widths (<colgroup>, class "sized"), new since; nor the line ends (a .ps1 checked out with
        # CRLF writes its here-strings with CRLF).
        $noStyle = { param([string]$P) $t = [regex]::Replace([regex]::Replace([IO.File]::ReadAllText($P).Replace("`r`n", "`n"), '(?s)<style>.*?</style>', ''), 'Scope: [^<]*', 'Scope:'); [regex]::Replace($t.Replace('<table class="sized">', '<table>'), '<colgroup>.*?</colgroup>\r?\n', '') }
        $same = $a.Code -eq 0 -and $b.Code -eq 0 -and ((& $noStyle (Join-Path $work 'before.html')) -eq (& $noStyle (Join-Path $work 'now.html')))
        Check $same 'without a theme: the same document as before' "$($a.Out) $($b.Out)"
        $now = [IO.File]::ReadAllText((Join-Path $work 'now.html'))
        Check ($b.Code -eq 0 -and $now -notmatch '@font-face' -and $now -notmatch '@page \{ size: \d') 'without a theme: no theme in the styles'
    }

    # 2. HTML (the theme from the config: a path with spaces, relative to the root; started in a subfolder).
    $html = Join-Path $work 'themed.html'
    $r = Invoke-LazySpec $lazyspec $sub 'Html' @('-Out', $html)
    Check ($r.Code -eq 0) 'HTML with the theme (path with spaces, relative to the project root, from a subfolder)' $r.Out
    Check ($r.Out -match [regex]::Escape("document theme: $(Join-Path $themeDir 'document-theme.yaml')")) 'the theme resolved to <root>\design\company theme\document-theme.yaml' $r.Out
    if ($r.Code -eq 0) {
        $h = [IO.File]::ReadAllText($html)
        Check (([regex]::Matches($h, "@font-face \{ font-family: 'Georgia'; src: url\(data:font/ttf;base64,")).Count -eq 4) 'HTML: the theme''s four font files inside (@font-face)'
        Check ($h -match "font-family: 'Georgia'" -and $h -match 'h1, h1\.part[^{]*\{[^}]*color: #C2185B') 'HTML: the theme''s styles'
        Check ($h -match '<div class="cover-logo"><img src="data:image/png;base64,') 'HTML: the cover''s logo inside'
        Check ($h -notmatch '@page \{ size: 215\.9mm') 'HTML: no page rules (a page, not paper)'
    }

    # 3. PDF: Word exports the Netmedia document; the theme isn't in it.
    $pdf = Join-Path $work 'themed.pdf'
    $r = Invoke-LazySpec $lazyspec $proj 'Pdf' @('-Out', $pdf)
    if (-not $hasWord) {
        Check ($r.Code -ne 0 -and $r.Out -match 'PDF needs Microsoft Word') 'PDF without Word: a clear error' $r.Out
    }
    else {
        Check ($r.Code -eq 0 -and (Test-Path -LiteralPath $pdf)) 'PDF: a Netmedia document' $r.Out
        if ($r.Code -eq 0) {
            $p = Get-PdfText $pdf
            Check ($p -match '/MediaBox\s*\[\s*0\s+0\s+595') 'PDF: the Netmedia template''s page (A4), not the theme''s Letter'
            Check ($p -notmatch '/BaseFont\s*/[A-Z]{6}\+Georgia') 'PDF: the theme''s font not in it'
        }
    }

    # 4. Word: a Netmedia document; the theme isn't in it.
    $docx = Join-Path $work 'themed.docx'
    $r = Invoke-LazySpec $lazyspec $proj 'Word' @('-Out', $docx)
    Check ($r.Code -eq 0 -and (Test-Path -LiteralPath $docx)) 'Word: a Netmedia document' $r.Out
    if ($r.Code -eq 0) {
        Check ($r.Out -match 'Netmedia document: ') 'Word: made by netmedia-document (and says which)' $r.Out
        $w = Read-Docx $docx
        $doc = $w['word/document.xml']
        $text = (-join @([regex]::Matches($doc, '<w:t(?: [^>]*)?>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }))
        Check ($text.Contains('ACME PORTAL') -and $text.Contains('Table of contents')) 'Word: the Netmedia cover (the title in capitals) and the contents'
        Check ($text.Contains('Password sign-in')) 'Word: the content is there'
        Check ($w['word/styles.xml'] -match 'Montserrat' -and ($w['word/styles.xml'] + $doc) -notmatch 'Georgia') 'Word: the Netmedia template''s font, not the theme''s'
        Check ($doc -notmatch 'C2185B') 'Word: the theme''s colour not in it'
        $hdrRels = @($w.Keys | Where-Object { $_ -match '^word/_rels/header\d*\.xml\.rels$' } | ForEach-Object { $w[$_] }) -join ''
        Check ($hdrRels -match 'Target="media/') 'Word: the template''s header with its logo'
    }

    # 5. (2.: the theme's path with spaces, relative to the root, from a subfolder.)

    # 6. Errors: a missing theme, broken YAML, a missing logo.
    $missing = Join-Path $work 'missing'
    New-FixtureProject $missing @('documentTheme: design/no such theme.yaml')
    $r = Invoke-LazySpec $lazyspec $missing 'Pdf' @('-Out', (Join-Path $work 'missing.pdf'))
    Check ($r.Code -ne 0 -and $r.Out -match [regex]::Escape((Join-Path $missing 'design\no such theme.yaml'))) 'missing theme: an error naming the resolved path, non-zero exit code' $r.Out
    Check (-not (Test-Path -LiteralPath (Join-Path $work 'missing.pdf'))) 'missing theme: no document in the default look'
    $bad = Join-Path $work 'bad'
    New-FixtureTheme (Join-Path $bad 'theme') "page:`n  size: A4`nstyles:`n  body: { font: Georgia, size: 10pt`n"
    New-FixtureProject $bad @('documentTheme: theme/document-theme.yaml')
    $r = Invoke-LazySpec $lazyspec $bad 'Word' @('-Out', (Join-Path $work 'bad.docx'))
    Check ($r.Code -ne 0 -and $r.Out -match 'line \d+' -and $r.Out -match 'document-theme\.yaml') 'broken YAML: an error naming the file and the line' $r.Out
    $nologo = Join-Path $work 'nologo'
    New-FixtureTheme (Join-Path $nologo 'theme') ($themeYaml.Replace('images/logo.png', 'images/missing-logo.png'))
    New-FixtureProject $nologo @('documentTheme: theme/document-theme.yaml')
    $r = Invoke-LazySpec $lazyspec $nologo 'Html' @('-Out', (Join-Path $work 'nologo.html'))
    Check ($r.Code -ne 0 -and $r.Out -match [regex]::Escape((Join-Path $nologo 'theme\images\missing-logo.png'))) 'missing logo: an error naming it, non-zero exit code' $r.Out

    # 7. -Theme wins over the config's (missing) documentTheme; relative to the current folder.
    $r = Invoke-LazySpec $lazyspec $themeDir 'Html' @('-Root', $missing, '-Out', (Join-Path $work 'override.html'), '-Theme', 'document-theme.yaml')
    Check ($r.Code -eq 0 -and ([IO.File]::ReadAllText((Join-Path $work 'override.html')) -match '#C2185B')) '-Theme overrides the config''s documentTheme (relative to the current folder)' $r.Out

    # Not set: the conventions' place, openspec/artifacts/document-theme.yaml; a Word template next to it unused.
    $conv = Join-Path $work 'conventions'
    New-FixtureProject $conv @()
    New-FixtureTheme (Join-Path $conv 'openspec\artifacts') $themeYaml
    [IO.File]::WriteAllBytes((Join-Path $conv 'openspec\artifacts\Document template.docx'), [byte[]](1, 2, 3))
    $r = Invoke-LazySpec $lazyspec $conv 'Html' @('-Out', (Join-Path $work 'conventions.html'))
    Check ($r.Code -eq 0 -and $r.Out -match 'document theme: .+openspec.artifacts.document-theme\.yaml' -and ([IO.File]::ReadAllText((Join-Path $work 'conventions.html')) -match '#C2185B')) 'not set: openspec/artifacts/document-theme.yaml (the conventions)' $r.Out
    $r = Invoke-LazySpec $lazyspec $conv 'Word' @('-Out', (Join-Path $work 'conventions.docx'))
    Check ($r.Code -eq 0 -and $r.Out -notmatch 'Word template') 'not set: a Word template next to it isn''t taken' $r.Out

    # 8. A template and a theme: Word on the template; -Theme doesn't change Word.
    $both = Join-Path $work 'both'
    New-FixtureTemplate (Join-Path $both 'template.docx') 'TEMPLATE-HEADER-MARK'
    New-FixtureTheme (Join-Path $both 'theme') $themeYaml
    New-FixtureProject $both @('documentTemplate: template.docx', 'documentTheme: theme/document-theme.yaml')
    $r = Invoke-LazySpec $lazyspec $both 'Word' @('-Out', (Join-Path $work 'both.docx'))
    $hdr = ''
    if ($r.Code -eq 0) { $bw = Read-Docx (Join-Path $work 'both.docx'); $hdr = @($bw.Keys | Where-Object { $_ -match '^word/header\d*\.xml$' } | ForEach-Object { $bw[$_] }) -join '' }
    Check ($r.Code -eq 0 -and $hdr -match 'TEMPLATE-HEADER-MARK' -and $r.Out -match 'Word template: ') 'template and theme: Word on the template (and says so)' $r.Out
    $r = Invoke-LazySpec $lazyspec $both 'Word' @('-Out', (Join-Path $work 'both-theme.docx'), '-Theme', (Join-Path $both 'theme\document-theme.yaml'))
    $hdr = ''
    if ($r.Code -eq 0) { $bw = Read-Docx (Join-Path $work 'both-theme.docx'); $hdr = @($bw.Keys | Where-Object { $_ -match '^word/header\d*\.xml$' } | ForEach-Object { $bw[$_] }) -join '' }
    Check ($r.Code -eq 0 -and $hdr -match 'TEMPLATE-HEADER-MARK') '-Theme on the command line: Word still on the template' $r.Out
}
finally {
    if (-not $Keep) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-TestSummary $(if ($Keep) { $work })
exit [int]($script:failed -gt 0)

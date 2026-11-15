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
    the same look in PDF, Word and HTML, its fonts from fonts\ next to it (embedded in Word). No modules:
    it builds its own project and theme in %TEMP% (the fonts: copies of the system's Georgia, Windows or macOS).

.DESCRIPTION
    1. Without a theme: the HTML is the same as before themes (-Baseline: that lazyspec.ps1; default: git
       HEAD's when it has no themes yet; else skipped).
    2. HTML: the theme's fonts inside (@font-face from fonts\), its styles, the cover's logo.
    3. PDF: the theme's page size, its font, the pictures (cover and header logo).
    4. Word: the theme's styles (fonts, colours) under the built-in style IDs, its page, header (logo) and
       footer (title, PAGE / NUMPAGES), none on the cover, its fonts embedded (obfuscated, as Word does),
       its fonts as Word's theme fonts (no Aptos).
    5. A theme path with spaces, relative to the project's root (lazyspec started in a subfolder).
    6. Missing theme, broken YAML, missing logo: a clear error, exit code 1, no document.
    7. -Theme wins over the config's documentTheme.
    8. A template and a theme in the config: Word on the template, PDF on the theme; -Theme on the command
       line: Word on the theme.

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
# A font as Word embeds it, back: the first 32 bytes XORed with the key's 16 bytes, last to first.
function Get-Deobfuscated([byte[]]$Data, [string]$FontKey) {
    $hex = $FontKey.Trim('{', '}').Replace('-', '')
    $key = for ($i = 0; $i -lt 16; $i++) { [Convert]::ToByte($hex.Substring(30 - $i * 2, 2), 16) }
    $o = [byte[]]$Data.Clone()
    for ($i = 0; $i -lt 32; $i++) { $o[$i] = $o[$i] -bxor $key[$i % 16] }
    return , $o
}
function Read-Bytes([string]$Path) { return [IO.File]::ReadAllBytes($Path) }
function Get-Latin1([string]$Path) { return [Text.Encoding]::GetEncoding(28591).GetString([IO.File]::ReadAllBytes($Path)) }

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
    $logoHash = Get-Sha (Get-Png 120 40 'Red')

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
        # tables' column widths (<colgroup>, class "sized"), new since.
        $noStyle = { param([string]$P) $t = [regex]::Replace([regex]::Replace([IO.File]::ReadAllText($P), '(?s)<style>.*?</style>', ''), 'Scope: [^<]*', 'Scope:'); [regex]::Replace($t.Replace('<table class="sized">', '<table>'), '<colgroup>.*?</colgroup>?
', '') }
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

    # 3. PDF.
    $pdf = Join-Path $work 'themed.pdf'
    $r = Invoke-LazySpec $lazyspec $proj 'Pdf' @('-Out', $pdf)
    Check ($r.Code -eq 0 -and (Test-Path -LiteralPath $pdf)) 'PDF with the theme' $r.Out
    if ($r.Code -eq 0) {
        $p = Get-PdfText $pdf
        Check ($p -match '/MediaBox\s*\[\s*0\s+0\s+612(\.0+)?\s+792(\.0+)?\s*\]') 'PDF: the theme''s page size (Letter)'
        Check ($p -match '/BaseFont\s*/[A-Z]{6}\+Georgia') 'PDF: the theme''s font in it'
        Check (([regex]::Matches($p, '/Subtype\s*/Image')).Count -ge 2) 'PDF: the pictures (cover and header logo)'
        # The header's logo on the pages after the cover: each page's resources name a picture.
        $pages = @([regex]::Matches($p, '/Type\s*/Page\b(?!s)'))
        Check ($pages.Count -ge 3 -and ([regex]::Matches($p, '/XObject\s*<<')).Count -ge $pages.Count) 'PDF: a picture on every page (the cover''s logo, then the header''s)' "pages: $($pages.Count)" 
    }

    # 4. Word.
    $docx = Join-Path $work 'themed.docx'
    $r = Invoke-LazySpec $lazyspec $proj 'Word' @('-Out', $docx)
    Check ($r.Code -eq 0 -and (Test-Path -LiteralPath $docx)) 'Word with the theme' $r.Out
    if ($r.Code -eq 0) {
        $w = Read-Docx $docx
        $wb = Read-Docx $docx -Bytes
        $doc = $w['word/document.xml']; $st = $w['word/styles.xml']
        # The text's font: Normal's, or the defaults Normal takes (Word moves it there when it saves).
        $normal = [regex]::Match($st, '(?s)<w:style w:type="paragraph" w:default="1" w:styleId="Normal">.*?</w:style>').Value
        $defaults = [regex]::Match($st, '(?s)<w:docDefaults>.*?</w:docDefaults>').Value
        Check ($normal -match 'w:ascii="Georgia"' -or ($normal -notmatch 'w:rFonts' -and $defaults -match 'w:ascii="Georgia"')) 'Word: Normal in the theme''s font'
        Check ($st -match '(?s)w:styleId="Heading1">.*?<w:color w:val="C2185B"/>.*?</w:style>') 'Word: Heading1 in the theme''s colour'
        $used = @([regex]::Matches($doc, '<w:pStyle w:val="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        foreach ($s in 'Title', 'Subtitle', 'Heading1', 'Heading2', 'ListParagraph', 'TOCHeading') { Check ($used -contains $s -and $st -match "w:styleId=`"$s`"") "Word: style $s defined and used" "used: $($used -join ', ')" }
        Check ($doc -match '<w:tblStyle w:val="TableGrid"/>' -and $st -match 'w:styleId="TableGrid"') 'Word: tables in TableGrid'
        $sect = [regex]::Match($doc, '(?s)<w:sectPr\b.*</w:sectPr>\s*</w:body>').Value
        Check ($sect -match '<w:pgSz w:w="12240" w:h="15840"/>' -and $sect -match 'w:top="2154"' -and $sect -match 'w:left="1361"') 'Word: the theme''s page size and margins'
        Check ($sect -match 'w:headerReference w:type="default"' -and $sect -match 'w:footerReference w:type="default"' -and $sect -match 'w:type="first"' -and $sect -match '<w:titlePg/>') 'Word: header and footer, none on the cover'
        $hdrRels = @($w.Keys | Where-Object { $_ -match '^word/_rels/header\d*\.xml\.rels$' } | ForEach-Object { $w[$_] }) -join ''
        $pics = @([regex]::Matches($hdrRels, 'Target="(media/[^"]+)"') | ForEach-Object { $w["word/$($_.Groups[1].Value)"] })
        Check ($pics -contains $logoHash) 'Word: the header''s logo'
        $ftr = @($w.Keys | Where-Object { $_ -match '^word/footer\d*\.xml$' } | ForEach-Object { $w[$_] }) -join ''
        Check ($ftr -match 'PAGE' -and $ftr -match 'NUMPAGES' -and $ftr -match 'Acme Portal') 'Word: the footer''s title and PAGE / NUMPAGES'
        $ft = $w['word/fontTable.xml']
        $font = [regex]::Match($ft, '(?s)<w:font w:name="Georgia">.*?</w:font>').Value
        $embeds = @([regex]::Matches($font, '<w:embed(\w+) r:id="([^"]+)" w:fontKey="([^"]+)"'))
        Check ($embeds.Count -ge 1 -and $font -match '<w:embedRegular ') 'Word: Georgia embedded (regular at least)' $font
        $ftRels = $w['word/_rels/fontTable.xml.rels']
        $valid = 0
        foreach ($e in $embeds) {
            $target = [regex]::Match($ftRels, "Id=`"$($e.Groups[2].Value)`"[^>]*Target=`"([^`"]+)`"").Groups[1].Value
            if (-not $target) { $target = [regex]::Match($ftRels, "Target=`"([^`"]+)`"[^>]*Id=`"$($e.Groups[2].Value)`"").Groups[1].Value }
            $data = $wb["word/$target"]
            if (-not $data) { continue }
            $font = Get-Deobfuscated $data $e.Groups[3].Value
            $sfnt = ($font[0] -eq 0 -and $font[1] -eq 1 -and $font[2] -eq 0 -and $font[3] -eq 0)
            $name = [Text.Encoding]::GetEncoding(28591).GetString($font)
            if ($sfnt -and ($name.Contains("`0G`0e`0o`0r`0g`0i`0a") -or $name.Contains('Georgia'))) { $valid++ }
        }
        Check ($embeds.Count -and $valid -eq $embeds.Count) 'Word: the embedded fonts are the font files (de-obfuscated: a TrueType font named Georgia)' "$valid of $($embeds.Count)"
        Check ($w['word/settings.xml'] -match '<w:embedTrueTypeFonts/>') 'Word: fonts kept embedded when it saves'
        Check ($w['word/theme/theme1.xml'] -match '<a:minorFont><a:latin typeface="Georgia"/>') 'Word: the theme''s font as Word''s body font'
        $all = (@($w.Keys | Where-Object { $_ -match '\.xml$' } | ForEach-Object { $w[$_] }) -join '')
        Check ($all -notmatch 'Aptos') 'Word: no Office default font (Aptos)'
        Check ($doc -match 'w:ascii="Consolas"' -and $doc -notmatch 'w:ascii="(Georgia|Segoe UI)"') 'Word: only code gets a font of its own (the theme''s code font)'
        $coverLogo = @($w.Keys | Where-Object { $_ -match '^word/media/' } | Where-Object { $w[$_] -eq (Get-Sha (Get-Png 300 100 'Blue')) })
        Check ($coverLogo.Count -ge 1) 'Word: the cover''s logo'
    }
    if (-not $hasWord) { Write-Host '        (no Word here: the documents as LazySpec built them, without the contents'' page numbers)' -ForegroundColor DarkGray }

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

    # 8. A template and a theme.
    $both = Join-Path $work 'both'
    New-FixtureTemplate (Join-Path $both 'template.docx') 'TEMPLATE-HEADER-MARK'
    New-FixtureTheme (Join-Path $both 'theme') $themeYaml
    New-FixtureProject $both @('documentTemplate: template.docx', 'documentTheme: theme/document-theme.yaml')
    $r = Invoke-LazySpec $lazyspec $both 'Word' @('-Out', (Join-Path $work 'both.docx'))
    $hdr = ''
    if ($r.Code -eq 0) { $bw = Read-Docx (Join-Path $work 'both.docx'); $hdr = @($bw.Keys | Where-Object { $_ -match '^word/header\d*\.xml$' } | ForEach-Object { $bw[$_] }) -join '' }
    Check ($r.Code -eq 0 -and $hdr -match 'TEMPLATE-HEADER-MARK' -and $r.Out -match 'uses the template') 'template and theme: Word on the template (and says so)' $r.Out
    $r = Invoke-LazySpec $lazyspec $both 'Pdf' @('-Out', (Join-Path $work 'both.pdf'))
    Check ($r.Code -eq 0 -and (Get-PdfText (Join-Path $work 'both.pdf')) -match '/MediaBox\s*\[\s*0\s+0\s+612') 'template and theme: PDF on the theme' $r.Out
    $r = Invoke-LazySpec $lazyspec $both 'Word' @('-Out', (Join-Path $work 'both-theme.docx'), '-Theme', (Join-Path $both 'theme\document-theme.yaml'))
    $hdr = ''
    if ($r.Code -eq 0) { $bw = Read-Docx (Join-Path $work 'both-theme.docx'); $hdr = @($bw.Keys | Where-Object { $_ -match '^word/header\d*\.xml$' } | ForEach-Object { $bw[$_] }) -join '' }
    Check ($r.Code -eq 0 -and $hdr -notmatch 'TEMPLATE-HEADER-MARK' -and $bw['word/fontTable.xml'] -match 'Georgia') '-Theme on the command line: Word on the theme, over the config''s template' $r.Out
}
finally {
    if (-not $Keep) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-TestSummary $(if ($Keep) { $work })
exit [int]($script:failed -gt 0)

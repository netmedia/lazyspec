#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-WordTemplate.ps1                               |
#  |   The Word export on the project's template (documentTemplate)           |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests the Word export with and without a document template (lazyspec: documentTemplate: in
    openspec/config.yaml, or -Template). No modules: it builds its own project and template in %TEMP%.

.DESCRIPTION
    1. Without documentTemplate: the .docx is the same as the one before templates (-Baseline: that
       lazyspec.ps1; default: git HEAD's when it has no templates yet; else this test is skipped).
    2. With the template: its header and footer parts and their pictures are in the result, the content
       uses its style IDs, none of its sample text is left, its section properties are kept.
    3. A template path with spaces resolves against the project's root (lazyspec started in a subfolder).
    4. A missing template: a clear error naming the resolved path, exit code 1.
    5. A broken template (not a .docx): a clear error, exit code 1.
    6. -Template wins over the config's documentTemplate.

    Word (or pandoc) is needed for 1; 2-6 need neither (Word, when there, adds the contents' page numbers).

.PARAMETER Baseline
    A lazyspec.ps1 from before document templates, for test 1.

.PARAMETER Keep
    Keep the test project in %TEMP% (to look at the documents).

.EXAMPLE
    .\tests\Test-WordTemplate.ps1

.EXAMPLE
    .\tests\Test-WordTemplate.ps1 -Baseline D:\old\lazyspec.ps1 -Keep
#>
[CmdletBinding()]
param(
    [string]$Baseline,
    [switch]$Keep
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$work = Join-Path ([IO.Path]::GetTempPath() -replace '^/var/', '/private/var/') ('lazyspec-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

# --- the fixtures -----------------------------------------------------------------------------------------

# --- the tests --------------------------------------------------------------------------------------------

Write-Host ''
Write-Host "  LazySpec: Word export on a document template ($work)" -ForegroundColor Cyan
Write-Host ''
$hasWord = Test-WordInstalled
$hasPandoc = [bool](Get-Command pandoc -CommandType Application -ErrorAction SilentlyContinue)
try {
    $tplPath = Join-Path $work 'acme\openspec\artifacts\Company template.docx'
    $proj = Join-Path $work 'acme'
    New-FixtureTemplate $tplPath 'ACME-HEADER-MARK'
    $other = Join-Path $work 'other templates\Other one.docx'
    New-FixtureTemplate $other 'OTHER-HEADER-MARK'
    $logoHash = Get-Sha (Get-Png 60 20 'Red')
    $samples = 'DOCUMENT TITLE', 'Title section', 'Text section', 'Bulletted text', 'Column value', 'Sample link', 'example.com/sample'

    # 1. Without documentTemplate: as before.
    $plain = Join-Path $work 'plain'
    New-FixtureProject $plain @()
    if (-not $Baseline) {
        $Baseline = Get-Baseline $repo $work 'Export-WordTemplate'
    }
    if (-not $hasWord -and -not $hasPandoc) { Skip 'without a template: as before' 'neither Word nor pandoc here' }
    elseif (-not $Baseline -or -not (Test-Path -LiteralPath $Baseline)) { Skip 'without a template: as before' 'no lazyspec.ps1 from before templates (-Baseline)' }
    else {
        Copy-KitFiles $lazyspec $Baseline
        $a = Invoke-LazySpec $Baseline $plain 'Word' @('-Out', (Join-Path $work 'before.docx'))
        $b = Invoke-LazySpec $lazyspec $plain 'Word' @('-Out', (Join-Path $work 'now.docx'))
        if ($a.Code -or $b.Code) { Fail 'without a template: as before' "exit codes $($a.Code) / $($b.Code): $($a.Out) $($b.Out)" }
        else {
            $pa = Read-Docx (Join-Path $work 'before.docx'); $pb = Read-Docx (Join-Path $work 'now.docx')
            $same = (Get-Normalized $pa['word/document.xml']) -eq (Get-Normalized $pb['word/document.xml'])
            $sameParts = (@($pa.Keys | Sort-Object) -join ',') -eq (@($pb.Keys | Sort-Object) -join ',')
            # Word's built-in styles as before; the custom ones Word makes from LazySpec's CSS classes may grow.
            $builtIn = { param([string]$X) [regex]::Replace((Get-Normalized $X), '(?s)<w:style\b[^>]*w:customStyle="1"[^>]*>.*?</w:style>', '') }
            $sameStyles = (& $builtIn $pa['word/styles.xml']) -eq (& $builtIn $pb['word/styles.xml'])
            Check ($same -and $sameParts -and $sameStyles) 'without a template: the same document as before' "document.xml same: $same, parts same: $sameParts, styles same: $sameStyles"
            Check ($b.Out -notmatch 'Word template') 'without a template: no template used' $b.Out
        }
    }

    # 2. + 3. With the template (spaces in its path, relative to the root; started in a subfolder).
    New-FixtureProject $proj @('# documentTemplate: the Word template (.docx) every generated document uses', 'documentTemplate: openspec/artifacts/Company template.docx')
    $outDoc = Join-Path $work 'with template.docx'
    $r = Invoke-LazySpec $lazyspec (Join-Path $proj 'src\deep') 'Word' @('-Out', $outDoc)
    Check ($r.Code -eq 0 -and (Test-Path -LiteralPath $outDoc)) 'path with spaces, relative to the project root (started in a subfolder)' $r.Out
    if ($r.Code -eq 0) {
        Check ($r.Out -match [regex]::Escape("Word template: $tplPath")) 'the template resolved to <root>\openspec\artifacts\Company template.docx' $r.Out
        $p = Read-Docx $outDoc
        $doc = $p['word/document.xml']
        $hdr = @($p.Keys | Where-Object { $_ -match '^word/header\d*\.xml$' })
        Check ($hdr.Count -ge 1 -and @($p.Keys | Where-Object { $_ -match '^word/footer\d*\.xml$' }).Count -ge 1) 'the template''s header and footer parts are there'
        Check (@($hdr | Where-Object { $p[$_] -match 'ACME-HEADER-MARK' }).Count -eq 1) 'the header is the template''s'
        # The logo: the picture the header points at, the same bytes as the template's (Word may rename it).
        $hdrRels = @($p.Keys | Where-Object { $_ -match '^word/_rels/header\d*\.xml\.rels$' } | ForEach-Object { $p[$_] }) -join ''
        $pics = @([regex]::Matches($hdrRels, 'Target="(media/[^"]+)"') | ForEach-Object { $p["word/$($_.Groups[1].Value)"] })
        Check ($pics -contains $logoHash) 'the header''s picture (the logo) is there, unchanged' "header pictures: $($pics.Count)" 
        $sect = [regex]::Match($doc, '(?s)<w:sectPr\b.*</w:sectPr>\s*</w:body>').Value
        Check ($sect -match 'w:headerReference' -and $sect -match 'w:footerReference' -and $sect -match 'w:titlePg' -and $sect -match 'w:left="1418"') 'the template''s section properties are kept (headers, footers, margins, first page)'
        $styles = [regex]::Matches($doc, '<w:pStyle w:val="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
        foreach ($s in 'Title', 'Subtitle', 'Heading1', 'Heading2', 'Heading3', 'Heading4', 'ListParagraph', 'TOCHeading') { Check ($styles -contains $s) "style $s used" "used: $($styles -join ', ')" }
        # Normal: by name, or as the default paragraph style (Word leaves it out when it saves).
        $body = [regex]::Match($doc, '(?s)<w:body>.*</w:body>').Value
        $plainParas = @([regex]::Matches($body, '(?s)<w:p\b[^>]*>.*?</w:p>') | Where-Object { $_.Value -match '<w:t\b' -and $_.Value -notmatch '<w:pStyle ' }).Count
        Check (($styles -contains 'Normal' -or $plainParas -gt 0) -and $p['word/styles.xml'] -match 'w:default="1" w:styleId="Normal"') 'style Normal used (the body text)' "pStyle Normal: $($styles -contains 'Normal'), paragraphs in the default style: $plainParas" 
        Check ($doc -match '<w:tblStyle w:val="TableGrid"/>') 'tables use TableGrid'
        $unknown = @($styles | Where-Object { $p['word/styles.xml'] -notmatch "w:styleId=`"$_`"" })
        Check (-not $unknown.Count) 'every paragraph style is one of the template''s' "unknown: $($unknown -join ', ')"
        $text = (-join @([regex]::Matches($doc, '<w:t(?: [^>]*)?>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }))
        $left = @($samples | Where-Object { $text.Contains($_) -or $doc.Contains($_) -or $p['word/_rels/document.xml.rels'].Contains($_) })
        Check (-not $left.Count) 'none of the template''s sample text is left' "found: $($left -join ', ')"
        Check (-not $p.ContainsKey('word/media/cover.png')) 'the sample cover''s picture is gone'
        Check ($p['docProps/core.xml'] -notmatch 'DOCUMENT TITLE' -and $p['docProps/core.xml'] -match 'Acme Portal') 'the document''s title in its properties'
        Check ($text.Contains('Acme Portal') -and $text.Contains('Password sign-in') -and $text.Contains('curl -s https://example.com/api/login')) 'the content is there'
        Check ($doc -notmatch 'w:rFonts w:ascii="(Montserrat|Georgia|Lato|Segoe UI)') 'no fonts set over the template''s (only code gets a monospace font)'
        $used = @([regex]::Matches($doc, '<w:numId w:val="(\d+)"/>') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $defined = @([regex]::Matches($p['word/numbering.xml'], '<w:num w:numId="(\d+)"') | ForEach-Object { $_.Groups[1].Value })
        Check ($used.Count -ge 2 -and -not @($used | Where-Object { $defined -notcontains $_ }).Count) 'lists are numbered, with numberings the document defines' "used: $($used -join ','), defined: $($defined -join ',')" 
        Check ($r.Out -match 'fonts of the Word template not installed on this PC: [^
]*LazySpec Missing Font') 'a warning names the template''s fonts this PC lacks' $r.Out
    }

    # 4. A missing template: an error naming the resolved path.
    $missing = Join-Path $work 'missing'
    New-FixtureProject $missing @('documentTemplate: openspec/artifacts/No such template.docx')
    $r = Invoke-LazySpec $lazyspec $missing 'Word' @('-Out', (Join-Path $work 'missing.docx'))
    $resolved = Join-Path $missing 'openspec\artifacts\No such template.docx'
    Check ($r.Code -ne 0) 'missing template: a non-zero exit code' "exit code $($r.Code)"
    Check ($r.Out -match [regex]::Escape($resolved)) 'missing template: the error names the resolved path' $r.Out
    Check (-not (Test-Path -LiteralPath (Join-Path $work 'missing.docx'))) 'missing template: no document in the default look'

    # 5. A broken template.
    $broken = Join-Path $work 'broken'
    New-FixtureProject $broken @('documentTemplate: bad.docx')
    [IO.File]::WriteAllText((Join-Path $broken 'bad.docx'), 'not a Word document')
    $r = Invoke-LazySpec $lazyspec $broken 'Word' @('-Out', (Join-Path $work 'broken.docx'))
    Check ($r.Code -ne 0 -and $r.Out -match "isn't a valid \.docx" -and $r.Out -match [regex]::Escape((Join-Path $broken 'bad.docx'))) 'broken template: a clear error, non-zero exit code' $r.Out

    # 6. -Template wins over the config (the config's is missing here: it isn't even looked at).
    $outOther = Join-Path $work 'override.docx'
    $r = Invoke-LazySpec $lazyspec $missing 'Word' @('-Out', $outOther, '-Template', $other)
    Check ($r.Code -eq 0) '-Template overrides the config''s documentTemplate' $r.Out
    if ($r.Code -eq 0) {
        $p = Read-Docx $outOther
        $hdr = @($p.Keys | Where-Object { $_ -match '^word/header\d*\.xml$' } | ForEach-Object { $p[$_] }) -join ''
        Check ($hdr -match 'OTHER-HEADER-MARK' -and $hdr -notmatch 'ACME-HEADER-MARK') '-Template: the document is on that template'
    }
    # -Template relative to the current folder.
    Push-Location (Split-Path $other)
    try { $r = Invoke-LazySpec $lazyspec (Split-Path $other) 'Word' @('-Root', $missing, '-Out', (Join-Path $work 'relative.docx'), '-Template', 'Other one.docx') } finally { Pop-Location }
    Check ($r.Code -eq 0) '-Template relative to the current folder' $r.Out
}
finally {
    if (-not $Keep) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-TestSummary $(if ($Keep) { $work })
exit [int]($script:failed -gt 0)

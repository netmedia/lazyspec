#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-WordTemplate.ps1                               |
#  |   Word: Netmedia documents, on the project's template copy (documentTemplate) |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests the Word export: a Netmedia document made by netmedia-document (Python with python-docx), on the
    Netmedia template or the project's copy of it (lazyspec: documentTemplate: in openspec/config.yaml, or
    -Template). No modules: it builds its own project and template in %TEMP%.

.DESCRIPTION
    1. Without documentTemplate: the Netmedia template (its cover with the title, its contents, its header
       with the logo, Montserrat); no template named.
    2. With the template (a copy of the Netmedia template's structure): its header and footer parts and their
       pictures are in the result, its section properties are kept, none of its sample text after the
       contents is left, the content in its Heading styles.
    3. A template path with spaces resolves against the project's root (lazyspec started in a subfolder).
    4. A missing template: a clear error naming the resolved path, exit code 1.
    5. A broken template (not a .docx): a clear error, exit code 1.
    6. -Template wins over the config's documentTemplate.

    Word isn't needed (when it's there, it fills in the contents' page numbers).

.PARAMETER Keep
    Keep the test project in %TEMP% (to look at the documents).

.EXAMPLE
    .\tests\Test-WordTemplate.ps1

.EXAMPLE
    .\tests\Test-WordTemplate.ps1 -Baseline D:\old\lazyspec.ps1 -Keep
#>
[CmdletBinding()]
param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$work = Join-Path ([IO.Path]::GetTempPath() -replace '^/var/', '/private/var/') ('lazyspec-test-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

# --- the fixtures -----------------------------------------------------------------------------------------

# --- the tests --------------------------------------------------------------------------------------------

Write-Host ''
Write-Host "  LazySpec: Word exports, Netmedia documents ($work)" -ForegroundColor Cyan
Write-Host ''
try {
    $tplPath = Join-Path $work 'acme\openspec\artifacts\Company template.docx'
    $proj = Join-Path $work 'acme'
    New-FixtureTemplate $tplPath 'ACME-HEADER-MARK'
    $other = Join-Path $work 'other templates\Other one.docx'
    New-FixtureTemplate $other 'OTHER-HEADER-MARK'
    $logoHash = Get-Sha (Get-Png 60 20 'Red')
    $samples = 'DOCUMENT TITLE', 'Title section', 'Text section', 'Bulletted text', 'Column value', 'Sample link'

    # 1. Without documentTemplate: the Netmedia template.
    $plain = Join-Path $work 'plain'
    New-FixtureProject $plain @()
    $r = Invoke-LazySpec $lazyspec $plain 'Word' @('-Out', (Join-Path $work 'plain.docx'))
    Check ($r.Code -eq 0) 'without a template: a Netmedia document' $r.Out
    if ($r.Code -eq 0) {
        Check ($r.Out -notmatch 'Word template:') 'without a template: none named' $r.Out
        $p = Read-Docx (Join-Path $work 'plain.docx')
        $text = (-join @([regex]::Matches($p['word/document.xml'], '<w:t(?: [^>]*)?>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }))
        Check ($text.Contains('ACME PORTAL') -and $text.Contains('Table of contents') -and -not $text.Contains('DOCUMENT TITLE')) 'without a template: the Netmedia cover with the title, the contents'
        Check ($p['word/styles.xml'] -match 'Montserrat') 'without a template: the Netmedia template''s font'
        $hdrRels = @($p.Keys | Where-Object { $_ -match '^word/_rels/header\d*\.xml\.rels$' } | ForEach-Object { $p[$_] }) -join ''
        Check ($hdrRels -match 'Target="media/') 'without a template: the Netmedia header with its logo'
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
        foreach ($s in 'Heading1', 'Heading2') { Check ($styles -contains $s) "style $s used" "used: $($styles -join ', ')" }
        $text = (-join @([regex]::Matches($doc, '<w:t(?: [^>]*)?>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }))
        $left = @($samples | Where-Object { $text.Contains($_) -or $doc.Contains($_) -or $p['word/_rels/document.xml.rels'].Contains($_) })
        Check (-not $left.Count) 'none of the template''s sample text is left' "found: $($left -join ', ')"
        Check ($p['docProps/core.xml'] -notmatch 'DOCUMENT TITLE' -and $p['docProps/core.xml'] -match 'Acme Portal') 'the document''s title in its properties'
        Check ($text.Contains('ACME PORTAL') -and $text.Contains('Password sign-in') -and $text.Contains('curl -s https://example.com/api/login')) 'the content is there (the cover''s title in capitals)'
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

#Requires -Version 5.1

#  +==========================================================================+
#  |   LazySpec  -  tests\Test-MarkdownDocument.ps1                           |
#  |   lazyspec -Export <format> -Markdown <file>: any Markdown as a document |
#  |                                                                          |
#  |   Author  : Netmedia                                                     |
#  |   Web     : https://netmedia.agency                                      |
#  |   Email   : netmedia@netmedia.hr                                         |
#  |   Product : LazySpec  -  https://github.com/netmedia/lazyspec            |
#  +==========================================================================+

<#
.SYNOPSIS
    Tests -Markdown: a Markdown file (meeting notes, a summary ...) as a PDF, Word or HTML document in the
    project's look. No modules: it builds its own project, theme and files in %TEMP%.

.DESCRIPTION
    1. The front matter: title, subtitle, client, date on the cover; no title: the first "# " heading, else
       the file's name.
    2. Headings don't start pages; toc: true: a contents of headings 1-2; cover: false: no cover page.
    3. Hard line breaks ("\" or two spaces at a line's end), in paragraphs and list items.
    4. Written next to the Markdown file, the same name; -Out elsewhere.
    5. The project's theme (the file in a subfolder of the project); outside a project: a note, the default look.
    6. Word: a Netmedia document (netmedia-document): the cover with the title, the contents, Heading 1 and 2.
    7. PDF (Word exports it; without Word: a clear error): a cover page, then the text.
    8. Errors: a missing file, a broken front matter: a clear error, exit code 1.

.PARAMETER Keep
    Keep the test files in %TEMP%.

.EXAMPLE
    .\tests\Test-MarkdownDocument.ps1
#>
[CmdletBinding()]
param([switch]$Keep)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$lazyspec = Join-Path $repo 'tools\lazyspec\lazyspec.ps1'
$work = Join-Path ([IO.Path]::GetTempPath() -replace '^/var/', '/private/var/') ('lazyspec-md-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
. (Join-Path $PSScriptRoot 'TestHelpers.ps1')

function Write-Md([string]$Path, [string]$Text) { [void](New-Item -ItemType Directory -Force -Path (Split-Path $Path)); [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding $false)) }
function Get-Body([string]$Html) { return [regex]::Match($Html, '(?s)<body>.*</body>').Value }

$notes = @'
---
title: Weekly meeting
subtitle: Notes, 4 November
client: Acme d.o.o.
date: 4. 11. 2026.
toc: true
---

**Present:**\
- Ana;\
- Ben

# Agreed

## Payments

Line one\
Line two  
Line three

| Item | Owner |
|---|---|
| Invoices | Ana |

# Open questions

1. When?
'@

Write-Host ''
Write-Host "  LazySpec: Markdown documents ($work)" -ForegroundColor Cyan
Write-Host ''
try {
    # A project with a theme; the notes in a subfolder of it.
    $proj = Join-Path $work 'acme'
    New-FixtureProject $proj @('documentTheme: theme/document-theme.yaml')
    $theme = Join-Path $proj 'theme'
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $theme 'fonts'))
    Copy-Item -LiteralPath (Get-GeorgiaFiles)[0] -Destination (Join-Path $theme 'fonts')
    [IO.File]::WriteAllText((Join-Path $theme 'document-theme.yaml'), "styles:`n  body: { font: Georgia, size: 10pt }`n  heading1: { color: `"#C2185B`" }`nfooter: { right: `"{page} / {pages}`" }`n")
    $md = Join-Path $proj 'meetings\2026-11-04 weekly.md'
    Write-Md $md $notes

    # 1-5. HTML, from another folder (the file's project is found from the file).
    $r = Invoke-LazySpec $lazyspec $work 'Html' @('-Markdown', $md)
    $html = [IO.Path]::ChangeExtension($md, 'html')
    Check ($r.Code -eq 0 -and (Test-Path -LiteralPath $html)) 'written next to the Markdown file, the same name' $r.Out
    if ($r.Code -eq 0) {
        $h = [IO.File]::ReadAllText($html)
        $b = Get-Body $h
        Check ($b -match '<p class="title">Weekly meeting</p>' -and $b -match '<p class="subtitle">Notes, 4 November</p>' -and $b -match 'Acme d\.o\.o\.' -and $b -match '4\. 11\. 2026\.') 'the front matter on the cover (title, subtitle, client, date)'
        Check ($b -notmatch '---' -and $b -notmatch 'toc: true') 'the front matter isn''t in the text'
        Check ($h -match 'h1, h1\.part \{ page-break-before: auto; \}') 'headings don''t start pages'
        Check ($b -match '<div class="toc">' -and $b -match '<p class="l1"><a href="#[^"]+">Agreed</a></p>' -and $b -match '<p class="l2"><a href="#[^"]+">Payments</a></p>') 'toc: true: a contents of headings 1-2, with links'
        Check ($b -match '<p class="page-break"></p>') 'the text on a page of its own after the cover'
        Check ($b -match '<p>Line one<br>Line two<br>Line three</p>') 'hard line breaks in a paragraph ("\" and two spaces)'
        Check ($b -match '<li>Ana;</li>' -and $b -match '<p><strong>Present:</strong></p>') 'a "\" at a list item''s or a paragraph''s end: no backslash, no empty line'
        Check ($h -match "@font-face \{ font-family: 'Georgia'" -and $r.Out -match 'document theme: ') 'the project''s theme (found from the file''s folder)' $r.Out
    }

    # Pictures (![alt](path), relative to the Markdown file) and a pipe inside a table cell (\|).
    $md4 = Join-Path $proj 'meetings\with pictures.md'
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $proj 'meetings\img'))
    [IO.File]::WriteAllBytes((Join-Path $proj 'meetings\img\flow chart.png'), (Get-Png 300 150 'SteelBlue'))
    Write-Md $md4 "# Pictures`n`nText.`n`n![The flow, step by step](img/flow%20chart.png)`n`n![Gone](img/missing.png)`n`n| Option | Values |`n|---|---|`n| ``mode`` | ``ask \| always \| never`` |`n"
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Markdown', $md4)
    $b = Get-Body ([IO.File]::ReadAllText([IO.Path]::ChangeExtension($md4, 'html')))
    Check ($r.Code -eq 0 -and $b -match '<div class="diagram"><img src="data:image/png;base64,[^"]+" width="300" height="150" alt="The flow, step by step"><p class="caption">The flow, step by step</p></div>') 'a picture: inside the document, its alt text under it (no "Diagram:")' $r.Out
    Check ($r.Out -match 'picture not found: img/missing\.png' -and $b -match '<p>Gone</p>') 'a missing picture: a note, its alt text in its place' $r.Out
    Check ($b -match '<td><code>ask \| always \| never</code></td>' -and ([regex]::Matches($b, '<td>')).Count -eq 2) 'a table cell with an escaped pipe (\|): one cell, the pipe kept'
    $r = Invoke-LazySpec $lazyspec $proj 'Word' @('-Markdown', $md4)
    $w = Read-Docx ([IO.Path]::ChangeExtension($md4, 'docx'))
    Check ($r.Code -eq 0 -and ([regex]::Matches($w['word/document.xml'], '<w:drawing>')).Count -ge 2 -and $w['word/document.xml'] -match 'The flow, step by step') 'Word: the picture embedded, its caption under it (the cover''s logo the other drawing)' $r.Out

    # The title from the first "# " heading, else the file's name; cover: false.
    $md2 = Join-Path $proj 'meetings\no front matter.md'
    Write-Md $md2 "# Kick-off`n`nHello.`n`n## Next`n`nMore.`n"
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Markdown', $md2)
    $b = Get-Body ([IO.File]::ReadAllText([IO.Path]::ChangeExtension($md2, 'html')))
    Check ($r.Code -eq 0 -and $b -match '<p class="title">Kick-off</p>' -and ([regex]::Matches($b, 'Kick-off')).Count -eq 1) 'no front matter: the first "# " heading is the title (once)' $r.Out
    Check ($b -notmatch 'class="toc"') 'no toc: no contents'
    $md3 = Join-Path $proj 'meetings\plain notes.md'
    Write-Md $md3 "---`ncover: false`n---`n`nJust text.`n"
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Markdown', $md3, '-Out', (Join-Path $work 'plain.html'))
    $h3 = [IO.File]::ReadAllText((Join-Path $work 'plain.html'))
    Check ($r.Code -eq 0 -and (Get-Body $h3) -match '<p class="title">plain notes</p>' -and (Get-Body $h3) -notmatch 'page-break' -and $h3 -match '\.toc-title \{ page-break-before: auto; \}') 'cover: false: the file''s name as title, the text right under it; -Out' $r.Out

    # Outside a project: a note, the default look.
    $loose = Join-Path $work 'loose\note.md'
    Write-Md $loose "# Loose`n`nText.`n"
    $r = Invoke-LazySpec $lazyspec (Split-Path $loose) 'Html' @('-Markdown', 'note.md')
    Check ($r.Code -eq 0 -and $r.Out -match "isn't in a project" -and [IO.File]::ReadAllText([IO.Path]::ChangeExtension($loose, 'html')) -notmatch '@font-face') 'outside a project: a note, the default look (relative path)' $r.Out

    # 6. Word.
    $r = Invoke-LazySpec $lazyspec $proj 'Word' @('-Markdown', $md)
    $docx = [IO.Path]::ChangeExtension($md, 'docx')
    Check ($r.Code -eq 0 -and (Test-Path -LiteralPath $docx)) 'Word document' $r.Out
    if ($r.Code -eq 0) {
        $w = Read-Docx $docx
        $doc = $w['word/document.xml']
        $used = @([regex]::Matches($doc, '<w:pStyle w:val="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        Check ($used -contains 'Heading1' -and $used -contains 'Heading2') 'Word: Heading1, Heading2' "used: $($used -join ', ')"
        $text = (-join @([regex]::Matches($doc, '<w:t(?: [^>]*)?>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }))
        Check ($r.Out -match 'Netmedia document: ' -and $text -cmatch 'ACME PORTAL|[A-Z ]{6,}') 'Word: a Netmedia document, the title on its cover' $r.Out
        Check ($doc -match 'TOC \\o') 'Word: the contents (a TOC field)'
        Check (@([regex]::Matches($doc, '<w:br w:type="page"/>')).Count -ge 1) 'Word: the text on a page of its own after the cover'
    }

    # 7. PDF (Word exports it).
    $pdf = Join-Path $work 'notes.pdf'
    $r = Invoke-LazySpec $lazyspec $proj 'Pdf' @('-Markdown', $md, '-Out', $pdf)
    if (-not (Test-WordInstalled)) { Check ($r.Code -ne 0 -and $r.Out -match 'PDF needs Microsoft Word') 'PDF without Word: a clear error' $r.Out; $r = [pscustomobject]@{ Code = 1 } }
    else { Check ($r.Code -eq 0 -and (Test-Path -LiteralPath $pdf)) 'PDF document' $r.Out }
    if ($r.Code -eq 0) { Check (([regex]::Matches((Get-PdfText $pdf), '/Type\s*/Page\b(?!s)')).Count -ge 3) 'PDF: cover, contents, text: 3 pages at least' }

    # 8. Errors.
    $r = Invoke-LazySpec $lazyspec $proj 'Pdf' @('-Markdown', 'meetings\missing.md')
    Check ($r.Code -ne 0 -and $r.Out -match [regex]::Escape((Join-Path $proj 'meetings\missing.md'))) 'a missing file: an error naming it, exit code 1' $r.Out
    $bad = Join-Path $proj 'meetings\bad.md'
    Write-Md $bad "---`ntitle: { broken`n---`n`nText.`n"
    $r = Invoke-LazySpec $lazyspec $proj 'Html' @('-Markdown', $bad)
    Check ($r.Code -ne 0 -and $r.Out -match 'front matter') 'a broken front matter: an error, exit code 1' $r.Out
}
finally {
    if (-not $Keep) { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-TestSummary $(if ($Keep) { $work })
exit [int]($script:failed -gt 0)

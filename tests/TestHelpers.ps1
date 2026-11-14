#  LazySpec tests: what the test scripts share (results, packages, pictures, running lazyspec). Dot-source it.

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem, System.Drawing
$script:failed = 0
$script:passed = 0
$script:skipped = 0

function Pass([string]$Name) { $script:passed++; Write-Host "  PASS  $Name" -ForegroundColor Green }
function Fail([string]$Name, [string]$Why) { $script:failed++; Write-Host "  FAIL  $Name" -ForegroundColor Red; if ($Why) { Write-Host "        $Why" -ForegroundColor DarkGray } }
function Skip([string]$Name, [string]$Why) { $script:skipped++; Write-Host "  SKIP  $Name ($Why)" -ForegroundColor Yellow }
function Check([bool]$Ok, [string]$Name, [string]$Why) { if ($Ok) { Pass $Name } else { Fail $Name $Why } }
function Write-TestSummary([string]$Kept) {
    Write-Host ''
    $color = 'Green'
    if ($script:failed) { $color = 'Red' }
    Write-Host "  $($script:passed) passed, $($script:failed) failed, $($script:skipped) skipped$(if ($Kept) { "  (kept: $Kept)" })" -ForegroundColor $color
    Write-Host ''
}

function Get-Png([int]$W, [int]$H, [string]$Color) {
    $bmp = New-Object Drawing.Bitmap($W, $H)
    $gr = [Drawing.Graphics]::FromImage($bmp)
    $gr.Clear([Drawing.Color]::FromName($Color))
    $gr.Dispose()
    $ms = New-Object IO.MemoryStream
    $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return , $ms.ToArray()
}
function Get-Sha([byte[]]$Bytes) { return [BitConverter]::ToString((New-Object Security.Cryptography.SHA256Managed).ComputeHash($Bytes)) }
function New-Package([string]$Path, [hashtable]$Parts) {
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
    [void](New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent))
    $zip = [IO.Compression.ZipFile]::Open($Path, 'Create')
    try {
        foreach ($k in $Parts.Keys) {
            $s = $zip.CreateEntry($k).Open()
            $b = $Parts[$k]
            if ($b -is [string]) { $b = (New-Object Text.UTF8Encoding $false).GetBytes($b) }
            $s.Write($b, 0, $b.Length)
            $s.Dispose()
        }
    } finally { $zip.Dispose() }
}
# A .docx's parts: the XML ones as text, the others as their SHA-256 (or, with -Bytes, their bytes).
function Read-Docx([string]$Path, [switch]$Bytes) {
    $zip = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $parts = @{}
        foreach ($e in $zip.Entries) {
            if ($e.FullName -match '\.(xml|rels)$') { $r = New-Object IO.StreamReader($e.Open()); $parts[$e.FullName] = $r.ReadToEnd(); $r.Dispose() }
            else {
                $ms = New-Object IO.MemoryStream; $st = $e.Open(); $st.CopyTo($ms); $st.Dispose()
                if ($Bytes) { $parts[$e.FullName] = $ms.ToArray() } else { $parts[$e.FullName] = Get-Sha $ms.ToArray() }
            }
        }
        return $parts
    } finally { $zip.Dispose() }
}
# A document's text and structure without what changes every time Word saves (its random ids).
function Get-Normalized([string]$Xml) {
    $x = [regex]::Replace($Xml, '<w:(divId|rsid) w:val="[^"]*"/>', '')
    $x = [regex]::Replace($x, '\s(w:rsid\w*|w14:paraId|w14:textId|w:id|w:name)="[^"]*"', '')
    # The cover's counts: their words have singular forms since changes as one ("1 chapter"), not compared.
    $x = [regex]::Replace($x, 'Scope: [^<]*', 'Scope:')
    return [regex]::Replace($x, '_Toc\d+', '_Toc')
}
# A minimal project: openspec\config.yaml with a lazyspec: block ($Settings: its lines), one spec with
# headings, lists, a table, code, links and a scenario.
function New-FixtureProject([string]$Dir, [string[]]$Settings) {
    [void](New-Item -ItemType Directory -Force -Path (Join-Path $Dir 'openspec\specs\user-login'), (Join-Path $Dir 'src\deep'))
    $cfg = "schema: spec-driven`n`nlazyspec:`n  name: Acme Portal`n"
    foreach ($s in $Settings) { if ($s) { $cfg += "  $s`n" } }
    [IO.File]::WriteAllText((Join-Path $Dir 'openspec\config.yaml'), $cfg)
    $spec = @'
# User login

## Purpose
Lets users sign in with a **password**, see [the guide](https://example.com/guide) and [Requirements](#requirements).

## Requirements
### Requirement: Password sign-in
The system SHALL let users sign in.

- First point
  - A nested point
- Second point

1. One
2. Two

| Field | Rule |
|---|---|
| E-mail | required |
| Password | 12+ characters |

```
curl -s https://example.com/api/login
```

#### Scenario: Valid password
- **WHEN** the password is right
- **THEN** the user is signed in
'@
    [IO.File]::WriteAllText((Join-Path $Dir 'openspec\specs\user-login\spec.md'), $spec)
}
# lazyspec -Export <Format> in $Cwd: its output and exit code.
function Invoke-LazySpec([string]$Script, [string]$Cwd, [string]$Format, [string[]]$More) {
    Push-Location $Cwd
    try {
        $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script -Export $Format -KeepDiagrams @More 2>&1 | Out-String
        return [pscustomobject]@{ Code = $LASTEXITCODE; Out = $out }
    } finally { Pop-Location }
}
function Test-WordInstalled {
    try { $wd = New-Object -ComObject Word.Application; $wd.Quit(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($wd); return $true } catch { return $false }
}
# The lazyspec.ps1 from before a feature (git HEAD's, when it hasn't got $Marker yet), with its kit files: '' when there's none.
function Get-Baseline([string]$Repo, [string]$Work, [string]$Marker) {
    $head = & git -C $Repo show 'HEAD:tools/lazyspec/lazyspec.ps1' 2>$null | Out-String
    if (-not $head -or $head -match $Marker) { return '' }
    $b = Join-Path $Work 'baseline\lazyspec.ps1'
    [void](New-Item -ItemType Directory -Force -Path (Split-Path $b))
    [IO.File]::WriteAllText($b, $head)
    return $b
}
function Copy-KitFiles([string]$Lazyspec, [string]$Baseline) {
    foreach ($f in 'export-texts.json', 'kit.json') {
        $s = Join-Path (Split-Path $Lazyspec) $f; $d = Join-Path (Split-Path $Baseline) $f
        if (-not (Test-Path -LiteralPath $d) -and (Test-Path -LiteralPath $s)) { Copy-Item -LiteralPath $s -Destination $d }
    }
}
# A company template as Word makes them: styles, a header with a logo, a footer with the page number, and a
# sample body (a cover, a contents, sections) that must not reach the documents.
function New-FixtureTemplate([string]$Path, [string]$Marker) {
    $w = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"'
    $wp = 'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"'
    $pic = { param($rid, $name) "<w:r><w:drawing><wp:inline><wp:extent cx=`"914400`" cy=`"304800`"/><wp:docPr id=`"1`" name=`"$name`"/><a:graphic><a:graphicData uri=`"http://schemas.openxmlformats.org/drawingml/2006/picture`"><pic:pic><pic:nvPicPr><pic:cNvPr id=`"0`" name=`"$name`"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed=`"$rid`"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x=`"0`" y=`"0`"/><a:ext cx=`"914400`" cy=`"304800`"/></a:xfrm><a:prstGeom prst=`"rect`"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>" }
    $style = { param($id, $name, $type, $extra) "<w:style w:type=`"$type`" w:styleId=`"$id`"><w:name w:val=`"$name`"/><w:basedOn w:val=`"Normal`"/>$extra</w:style>" }
    $styles = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:styles $w>" +
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:rPr><w:rFonts w:ascii="Montserrat" w:hAnsi="Montserrat"/></w:rPr></w:style>' +
        (& $style 'Title' 'Title' 'paragraph' '<w:rPr><w:sz w:val="72"/></w:rPr>') +
        (& $style 'Subtitle' 'Subtitle' 'paragraph' '<w:rPr><w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/></w:rPr>') +
        (-join @(1..6 | ForEach-Object { & $style "Heading$_" "heading $_" 'paragraph' "<w:pPr><w:outlineLvl w:val=`"$($_ - 1)`"/></w:pPr>" })) +
        (& $style 'ListParagraph' 'List Paragraph' 'paragraph' '<w:pPr><w:ind w:left="720"/></w:pPr>') +
        (& $style 'TOCHeading' 'TOC Heading' 'paragraph' '<w:rPr><w:rFonts w:ascii="Lato" w:hAnsi="Lato"/></w:rPr>') +
        (& $style 'TOC1' 'toc 1' 'paragraph' '') +
        '<w:style w:type="character" w:styleId="Hyperlink"><w:name w:val="Hyperlink"/><w:rPr><w:u w:val="single"/></w:rPr></w:style>' +
        '<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4"/></w:tblBorders></w:tblPr></w:style>' +
        '</w:styles>'
    $body = '<w:p><w:pPr><w:jc w:val="center"/></w:pPr>' + (& $pic 'rId20' 'Cover art') + '</w:p>' +
        '<w:p><w:r><w:t>DOCUMENT TITLE</w:t></w:r></w:p>' +
        '<w:p><w:pPr><w:pStyle w:val="TOCHeading"/></w:pPr><w:r><w:t>Table of contents</w:t></w:r></w:p>' +
        '<w:p><w:pPr><w:pStyle w:val="TOC1"/></w:pPr><w:r><w:fldChar w:fldCharType="begin"/></w:r><w:r><w:instrText xml:space="preserve"> TOC \o "1-3" \h \z \u </w:instrText></w:r><w:r><w:fldChar w:fldCharType="separate"/></w:r><w:r><w:t>Title section</w:t></w:r><w:r><w:fldChar w:fldCharType="end"/></w:r></w:p>' +
        '<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Title section</w:t></w:r></w:p>' +
        '<w:p><w:r><w:t>Text section</w:t></w:r></w:p>' +
        '<w:p><w:pPr><w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Bulletted text</w:t></w:r></w:p>' +
        '<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/></w:tblPr><w:tblGrid><w:gridCol w:w="4000"/></w:tblGrid><w:tr><w:tc><w:p><w:r><w:t>Column value 1</w:t></w:r></w:p></w:tc></w:tr></w:tbl>' +
        '<w:p><w:hyperlink r:id="rId21"><w:r><w:t>Sample link</w:t></w:r></w:hyperlink></w:p>'
    $sect = '<w:sectPr><w:headerReference w:type="default" r:id="rId10"/><w:footerReference w:type="default" r:id="rId11"/><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="2269" w:right="1558" w:bottom="1418" w:left="1418" w:header="720" w:footer="720" w:gutter="0"/><w:titlePg/></w:sectPr>'
    New-Package $Path @{
        '[Content_Types].xml' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="png" ContentType="image/png"/><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/><Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/><Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/><Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/></Types>'
        '_rels/.rels' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/></Relationships>'
        'docProps/core.xml' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>DOCUMENT TITLE</dc:title></cp:coreProperties>'
        'word/document.xml' = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:document $w $wp><w:body>$body$sect</w:body></w:document>"
        'word/_rels/document.xml.rels' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable" Target="fontTable.xml"/><Relationship Id="rId10" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/><Relationship Id="rId11" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/><Relationship Id="rId20" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/cover.png"/><Relationship Id="rId21" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" Target="https://example.com/sample" TargetMode="External"/></Relationships>'
        'word/styles.xml' = $styles
        'word/numbering.xml' = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:numbering $w><w:abstractNum w:abstractNumId=`"0`"><w:lvl w:ilvl=`"0`"><w:numFmt w:val=`"bullet`"/><w:lvlText w:val=`"-`"/></w:lvl></w:abstractNum><w:num w:numId=`"1`"><w:abstractNumId w:val=`"0`"/></w:num></w:numbering>"
        'word/fontTable.xml' = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:fonts $w><w:font w:name=`"Montserrat`"/><w:font w:name=`"Georgia`"/><w:font w:name=`"Lato`"/><w:font w:name=`"LazySpec Missing Font`"/></w:fonts>"
        'word/header1.xml' = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:hdr $w $wp><w:p>$(& $pic 'rId1' 'Logo')<w:r><w:t>$Marker</w:t></w:r></w:p></w:hdr>"
        'word/_rels/header1.xml.rels' = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/logo.png"/></Relationships>'
        'word/footer1.xml' = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><w:ftr $w><w:p><w:r><w:fldChar w:fldCharType=`"begin`"/></w:r><w:r><w:instrText> PAGE </w:instrText></w:r><w:r><w:fldChar w:fldCharType=`"end`"/></w:r></w:p></w:ftr>"
        'word/media/logo.png' = (Get-Png 60 20 'Red')
        'word/media/cover.png' = (Get-Png 200 100 'Blue')
    }
}
# A PDF's text with its compressed streams opened (Chrome packs its objects into them).
function Get-PdfText([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    $latin = [Text.Encoding]::GetEncoding(28591)
    $raw = $latin.GetString($bytes)
    $sb = New-Object Text.StringBuilder
    [void]$sb.Append($raw)
    foreach ($m in [regex]::Matches($raw, '/FlateDecode[^>]*>>\s*stream\r?\n')) {
        $start = $m.Index + $m.Length
        $end = $raw.IndexOf('endstream', $start)
        if ($end -lt 0) { continue }
        try {
            $ms = New-Object IO.MemoryStream($bytes, $start + 2, $end - $start - 2)
            $z = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress)
            $out = New-Object IO.MemoryStream
            $z.CopyTo($out)
            [void]$sb.Append($latin.GetString($out.ToArray()))
        } catch { }
    }
    return $sb.ToString()
}

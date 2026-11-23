# Usage: powershell -NoProfile -File word-finish.ps1 [-Pdf] <file.docx> [<file.docx> ...]
#
# Lets Word finish documents written by netmedia_document.py: it updates the table of contents (entries, dot leaders,
# page numbers) and saves the file, and with -Pdf it also exports <file>.pdf next to it. python-docx cannot lay out
# pages, so without Word the table of contents needs one F9 in Word.
param(
    [switch] $Pdf,
    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]] $Paths
)

$ErrorActionPreference = 'Stop'
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    foreach ($path in $Paths) {
        $full = (Resolve-Path -LiteralPath $path).Path
        $document = $word.Documents.Open($full, $false, $false, $false)
        try {
            foreach ($toc in $document.TablesOfContents) { $toc.Update() }
            $document.Save()
            $line = "toc updated: {0} ({1} pages)" -f (Split-Path $full -Leaf), $document.ComputeStatistics(2)
            if ($Pdf) {
                $pdfPath = [System.IO.Path]::ChangeExtension($full, '.pdf')
                $document.ExportAsFixedFormat($pdfPath, 17)   # wdExportFormatPDF
                $line += "; pdf: $pdfPath"
            }
            Write-Output $line
        }
        finally {
            $document.Close($false)
        }
    }
}
finally {
    $word.Quit()
    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($word)
}

# LazySpec developer guide: Word fills the contents' page numbers, saves the .docx and, with -Pdf, writes
# a PDF to look at. Used after build-docx.js (see README.md here).
param([Parameter(Mandatory = $true)][string]$Docx, [string]$Pdf)
$Docx = (Resolve-Path -LiteralPath $Docx).Path
if ($Pdf) { $Pdf = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Pdf)) }
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0
try {
    $doc = $word.Documents.Open($Docx, $false, $false)
    foreach ($t in $doc.TablesOfContents) { $t.Update() }
    $doc.Fields.Update() | Out-Null
    $doc.Save()
    if ($Pdf) { $doc.SaveAs2($Pdf, 17) }
    "pages: $($doc.ComputeStatistics(2))"
    $doc.Close($false)
}
finally {
    $word.Quit()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($word)
}

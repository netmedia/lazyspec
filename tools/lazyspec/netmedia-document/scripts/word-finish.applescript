-- Usage: osascript word-finish.applescript [pdf] <file.docx> [<file.docx> ...]
--
-- The macOS counterpart of word-finish.ps1: Word for Mac updates the table of contents (entries, page numbers) of
-- documents written by netmedia_document.py and saves them; with "pdf" it also saves <file>.pdf next to each.
-- Word may ask once to grant access to the folder (Word for Mac is sandboxed). Paths are absolute POSIX paths.
on run argv
	set makePdf to false
	set docPaths to {}
	repeat with arg in argv
		if (arg as text) is "pdf" then
			set makePdf to true
		else
			set end of docPaths to (arg as text)
		end if
	end repeat
	set report to {}
	tell application "Microsoft Word"
		repeat with docPath in docPaths
			open (POSIX file (docPath as text))
			set theDoc to active document
			repeat with i from 1 to (count of tables of contents of theDoc)
				update (table of contents i of theDoc)
			end repeat
			save theDoc
			set line_ to "toc updated: " & (docPath as text)
			if makePdf then
				set pdfPath to (text 1 thru -6 of (docPath as text)) & ".pdf"
				save as theDoc file name pdfPath file format format PDF
				set line_ to line_ & "; pdf: " & pdfPath
			end if
			close theDoc saving no
			set end of report to line_
		end repeat
	end tell
	set AppleScript's text item delimiters to linefeed
	return report as text
end run

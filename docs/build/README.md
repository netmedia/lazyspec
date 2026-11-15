# Building the developer guide as Word

`docs/developer-guide.md` is the source; `docs/developer-guide.docx` is made from it (cover, contents,
every diagram and screenshot from `docs/images/`, tables, code). After changing the Markdown:

```
cd docs\build
npm install                       # once: docx, marked
node build-docx.js                # writes ..\developer-guide.docx
powershell -File update-fields.ps1 -Docx ..\developer-guide.docx [-Pdf ..\developer-guide.pdf]
```

`update-fields.ps1` opens the document in Microsoft Word, fills in the contents' page numbers and saves it
(optionally also as PDF, to check it). Without Word the contents fill in when the document is first opened
(Word asks to update its fields).

Relative links in the guide (`../tools/lazyspec/LAZYSPEC.md`) become links to the repository on GitHub
(`develop`).

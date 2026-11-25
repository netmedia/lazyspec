# LazySpec

## Documents

LazySpec's Word and PDF documents (Developer Guide, Reference, README) are built from their Markdown sources with
the netmedia-document plugin, as `docs/documents.json` lists them: run `docs/build-documents.ps1`. A changed document
gets a history entry in `docs/documents.json`; its version comes from `vscode/package.json`.

Every rebuilt document that is company knowledge also goes to the Knowledge Base with its Markdown sources and images
(DP 5.8, netmedia-document:knowledge-base); its commands come after this repository's.

"""Netmedia document: Markdown or HTML -> Word (and PDF) in the Netmedia document template.

Usage:
  python netmedia_document.py <document.md|.html> [-o <out.docx>] [--pdf] [--title T] [--subtitle S] [--version V]
                              [--date "November 2026"] [--author A] [--cover "Client: Acme"] [--language hr]
                              [--template <copy.docx>] [--no-toc] [--no-history] [--hyperlinks]
  python netmedia_document.py --documents docs/documents.json [--only <name> ...] [--pdf]   # a repository's documents
  python netmedia_document.py --theme-dir <dir>    # copy the template, the theme (YAML), fonts and logo into <dir>

The look comes from the plugin's theme/: "Document template.docx" (Word styles, cover, header logo, footer; --template
or NETMEDIA_DOCUMENT_TEMPLATE: a project's copy of it) and document-theme.yaml (the same look for HTML tools such as
LazySpec's HTML export). An HTML source (a tool's export, LazySpec's Word and PDF) goes through html_source.py: its
own cover becomes the metadata. --documents builds what a documents.json lists (build_documents). The source is
Markdown with an optional YAML front matter:

  ---
  title: LazyBicep                 # the cover title (else the first "# " heading)
  subtitle: Developer guide         # under the title on the cover
  version: "1.2"                   # else the last history entry's version
  date: November 2026              # else the current month
  author: Netmedia
  toc: true                        # table of contents of the "## " headings
  language: en                     # en, hr, de, nl: the contents' and history's titles
  cover: ["Client: Acme"]          # more lines on the cover
  history:                         # the "Document history" table at the end; a 4th value is that row's author
    - [16.11.2026, "1.0", First version]
  ---

Markdown: "## " -> Heading 1, "### " -> Heading 2 ... "###### " -> Heading 5 (the "# " title is the cover), paragraphs,
**bold**, *italic*, ~~strikethrough~~, `code`, links, lists (nested), tables, fenced code, quotes and images (![caption](path), relative
to the Markdown file). On Windows with Word installed, Word fills in the table of contents and, with --pdf, exports
the PDF; elsewhere open the document once and press F9 on the table of contents.
"""
import argparse
import datetime
import re
import subprocess
import sys
from pathlib import Path

try:
    import docx
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn
except ImportError:
    sys.exit("Netmedia documents need python-docx. Install it once with:\n"
             f"  {Path(sys.executable).name} -m pip install python-docx")

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import docx_render  # noqa: E402
from docx_render import render_markdown  # noqa: E402
from docx_tools import check, clean_clone, remove_update_fields, toc_field_paragraphs  # noqa: E402

TEMPLATE_DIR = HERE.parent / "theme"
TEMPLATE = TEMPLATE_DIR / "Document template.docx"
# The words the generator writes itself, in the document's language (front matter "language", default en).
LABELS = {
    "en": {"toc": "Table of contents", "history": "Document history", "version": "Version",
           "columns": ("Date", "Author", "Version", "Change")},
    "hr": {"toc": "Sadržaj", "history": "Povijest dokumenta", "version": "Verzija",
           "columns": ("Datum", "Autor", "Verzija", "Promjena")},
    "de": {"toc": "Inhalt", "history": "Dokumenthistorie", "version": "Version",
           "columns": ("Datum", "Autor", "Version", "Änderung")},
    "nl": {"toc": "Inhoud", "history": "Documentgeschiedenis", "version": "Versie",
           "columns": ("Datum", "Auteur", "Versie", "Wijziging")},
}


def template_path(template=None):
    """The Word template: the given one, NETMEDIA_DOCUMENT_TEMPLATE, else the plugin's own (the latest Netmedia
    template). An overriding template is a copy of the Netmedia template: it keeps the cover's "DOCUMENT TITLE"
    paragraph and the "Table of contents" title, which the generator fills in."""
    import os
    chosen = template or os.environ.get("NETMEDIA_DOCUMENT_TEMPLATE")
    if chosen:
        chosen = Path(chosen)
        if chosen.is_dir():
            chosen = chosen / "Document template.docx"
        if not chosen.exists():
            sys.exit(f"The Word template is not there: {chosen}")
        return chosen
    return TEMPLATE


def labels(meta):
    return LABELS.get(str(meta.get("language") or "en").lower()[:2], LABELS["en"])
MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
          "November", "December"]


def front_matter(text):
    """(metadata, body): the YAML block between leading '---' lines, if any."""
    match = re.match(r"^---\r?\n(.*?)\r?\n---\r?\n", text, re.DOTALL)
    if not match:
        return {}, text
    try:
        import yaml
        return yaml.safe_load(match.group(1)) or {}, text[match.end():]
    except ImportError:
        return _simple_yaml(match.group(1)), text[match.end():]


def _simple_yaml(block):
    """The front matter without PyYAML: `key: value` lines and a `history:` list of `- [date, version, change]`."""
    meta, current = {}, None
    unquote = lambda s: s.strip().strip('"').strip("'")  # noqa: E731
    for line in block.splitlines():
        line = re.sub(r"\s+#.*$", "", line)
        if not line.strip():
            continue
        item = re.match(r"^\s+-\s*\[(.*)\]\s*$", line)
        if item and current:
            parts = [unquote(p) for p in re.findall(r'"[^"]*"|\'[^\']*\'|[^,]+', item.group(1))]
            meta[current].append(parts[:2] + [", ".join(parts[2:])])
            continue
        pair = re.match(r"^([A-Za-z]+):\s*(.*)$", line)
        if pair:
            key, value = pair.group(1), unquote(pair.group(2))
            current = key if value == "" else None
            meta[key] = [] if value == "" else {"true": True, "false": False}.get(value.lower(), value)
    return meta


def _run(text, color=None, size=None, page_break=False, line_break=False):
    r = OxmlElement("w:r")
    props = OxmlElement("w:rPr")
    if color:
        c = OxmlElement("w:color")
        c.set(qn("w:val"), color)
        props.append(c)
    if size:
        for tag in ("w:sz", "w:szCs"):
            s = OxmlElement(tag)
            s.set(qn("w:val"), str(size))
            props.append(s)
    r.append(props)
    if line_break:
        r.append(OxmlElement("w:br"))
    if text:
        t = OxmlElement("w:t")
        t.set("{http://www.w3.org/XML/1998/namespace}space", "preserve")
        t.text = text
        r.append(t)
    if page_break:
        br = OxmlElement("w:br")
        br.set(qn("w:type"), "page")
        r.append(br)
    return r


def build(source, out, meta, toc=True, history=True, hyperlinks=False, template=None):
    words = labels(meta)
    document = docx.Document(template_path(template))
    body = document.element.body
    paragraphs = document.paragraphs

    # Cover: the template's "DOCUMENT TITLE" paragraph keeps its page break; the subtitle line goes above the break.
    # A copy of the template (a project's own) needs that paragraph and the "Table of contents" title.
    cover = next((p for p in paragraphs[:30] if p.text.strip() == "DOCUMENT TITLE"), None)
    if cover is None:
        sys.exit(f"The Word template has no \"DOCUMENT TITLE\" paragraph on its cover ({template_path(template)}): "
                 "use a copy of the Netmedia template (netmedia-document's theme/Document template.docx).")
    texts = list(cover._p.iter(qn("w:t")))
    texts[0].text = meta["title"].upper()
    for t in texts[1:]:
        t.getparent().remove(t)
    page_break_run = next((r for r in cover._p.iter(qn("w:r")) if r.find(qn("w:br")) is not None
                           and r.find(qn("w:br")).get(qn("w:type")) == "page"), None)
    if page_break_run is None:                      # a copy without the cover's page break: one is added
        page_break_run = _run("", page_break=True)
        cover._p.append(page_break_run)
    line = " · ".join(x for x in [meta.get("subtitle"),
                                   f"{words['version']} {meta['version']}" if meta.get("version") else None,
                                   meta["date"]] if x)
    page_break_run.addprevious(_run(line, color="595959", size=24, line_break=True))
    # More cover lines (front matter "cover", or an HTML source's own cover: "Client: Acme", "Scope: ...").
    for extra in meta.get("cover") or []:
        page_break_run.addprevious(_run(str(extra), color="7F7F7F", size=20, line_break=True))

    # Everything after the "Table of contents" title is the template's sample content: removed.
    is_toc = lambda p: p.style.name.lower().startswith("toc")  # noqa: E731 - "toc 1", "TOC Heading"
    toc_title = next((p for p in paragraphs if p.text.strip() == "Table of contents" and is_toc(p)), None) or         next((p for p in paragraphs if p.text.strip() == "Table of contents"), None)
    if toc_title is None:
        sys.exit(f"The Word template has no \"Table of contents\" title ({template_path(template)}): "
                 "use a copy of the Netmedia template (netmedia-document's theme/Document template.docx).")
    if words["toc"] != "Table of contents":
        toc_texts = list(toc_title._p.iter(qn("w:t")))
        toc_texts[0].text = words["toc"]
        for t in toc_texts[1:]:
            t.text = ""
    entry = next((p for p in paragraphs if is_toc(p) and p._p is not toc_title._p
                  and p.text.strip() != "Table of contents"), None)
    toc_entry = clean_clone((entry or toc_title)._p)
    children = list(body.iterchildren())
    for child in children[children.index(toc_title._p) + 1:]:
        if child.tag != qn("w:sectPr"):
            body.remove(child)
    anchor = OxmlElement("w:p")
    toc_title._p.addnext(anchor)
    if not toc:
        body.remove(toc_title._p)

    docx_render.HYPERLINKS = hyperlinks
    render_markdown(document, meta["body"], base_dir=source.parent)

    rows = meta.get("history") or []
    if history and rows:
        document.add_paragraph(words["history"], style="Heading 1")
        lines = ["| " + " | ".join(words["columns"]) + " |", "|---|---|---|---|"]
        for row in rows:
            date, version, change, author = (list(row) + ["", "", "", ""])[:4]
            lines.append(f"| {date} | {author or meta['author']} | {version} | {str(change).replace('|', '/')} |")
        docx_render.add_table(document, lines)

    if toc:
        headings = [p.text for p in document.paragraphs if p.style.name == "Heading 1" and p.text.strip()]
        from docx.text.paragraph import Paragraph
        last = anchor
        for element in toc_field_paragraphs(Paragraph(toc_entry, document._body), headings):
            last.addnext(element)   # the last one closes the field and breaks the page
            last = element
    body.remove(anchor)

    # The empty paragraph Word needs after a closing table: 1 pt and no spacing, so it never makes a page of its own.
    last = [c for c in body.iterchildren() if c.tag != qn("w:sectPr")]
    if last and last[-1].tag == qn("w:p") and not "".join(last[-1].itertext()).strip() and len(last) > 1 \
            and last[-2].tag == qn("w:tbl"):
        from docx.text.paragraph import Paragraph
        tail = Paragraph(last[-1], document._body)
        tail.paragraph_format.space_before = tail.paragraph_format.space_after = docx.shared.Pt(0)
        tail.paragraph_format.line_spacing = docx.shared.Pt(1)
        mark = tail._p.get_or_add_pPr().get_or_add_rPr() if hasattr(tail._p.get_or_add_pPr(), "get_or_add_rPr") else None
        if mark is not None:
            for tag in ("w:sz", "w:szCs"):
                size = OxmlElement(tag)
                size.set(qn("w:val"), "2")
                mark.append(size)

    remove_update_fields(document)
    props = document.core_properties
    props.title = meta["title"]
    props.subject = meta.get("subtitle") or ""
    props.author = meta["author"]
    document.save(out)
    problems = check(docx.Document(out))
    if problems:
        sys.exit(f"written {out}, but it has problems: {', '.join(problems)}")
    return out


def word(paths, pdf):
    """Word fills in the table of contents and exports the PDF: Windows (word-finish.ps1) and macOS
    (word-finish.applescript), with Word installed."""
    if sys.platform == "win32":
        args = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(HERE / "word-finish.ps1")]
        args += ["-Pdf"] if pdf else []
    elif sys.platform == "darwin":
        args = ["osascript", str(HERE / "word-finish.applescript")] + (["pdf"] if pdf else [])
    else:
        return False
    try:
        result = subprocess.run(args + [str(Path(p).resolve()) for p in paths], capture_output=True, text=True)
    except FileNotFoundError as error:
        print(f"Word was not available ({error}): open the document, click the table of contents and press F9; "
              "export the PDF from Word.")
        return False
    print(result.stdout.strip())
    if result.returncode != 0:
        print(f"Word was not available ({result.stderr.strip()[:200]}): open the document, click the table of "
              "contents and press F9; export the PDF from Word.")
        return False
    return True


def read_source(source):
    """(metadata, Markdown) of a source: Markdown with its front matter, or HTML (html_source: its own cover becomes
    the metadata; data: pictures are written next to a temporary copy)."""
    source = Path(source)
    text = source.read_text(encoding="utf-8")
    if source.suffix.lower() not in (".html", ".htm"):
        return front_matter(text)
    import tempfile
    from html_source import html_to_markdown
    work = Path(tempfile.mkdtemp(prefix="netmedia-document-"))
    meta, body, notes = html_to_markdown(text, source.parent, work)
    for note in notes:
        print(f"  ! {note}")
    lang = re.search(r'(?is)<html[^>]*\blang="([a-zA-Z-]+)"', text)
    if lang:
        meta.setdefault("language", lang.group(1))
    return meta, body


def metadata(source, title=None, subtitle=None, version=None, date=None, author=None, history=None, extra=None):
    """The document's metadata: the source's front matter (or HTML cover), then extra (a documents.json entry or a
    --meta file), then the given values; "body" is the text."""
    meta, body = read_source(source)
    meta = {**meta, **{k: v for k, v in (extra or {}).items() if v is not None}}
    heading = re.search(r"^#\s+(.+)$", body, re.MULTILINE)
    today = datetime.date.today()
    rows = history if history is not None else (meta.get("history") or [])
    return {
        **meta,
        "body": body,
        "history": rows,
        "title": title or meta.get("title") or (heading.group(1).strip() if heading else Path(source).stem),
        "subtitle": subtitle or meta.get("subtitle"),
        "version": str(version or meta.get("version") or (rows[-1][1] if rows else "")) or None,
        "date": date or meta.get("date") or f"{MONTHS[today.month - 1]} {today.year}",
        "author": author or meta.get("author") or "Netmedia",
    }


def _chapter(text, base_dir, chapter=None, shift=False):
    """One source of a combined document: its pictures with absolute paths; with a chapter name, its "# " title
    becomes that Heading 1 and its own headings move one level down; with shift, every heading moves one level down
    (a source whose "# " headings are chapters)."""
    _, text = front_matter(text)
    text = re.sub(r"^(\s*!\[[^\]]*\]\()([^)\s]+)\)",
                  lambda m: m.group(1) + (m.group(2) if re.match(r"^[a-z]+:", m.group(2)) or Path(m.group(2)).is_absolute()
                                          else (base_dir / m.group(2)).resolve().as_posix()) + ")",
                  text, flags=re.MULTILINE)
    if chapter is None and not shift:
        return text
    lines, fence, titled = [], False, chapter is None
    for line in text.splitlines():
        if line.strip().startswith("```"):
            fence = not fence
        heading = None if fence else re.match(r"^(#{1,6})\s+(.*)$", line)
        if heading and len(heading.group(1)) == 1 and not titled:
            lines.append(f"## {chapter}")
            titled = True
        elif heading:
            lines.append("#" * min(len(heading.group(1)) + 1, 6) + " " + heading.group(2))
        else:
            lines.append(line)
    if not titled:
        lines.insert(0, f"## {chapter}\n")
    return "\n".join(lines)


def _value(value, base_dir):
    """A documents.json value, or {"file": "<json>", "key": "a.b"}: read from a JSON file (a product's version)."""
    if isinstance(value, dict) and "file" in value:
        import json
        data = json.loads((base_dir / value["file"]).read_text(encoding="utf-8"))
        for key in str(value.get("key", "version")).split("."):
            data = data[key]
        return str(data)
    return value


def build_documents(listing, pdf=False, only=None, template=None, finish=True):
    """Builds every document of a documents.json (paths relative to it):

    {"author": "Netmedia", "language": "en",            <- defaults for every document
     "documents": [
       {"out": "LazyBicep-Developer-Guide.docx", "source": "DEVELOPER-GUIDE.md",
        "title": "LazyBicep", "subtitle": "Developer Guide", "version": {"file": "../infra/kit.json", "key": "version"},
        "pdf": true, "history": [["23.11.2026", "0.2.1", "Built with netmedia-document"]]},
       {"out": "SharpTracks - Architecture and Workflows.docx",
        "sources": ["word/workflows.md", {"path": "ARCHITECTURE.md", "chapter": "Architecture tour"}], ...}]}

    A source given as a string keeps its headings ("# " is the cover's title, "## " a chapter); with "chapter" its
    "# " title becomes that chapter and its headings move one level down. Other keys: date, cover (more cover
    lines), toc, history, hyperlinks, template. A source {"path": ..., "shift": true} moves all its headings one level
    down (its "# " headings are chapters). "prepare": commands run first in this folder, e.g.
    [["{python}", "word/diagrams.py", "word/img"]] ("{python}" is this Python). Returns the written files."""
    import json
    listing = Path(listing).resolve()
    base = listing.parent
    spec = json.loads(listing.read_text(encoding="utf-8"))
    defaults = {k: v for k, v in spec.items() if k not in ("documents", "prepare") and not k.startswith("$")}
    # Commands run first in this folder (diagrams drawn by a script); "{python}" is this Python.
    for command in spec.get("prepare") or []:
        print("prepare: " + " ".join(command))
        subprocess.run([sys.executable if a == "{python}" else a for a in command], cwd=base, check=True)
    written, pdfs = [], []
    for entry in spec["documents"]:
        entry = {**defaults, **entry}
        out = (base / entry["out"]).resolve()
        if only and out.stem not in only and entry["out"] not in only:
            continue
        sources = entry.get("sources") or [entry["source"]]
        parts, first = [], None
        for item in sources:
            item = {"path": item} if isinstance(item, str) else item
            path = (base / item["path"]).resolve()
            first = first or path
            parts.append(_chapter(path.read_text(encoding="utf-8"), path.parent, item.get("chapter"),
                                  item.get("shift", False)))
        extra = {k: _value(v, base) for k, v in entry.items()
                 if k not in ("out", "source", "sources", "pdf", "hyperlinks", "template")}
        meta = metadata(first, extra=extra)
        if len(parts) > 1:
            meta["body"] = "\n\n".join(parts)
        out.parent.mkdir(parents=True, exist_ok=True)
        build(first, out, meta, toc=entry.get("toc", True), history=bool(meta.get("history")),
              hyperlinks=entry.get("hyperlinks", False),
              template=(base / entry["template"]) if entry.get("template") else template)
        print(f"written {out}")
        written.append(out)
        if pdf or entry.get("pdf"):
            pdfs.append(out)
    if finish:
        rest = [p for p in written if p not in pdfs]
        if rest:
            word(rest, False)
        if pdfs:
            word(pdfs, True)
    return written


def main():
    parser = argparse.ArgumentParser(description="Markdown or HTML -> Netmedia Word document (and PDF).")
    parser.add_argument("source", nargs="?", help="a Markdown (.md) or HTML (.html) file")
    parser.add_argument("--documents", help="build every document a documents.json lists (docs/documents.json)")
    parser.add_argument("--only", nargs="*", help="with --documents: only these (output names, with or without .docx)")
    parser.add_argument("--template", help="another Word template (a copy of the Netmedia one), or its folder; "
                                           "default NETMEDIA_DOCUMENT_TEMPLATE, else the plugin's own")
    parser.add_argument("--language", help="en, hr, de or nl: the contents' and history's titles (default: the "
                                           "front matter's, an HTML source's lang, else en)")
    parser.add_argument("--cover", action="append", help="one more cover line (repeatable), e.g. \"Client: Acme\"")
    parser.add_argument("-o", "--out")
    parser.add_argument("--pdf", action="store_true")
    parser.add_argument("--title")
    parser.add_argument("--subtitle")
    parser.add_argument("--version")
    parser.add_argument("--date")
    parser.add_argument("--author")
    parser.add_argument("--no-toc", action="store_true")
    parser.add_argument("--no-history", action="store_true")
    parser.add_argument("--hyperlinks", action="store_true", help="links as Word hyperlinks (default: text only)")
    parser.add_argument("--theme-dir", help="copy the template, document-theme.yaml, fonts and logo into this folder")
    args = parser.parse_args()

    if args.theme_dir:
        import theme
        written, kept = theme.copy(Path(args.theme_dir), update=False)
        print(f"theme -> {args.theme_dir}: {len(written)} written, {len(kept)} kept")
        return
    if args.documents:
        build_documents(args.documents, pdf=args.pdf, only=args.only, template=args.template)
        return
    if not args.source:
        parser.error("a Markdown or HTML file is required (or --documents, --theme-dir)")

    source = Path(args.source).resolve()
    meta = metadata(source, title=args.title, subtitle=args.subtitle, version=args.version, date=args.date,
                    author=args.author, extra={"language": args.language, "cover": args.cover})
    out = Path(args.out).resolve() if args.out else source.with_suffix(".docx")
    build(source, out, meta, toc=not args.no_toc and meta.get("toc", True), history=not args.no_history,
          hyperlinks=args.hyperlinks, template=args.template)
    print(f"written {out}")
    word([out], args.pdf)


if __name__ == "__main__":
    main()

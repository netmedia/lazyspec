"""HTML -> the Markdown netmedia_document renders: a tool that writes HTML (LazySpec's spec exports) gets the same
Netmedia document as a Markdown source - the template's cover, contents, headings, tables and history.

html_to_markdown(html, base_dir, work_dir) -> (meta, markdown)

- The body's own cover (`div.cover`: `p.title`, `p.subtitle`, `p.meta` lines) becomes metadata (title, subtitle,
  cover lines) - the template draws the cover. Its own contents (`p.toc-title`, `div.toc`, `ul.toc-list`,
  `p.toc-scn`) are left out: the template's table of contents replaces them.
- h1..h6 -> "##".."#######" (h1 is a chapter: Heading 1; h6 stays Heading 5), with a heading's `span.tag`
  ("Requirement", "Scenario") as "Requirement: <name>".
- p, ul/ol/li (nested), table (thead/tbody), pre, blockquote and `div.scenario` (a quote), img with the caption of
  its `div.diagram` (`p.caption`); strong/b, em/i, code, del/s, br inline; links become text.
- Pictures: files, file: URIs and data: URIs (written into work_dir); an SVG is rendered to PNG with
  render_images.py (Edge or Chrome), else left out with a note.
"""
import base64
import html as htmllib
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlparse

VOID = {"br", "img", "hr", "meta", "col", "input", "link", "source", "wbr"}
SKIP_TAGS = {"head", "script", "style", "colgroup", "template", "svg", "nav"}
SKIP_CLASSES = {"toc-title", "toc", "toc-list", "toc-scn", "bar"}


class Node:
    def __init__(self, tag, attrs=None, parent=None):
        self.tag, self.attrs, self.parent, self.children = tag, dict(attrs or {}), parent, []

    @property
    def classes(self):
        return set((self.attrs.get("class") or "").split())

    def text(self):
        return "".join(c if isinstance(c, str) else c.text() for c in self.children)

    def find(self, tag=None, cls=None):
        for c in self.children:
            if isinstance(c, Node):
                if (tag is None or c.tag == tag) and (cls is None or cls in c.classes):
                    return c
                hit = c.find(tag, cls)
                if hit:
                    return hit
        return None


class _Parser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.root = Node("root")
        self.cur = self.root

    def handle_starttag(self, tag, attrs):
        node = Node(tag, attrs, self.cur)
        self.cur.children.append(node)
        if tag not in VOID:
            self.cur = node

    def handle_startendtag(self, tag, attrs):
        self.cur.children.append(Node(tag, attrs, self.cur))

    def handle_endtag(self, tag):
        node = self.cur
        while node is not self.root and node.tag != tag:
            node = node.parent
        if node is not self.root:
            self.cur = node.parent

    def handle_data(self, data):
        self.cur.children.append(data)


def parse(html):
    parser = _Parser()
    body = re.search(r"(?is)<body[^>]*>(.*)</body>", html)
    parser.feed(body.group(1) if body else html)
    parser.close()
    return parser.root


def _space(text):
    return re.sub(r"\s+", " ", text)


def inline(node, in_code=False):
    """A node's content as one line of inline Markdown."""
    out = []
    for c in node.children:
        if isinstance(c, str):
            out.append(c if in_code else _space(c))
            continue
        if c.tag in SKIP_TAGS or c.classes & SKIP_CLASSES:
            continue
        if c.tag == "br":
            out.append("<br>")
        elif c.tag in ("strong", "b"):
            text = inline(c).strip()
            out.append(f"**{text}**" if text else "")
        elif c.tag in ("em", "i"):
            text = inline(c).strip()
            out.append(f"*{text}*" if text else "")
        elif c.tag in ("del", "s", "strike"):
            text = inline(c).strip()
            out.append(f"~~{text}~~" if text else "")
        elif c.tag == "code":
            text = c.text().replace("`", "'")
            out.append(f"`{text}`" if text.strip() else "")
        elif c.tag == "img":
            continue
        elif c.tag == "span" and "tag" in c.classes:
            out.append(inline(c).strip() + ": ")
        else:
            out.append(inline(c, in_code))
    return "".join(out)


def _clean(text):
    text = re.sub(r"[ \t]+", " ", text).strip()
    return re.sub(r":\s*:", ":", text)


class Converter:
    def __init__(self, base_dir, work_dir):
        self.base_dir = Path(base_dir)
        self.work_dir = Path(work_dir)
        self.lines = []
        self.meta = {}
        self.images = 0
        self.notes = []

    def emit(self, *lines):
        self.lines.extend(lines)

    def blank(self):
        if self.lines and self.lines[-1] != "":
            self.lines.append("")

    def block(self, node, depth=0):
        for c in node.children:
            if isinstance(c, str):
                text = _space(c).strip()
                if text:
                    self.blank()
                    self.emit(text)
                continue
            self.element(c, depth)

    def element(self, n, depth):
        tag, cls = n.tag, n.classes
        if tag in SKIP_TAGS or cls & SKIP_CLASSES:
            return
        if "cover" in cls:
            self.cover(n)
            return
        if re.fullmatch(r"h[1-6]", tag):
            if self._next(n) is not None and self._next(n).classes & {"toc-list", "toc"}:
                return                        # the title of a list of links the template's contents replace
            text =re.sub(r"\*\*|`|~~|(?<!\w)\*|\*(?!\w)", "", _clean(inline(n)))   # a heading is plain text
            if text:
                self.blank()
                self.emit("#" * (min(int(tag[1]), 5) + 1) + " " + text)
                self.blank()
            return
        if tag == "p":
            if "caption" in cls:
                return                        # with its picture
            text = _clean(inline(n))
            if text == "[[TOC]]":
                return                        # a contents placeholder: the template has its own
            if not text:
                for img in self._images(n):
                    self.image(img, "")
                return
            self.blank()
            self.emit(("> " if self._in_quote(n) else "") + text)
            self.blank()
            return
        if tag in ("ul", "ol"):
            self.blank()
            self.listing(n, 0)
            self.blank()
            return
        if tag == "table":
            self.table(n)
            return
        if tag == "pre":
            self.blank()
            self.emit("```", *n.text().rstrip("\n").split("\n"), "```")
            self.blank()
            return
        if tag == "img":
            self.image(n, n.attrs.get("alt") or "")
            return
        if tag == "div" and "diagram" in cls:
            img = n.find("img")
            caption = n.find("p", "caption")
            if img is not None:
                self.image(img, _clean(inline(caption)) if caption else (img.attrs.get("alt") or ""))
            return
        if tag == "hr":
            return
        self.block(n, depth)

    @staticmethod
    def _next(n):
        """The element after n (text between them that is only space skipped)."""
        siblings = n.parent.children if n.parent is not None else []
        for c in siblings[siblings.index(n) + 1:]:
            if isinstance(c, Node):
                return c
            if c.strip():
                return None
        return None

    def _in_quote(self, n):
        node = n.parent
        while node is not None:
            if node.tag == "blockquote" or (node.tag == "div" and "scenario" in node.classes):
                return True
            node = node.parent
        return False

    def _images(self, n):
        found = []
        for c in n.children:
            if isinstance(c, Node):
                found += [c] if c.tag == "img" else self._images(c)
        return found

    def cover(self, n):
        for c in n.children:
            if not isinstance(c, Node):
                continue
            text = _clean(inline(c)).replace("**", "")
            if "title" in c.classes and text:
                self.meta["title"] = text
            elif "subtitle" in c.classes and text:
                self.meta["subtitle"] = text
            elif "meta" in c.classes and "date" in c.classes and text:
                self.meta["date"] = text.split(":", 1)[-1].strip()      # the cover's date line: the cover's date
            elif "meta" in c.classes and text:
                self.meta.setdefault("cover", []).append(text)

    def listing(self, n, level):
        indent = ["", "  ", "      "][min(level, 2)]
        number = 0
        for li in n.children:
            if not isinstance(li, Node) or li.tag != "li":
                continue
            number += 1
            marker = f"{number}." if n.tag == "ol" else "-"
            own = Node("li", li.attrs)
            own.children = [c for c in li.children if not (isinstance(c, Node) and c.tag in ("ul", "ol"))]
            text = _clean(inline(own)).replace("✓", "☑")
            self.emit(f"{indent}{marker} {text}")
            for sub in li.children:
                if isinstance(sub, Node) and sub.tag in ("ul", "ol"):
                    self.listing(sub, level + 1)

    def table(self, n):
        rows = []
        for tr in self._rows(n):
            cells = [_clean(inline(td)).replace("|", "\\|") or " " for td in tr.children
                     if isinstance(td, Node) and td.tag in ("th", "td")]
            if cells:
                rows.append(cells)
        if not rows:
            return
        width = max(len(r) for r in rows)
        rows = [r + [" "] * (width - len(r)) for r in rows]
        self.blank()
        self.emit("| " + " | ".join(rows[0]) + " |", "|" + "---|" * width)
        self.emit(*["| " + " | ".join(r) + " |" for r in rows[1:]])
        self.blank()

    def _rows(self, n):
        out = []
        for c in n.children:
            if isinstance(c, Node):
                out += [c] if c.tag == "tr" else self._rows(c) if c.tag in ("thead", "tbody", "tfoot") else []
        return out

    def image(self, img, caption):
        path = self.picture(img.attrs.get("src") or "")
        if path:
            self.blank()
            self.emit(f"![{caption.replace(']', ')')}]({path.as_posix()})")
            self.blank()

    def picture(self, src):
        """A picture's file (PNG, JPEG, GIF, BMP), or None."""
        self.images += 1
        try:
            if src.startswith("data:"):
                head, data = src.split(",", 1)
                ext = re.match(r"data:image/([a-z0-9.+-]+)", head).group(1).replace("svg+xml", "svg").replace("jpeg", "jpg")
                path = self.work_dir / f"picture-{self.images}.{ext}"
                path.write_bytes(base64.b64decode(data) if ";base64" in head else unquote(data).encode("utf-8"))
            elif src.startswith("file:"):
                parsed = urlparse(src)
                path = Path(unquote(parsed.path.lstrip("/") if re.match(r"^/[A-Za-z]:", parsed.path) else parsed.path))
            elif re.match(r"^[a-z]+://", src):
                self.notes.append(f"a web picture left out: {src}")
                return None
            else:
                path = (self.base_dir / unquote(src)).resolve()
            if not path.exists():
                self.notes.append(f"a picture not found: {path}")
                return None
            if path.suffix.lower() == ".svg":
                return self.svg_to_png(path)
            return path
        except Exception as error:  # noqa: BLE001 - one broken picture never stops the document
            self.notes.append(f"a picture left out ({error})")
            return None

    def svg_to_png(self, svg):
        """An SVG rendered to PNG at twice its size (sharp in Word) with Edge or Chrome."""
        size = re.search(r'<svg[^>]*?\swidth="([\d.]+)"[^>]*?\sheight="([\d.]+)"', svg.read_text(encoding="utf-8"))
        w, h = (float(size.group(1)), float(size.group(2))) if size else (800.0, 500.0)
        page = self.work_dir / f"{svg.stem}-svg.html"
        page.write_text(f'<!doctype html><html><head><meta name="render-size" content="{2 * w:.0f}x{2 * h:.0f}">'
                        f'</head><body style="margin:0;background:#fff"><img src="{svg.resolve().as_uri()}" '
                        f'width="{2 * w:.0f}" height="{2 * h:.0f}" style="display:block"></body></html>',
                        encoding="utf-8")
        try:
            import render_images
            render_images.render(render_images.browser(), page, self.work_dir)
            out = self.work_dir / f"{page.stem}.png"
            return out if out.exists() else None
        except (Exception, SystemExit) as error:  # noqa: BLE001 - no browser: the picture is left out, said
            self.notes.append(f"an SVG picture left out (it needs Edge or Chrome to render: {error})")
            return None


def html_to_markdown(html, base_dir, work_dir):
    converter = Converter(base_dir, work_dir)
    converter.block(parse(html))
    text = "\n".join(converter.lines).strip() + "\n"
    text = re.sub(r"\n{3,}", "\n\n", text)
    title = re.search(r"(?is)<title>(.*?)</title>", html)
    if "title" not in converter.meta and title and title.group(1).strip():
        converter.meta["title"] = htmllib.unescape(title.group(1).strip())
    return converter.meta, text, converter.notes

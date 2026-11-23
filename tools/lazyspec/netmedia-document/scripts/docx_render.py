"""Markdown -> company Word document, on top of a document opened from a convention document as template.

Part of the netmedia-document plugin: used by netmedia_document.py and by AIToolbelt's document builds
(plugins/netmedia/scripts/build-*-docx.py). Supported markdown: headings (## -> Heading 1,
### -> Heading 2 ... ###### -> Heading 5; the # title is skipped), paragraphs, **bold**, *italic*, ~~strikethrough~~, `code`, links (text
only), bullet and numbered lists (nested by indentation), convention rules (- **1.2** ... or with an area prefix, - **SP 1.2** ...), tables, fenced code,
block quotes and images (![caption](path), rendered full width with a numbered caption). Links become text, or Word
hyperlinks when HYPERLINKS is True (relative targets resolve next to the written document)."""
import re
from pathlib import Path
from urllib.parse import quote, unquote

from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.opc.constants import RELATIONSHIP_TYPE
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Emu, Pt, RGBColor
from docx.text.run import Run

RULE_RED = RGBColor(0xFF, 0x30, 0x3C)
CODE_GREY = RGBColor(0x33, 0x33, 0x33)
CAPTION_GREY = RGBColor(0x59, 0x59, 0x59)
LINK_BLUE = "0563C1"
INDENT = Emu(467995)
CODE_SIZE = Emu(107950)

# Set by a generator: render [text](target) as Word hyperlinks instead of plain text.
HYPERLINKS = False

_INLINE = re.compile(r"(~~[^~]+~~|\*\*[^*]+\*\*|`[^`]+`|(?<![\w*])\*[^*\s][^*]*\*(?![\w*]))")
_LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")


def add_hyperlink(paragraph, text, target, base_bold=False):
    """A Word hyperlink; relative file targets stay relative (Word resolves them next to the document)."""
    target = unquote(target)
    if re.match(r"^[a-z]+:", target) is None:
        target = quote(target, safe="/#()")
    r_id = paragraph.part.relate_to(target, RELATIONSHIP_TYPE.HYPERLINK, is_external=True)
    link = OxmlElement("w:hyperlink")
    link.set(qn("r:id"), r_id)
    run = OxmlElement("w:r")
    properties = OxmlElement("w:rPr")
    if base_bold:
        properties.append(OxmlElement("w:b"))
    color = OxmlElement("w:color")
    color.set(qn("w:val"), LINK_BLUE)
    properties.append(color)
    underline = OxmlElement("w:u")
    underline.set(qn("w:val"), "single")
    properties.append(underline)
    run.append(properties)
    t = OxmlElement("w:t")
    t.set("{http://www.w3.org/XML/1998/namespace}space", "preserve")
    t.text = text.replace("**", "").replace("`", "")
    run.append(t)
    link.append(run)
    paragraph._p.append(link)


def add_runs(paragraph, text, base_bold=False):
    """Inline markdown: **bold**, *italic*, `code`, [text](link) -> text, or a hyperlink when HYPERLINKS is set;
    <br> is a line break (as in Markdown table cells)."""
    for index, segment in enumerate(re.split(r"<br\s*/?>", text)):
        if index:
            paragraph.add_run().add_break()
        _add_runs(paragraph, segment, base_bold)


def _add_runs(paragraph, text, base_bold=False):
    if HYPERLINKS:
        parts = _LINK.split(text)
        for index in range(0, len(parts), 3):
            _add_plain_runs(paragraph, parts[index], base_bold)
            if index + 2 < len(parts):
                add_hyperlink(paragraph, parts[index + 1], parts[index + 2], base_bold)
        return
    _add_plain_runs(paragraph, re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text), base_bold)


def _add_plain_runs(paragraph, text, base_bold=False):
    for token in _INLINE.split(text):
        if not token:
            continue
        if token.startswith("~~") and token.endswith("~~") and len(token) > 4:
            run = paragraph.add_run(token[2:-2])
            run.font.strike = True
            run.bold = base_bold or None
        elif token.startswith("**") and token.endswith("**"):
            for sub in re.split(r"(`[^`]+`|~~[^~]+~~)", token[2:-2]):
                if sub.startswith("`"):
                    run = paragraph.add_run(sub[1:-1])
                    run.font.name = "Consolas"
                    run.bold = True
                elif sub.startswith("~~") and sub.endswith("~~") and len(sub) > 4:
                    run = paragraph.add_run(sub[2:-2])
                    run.font.strike = True
                    run.bold = True
                elif sub:
                    paragraph.add_run(sub).bold = True
        elif token.startswith("`") and token.endswith("`"):
            run = paragraph.add_run(token[1:-1])
            run.font.name = "Consolas"
            run.bold = base_bold or None
        elif token.startswith("*") and token.endswith("*") and len(token) > 2:
            run = paragraph.add_run(token[1:-1])
            run.italic = True
            run.bold = base_bold or None
        else:
            run = paragraph.add_run(token)
            run.bold = base_bold or None


def add_paragraph(document, style="Normal"):
    return document.add_paragraph(style=style)


def add_rule(document, number, body):
    paragraph = add_paragraph(document)
    paragraph.paragraph_format.left_indent = INDENT
    paragraph.paragraph_format.first_line_indent = -INDENT
    run = paragraph.add_run(number)
    run.bold = True
    run.font.color.rgb = RULE_RED
    paragraph.add_run("\t")
    add_runs(paragraph, body)


def add_code(document, lines):
    for line in lines:
        paragraph = add_paragraph(document)
        paragraph.paragraph_format.left_indent = INDENT
        paragraph.paragraph_format.space_after = Pt(0)
        paragraph.paragraph_format.space_before = Pt(0)
        run = paragraph.add_run(line if line else " ")
        run.font.name = "Consolas"
        run.font.size = CODE_SIZE
        run.font.color.rgb = CODE_GREY
    document.add_paragraph().paragraph_format.space_after = Pt(2)


def add_table(document, rows):
    cells = [[c.strip() for c in re.split(r"(?<!\\)\|", row.strip().strip("|"))] for row in rows]
    cells = [r for r in cells if not all(re.fullmatch(r":?-{2,}:?", c) for c in r)]
    width = max(len(r) for r in cells)
    table = document.add_table(rows=len(cells), cols=width)
    table.style = "Table Grid"
    table.autofit = False
    for i, row in enumerate(cells):
        for j in range(width):
            cell = table.cell(i, j)
            cell.paragraphs[0].text = ""
            add_runs(cell.paragraphs[0], (row[j] if j < len(row) else "").replace("\\|", "|"), base_bold=(i == 0))
            for element in cell.paragraphs[0]._p.iter(qn("w:r")):    # hyperlink runs included
                Run(element, cell.paragraphs[0]).font.size = Pt(9)
    _size_columns(document, table, cells, width)
    document.add_paragraph()


def _size_columns(document, table, cells, width):
    """Column widths in proportion to their text (long prose gets room, short codes stay narrow)."""
    section = document.sections[-1]
    available = section.page_width - section.left_margin - section.right_margin
    plain = lambda s: re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", s).replace("**", "").replace("~~", "")
    padding = Pt(11.5)                              # left + right cell margin of the table style
    char = Pt(9) * 0.56                             # average width of a 9 pt character in the company font
    text_space = available - width * padding
    line_chars = text_space / char
    minimum, desired = [], []
    for j in range(width):
        texts = [plain(r[j]) for r in cells if j < len(r)]

        def unbreakable(word, bold=False):
            # Word wraps long words after a hyphen or slash; short ones should stay whole. Code and bold are wider.
            bare = word.strip("`*,.;:()")
            part = bare if len(bare) <= 12 else max(re.split(r"(?<=[-/])", bare), key=len)
            return len(part) * (1.15 if word.startswith("`") else 1) * (1.1 if bold else 1)

        widest = max([unbreakable(w, i == 0) for i, t in enumerate(texts) for w in t.split()], default=3)
        minimum.append(min(widest, 20) + 1.5)       # + a little: Montserrat's capitals are wider than average
        desired.append(max(min(max(len(t) for t in texts), 70), minimum[-1]))
    if sum(desired) <= line_chars:
        shares = desired
    else:
        spare = max(line_chars - sum(minimum), 0)
        extra = [d - m for d, m in zip(desired, minimum)]
        shares = [m + (spare * e / sum(extra) if sum(extra) else 0) for m, e in zip(minimum, extra)]
    widths = [int(padding + text_space * s / sum(shares)) for s in shares]
    for j, w in enumerate(widths):
        table.columns[j].width = w
        for cell in table.columns[j].cells:
            cell.width = w


def add_list_item(document, text, level, marker):
    paragraph = add_paragraph(document)
    paragraph.paragraph_format.left_indent = Emu(int(INDENT) * (level + 1))
    paragraph.paragraph_format.first_line_indent = Emu(-230000)
    paragraph.paragraph_format.space_after = Pt(2)
    paragraph.add_run(f"{marker}\t")
    add_runs(paragraph, text)


def add_bullet(document, text, level):
    add_list_item(document, text, level, "•" if level == 0 else "–")


class Figures:
    """Numbers the figures of one document."""

    def __init__(self):
        self.count = 0


def add_image(document, path, caption, figures):
    section = document.sections[-1]
    width = section.page_width - section.left_margin - section.right_margin
    paragraph = add_paragraph(document)
    paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    paragraph.paragraph_format.keep_with_next = True
    paragraph.paragraph_format.space_before = Pt(6)
    paragraph.add_run().add_picture(str(path), width=width)
    figures.count += 1
    caption_paragraph = add_paragraph(document)
    caption_paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
    caption_paragraph.paragraph_format.space_after = Pt(10)
    run = caption_paragraph.add_run(f"Figure {figures.count}. {caption}")
    run.italic = True
    run.font.size = Pt(9)
    run.font.color.rgb = CAPTION_GREY


def _list_level(indent):
    return 0 if indent < 2 else 1 if indent < 6 else 2


def render_markdown(document, text, base_dir=None, figures=None):
    """Appends the markdown to the document. base_dir resolves image paths; figures numbers the captions."""
    figures = figures or Figures()
    base_dir = Path(base_dir) if base_dir else Path.cwd()
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped.startswith("<!--") or stripped == "" or re.fullmatch(r"-{3,}|\*{3,}", stripped):
            i += 1
            continue
        heading = re.match(r"^(#{1,6})\s+(.*)$", line)
        if heading:
            level = len(heading.group(1))
            if level > 1:
                document.add_paragraph(heading.group(2).strip(), style=f"Heading {level - 1}")
            i += 1
            continue
        image = re.match(r"^!\[([^\]]*)\]\(([^)]+)\)\s*$", stripped)
        if image:
            add_image(document, base_dir / image.group(2), image.group(1), figures)
            i += 1
            continue
        if stripped.startswith("```"):
            fence_indent = len(line) - len(line.lstrip())
            i += 1
            code = []
            while i < len(lines) and lines[i].strip().startswith("```") is False:
                code.append(lines[i][fence_indent:] if len(lines[i]) >= fence_indent else lines[i].strip())
                i += 1
            i += 1
            add_code(document, code)
            continue
        if stripped.startswith("|"):
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(lines[i])
                i += 1
            add_table(document, rows)
            continue
        if stripped.startswith(">"):
            quote = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(lines[i].strip().lstrip(">").strip())
                i += 1
            paragraph = add_paragraph(document)
            paragraph.paragraph_format.left_indent = INDENT
            add_runs(paragraph, " ".join(q for q in quote if q))
            for run in paragraph.runs:
                run.italic = True
            continue
        rule = re.match(r"^- \*\*((?:[A-Z]{2,3} )?\d+(?:\.\d+)?[a-z]?)\*\*\s+(.*)$", line)
        if rule:
            body = [re.sub(r"^[-–]\s+", "", rule.group(2))]     # "**PR 1** - text": the dash is only a separator
            i += 1
            while i < len(lines) and lines[i].startswith("  ") and lines[i].strip() and \
                    re.match(r"^\s*(?:[-*]|\d+\.)\s+|^\s*(```|\|)", lines[i]) is None:
                body.append(lines[i].strip())
                i += 1
            add_rule(document, rule.group(1), " ".join(body))
            continue
        item = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", line)
        if item:
            level = _list_level(len(item.group(1)))
            marker = item.group(2)
            body = [item.group(3)]
            i += 1
            while i < len(lines) and lines[i].strip() and re.match(r"^\s*(?:[-*]|\d+\.)\s+", lines[i]) is None \
                    and lines[i].strip().startswith(("```", "|", ">", "![")) is False and lines[i].startswith(" "):
                body.append(lines[i].strip())
                i += 1
            if marker in ("-", "*"):
                add_bullet(document, " ".join(body), level)
            else:
                add_list_item(document, " ".join(body), level, marker)
            continue
        body = [stripped]
        i += 1
        while i < len(lines) and lines[i].strip() and lines[i].startswith(("#", "|", "```", "- ", ">", "![")) is False \
                and re.match(r"^\s*\d+\.\s+", lines[i]) is None:
            body.append(lines[i].strip())
            i += 1
        add_runs(add_paragraph(document), " ".join(body))
    return figures

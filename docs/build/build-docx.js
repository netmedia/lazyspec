// LazySpec developer guide: docs/developer-guide.md -> docs/developer-guide.docx (images, tables, code).
// In docs/build: npm install, node build-docx.js [out.docx], then update-fields.ps1 (Word fills the
// contents' page numbers). See docs/build/README.md.
const fs = require('fs');
const path = require('path');
const { marked } = require('marked');
const d = require('docx');

const REPO = path.resolve(__dirname, '..', '..');
const SRC = path.join(REPO, 'docs', 'developer-guide.md');
const OUT = process.argv[2] || path.join(REPO, 'docs', 'developer-guide.docx');
const GH = 'https://github.com/netmedia/lazyspec/blob/develop/';

const FONT = 'Segoe UI', MONO = 'Consolas';
const RED = 'FF303C', GREY = '595959', TEXT = '333333', MUTED = '7A7A7A', LINE = 'C9CED6', CODEBG = 'F3F4F6';
const PAGE_W = 11906, MARGIN = 1300, CONTENT_W = PAGE_W - 2 * MARGIN; // A4, DXA
const IMG_W = 600; // px, about the text width

const md = fs.readFileSync(SRC, 'utf8');
const tokens = marked.lexer(md);

// --- inline -------------------------------------------------------------------------------------------
function decode(s) {
  return s.replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'");
}
function href(u) {
  if (/^https?:/.test(u)) return u;
  if (u.startsWith('#')) return null;
  // ../tools/lazyspec/LAZYSPEC.md -> the repo on GitHub
  const rel = path.posix.normalize(path.posix.join('docs', u.replace(/\\/g, '/')));
  return GH + rel;
}
function runs(toks, st = {}) {
  const out = [];
  for (const t of toks || []) {
    switch (t.type) {
      case 'strong': out.push(...runs(t.tokens, { ...st, bold: true })); break;
      case 'em': out.push(...runs(t.tokens, { ...st, italics: true })); break;
      case 'codespan':
        out.push(new d.TextRun({ text: decode(t.text), font: MONO, size: st.size ? st.size - 2 : 18, bold: st.bold, color: st.color || '1F2933',
          shading: { type: d.ShadingType.CLEAR, color: 'auto', fill: st.inTable ? 'EDEFF2' : 'EEF0F3' } }));
        break;
      case 'link': {
        const h = href(t.href);
        const inner = runs(t.tokens, { ...st, color: '1D6FA5', underline: {} });
        if (h) out.push(new d.ExternalHyperlink({ link: h, children: inner })); else out.push(...inner);
        break;
      }
      case 'br': out.push(new d.TextRun({ break: 1 })); break;
      case 'escape': case 'text': case 'html':
        if (t.tokens && t.tokens.length && t.type === 'text') { out.push(...runs(t.tokens, st)); break; }
        out.push(new d.TextRun({ text: decode(t.text), bold: st.bold, italics: st.italics, color: st.color, underline: st.underline, size: st.size }));
        break;
      default:
        if (t.text) out.push(new d.TextRun({ text: decode(t.text), bold: st.bold, italics: st.italics, color: st.color, size: st.size }));
    }
  }
  return out;
}

// --- blocks -------------------------------------------------------------------------------------------
let listInstance = 0;
function para(children, opts = {}) { return new d.Paragraph({ children, ...opts }); }

function image(src, alt) {
  const file = path.join(path.dirname(SRC), src);
  const buf = fs.readFileSync(file);
  const w = buf.readUInt32BE(16), h = buf.readUInt32BE(20);
  const width = Math.min(IMG_W, w), height = Math.round(h * width / w);
  return [
    para([new d.ImageRun({ type: 'png', data: buf, transformation: { width, height }, altText: { title: alt, description: alt, name: path.basename(src) } })],
      { alignment: d.AlignmentType.CENTER, spacing: { before: 200, after: 60 }, keepNext: true }),
    para([new d.TextRun({ text: alt, italics: true, size: 17, color: MUTED })], { alignment: d.AlignmentType.CENTER, spacing: { after: 280 } }),
  ];
}

function list(tok, level, out) {
  const inst = ++listInstance;
  const start = out.length;
  tok.items.forEach((item) => {
    let first = true;
    for (const t of item.tokens) {
      if (t.type === 'list') { list(t, level + 1, out); continue; }
      const kids = runs(t.tokens || [{ type: 'text', text: t.text }]);
      if (first) {
        out.push(para(kids, { numbering: { reference: tok.ordered ? 'num' : 'bul', level, instance: tok.ordered ? inst : undefined }, spacing: { after: 60 } }));
        first = false;
      } else {
        out.push(para(kids, { indent: { left: 720 * (level + 1) }, spacing: { after: 60 } }));
      }
    }
  });
  // Room after a whole list, before the next paragraph.
  if (level === 0 && out.length > start) out.push(para([], { spacing: { after: 0, line: 120 } }));
}

// Column widths from the text: each column at least its longest word, the rest by how much text it has.
function widths(tok) {
  const rows = [tok.header, ...tok.rows];
  const n = tok.header.length;
  const need = Array(n).fill(0), want = Array(n).fill(0);
  rows.forEach((r, ri) => r.forEach((c, i) => {
    const t = c.text.replace(/[`*]/g, '');
    const longest = Math.max(...t.split(/\s+/).map((w) => w.length), 1);
    need[i] = Math.max(need[i], Math.min(18, longest) * (ri ? 1 : 1.15) + 2);
    want[i] = Math.max(want[i], t.length + 2);
  }));
  const total = 90; // characters across the page, about
  const sumNeed = need.reduce((a, b) => a + b, 0);
  let w;
  if (sumNeed >= total) w = need;
  else {
    const grow = want.map((x, i) => Math.max(0, x - need[i]));
    const sumGrow = grow.reduce((a, b) => a + b, 0) || 1;
    const extra = total - sumNeed;
    w = need.map((x, i) => x + extra * grow[i] / sumGrow);
  }
  const s = w.reduce((a, b) => a + b, 0);
  const dxa = w.map((x) => Math.floor(CONTENT_W * x / s));
  dxa[dxa.length - 1] += CONTENT_W - dxa.reduce((a, b) => a + b, 0);
  return dxa;
}
function table(tok) {
  const cols = widths(tok);
  const border = { style: d.BorderStyle.SINGLE, size: 4, color: LINE };
  const borders = { top: border, bottom: border, left: border, right: border };
  const cell = (c, i, head) => new d.TableCell({
    width: { size: cols[i], type: d.WidthType.DXA }, borders,
    shading: head ? { type: d.ShadingType.CLEAR, color: 'auto', fill: 'EEF2F6' } : undefined,
    margins: { top: 60, bottom: 60, left: 100, right: 100 },
    children: [para(runs(c.tokens, { bold: head, size: 18, inTable: true }), { spacing: { after: 0 } })],
  });
  return new d.Table({
    width: { size: CONTENT_W, type: d.WidthType.DXA }, columnWidths: cols,
    rows: [
      new d.TableRow({ tableHeader: true, children: tok.header.map((c, i) => cell(c, i, true)) }),
      ...tok.rows.map((r) => new d.TableRow({ cantSplit: true, children: r.map((c, i) => cell(c, i, false)) })),
    ],
  });
}
function code(tok) {
  const lines = tok.text.split('\n');
  return lines.map((l, i) => para([new d.TextRun({ text: l || ' ', font: MONO, size: 17, color: '1F2933' })], {
    shading: { type: d.ShadingType.CLEAR, color: 'auto', fill: CODEBG },
    spacing: { before: i ? 0 : 120, after: i === lines.length - 1 ? 200 : 0, line: 260 },
    indent: { left: 120, right: 120 }, keepNext: i < lines.length - 1, keepLines: true,
  }));
}

const body = [];
let title = 'LazySpec — Developer Guide', intro = null;
for (const t of tokens) {
  switch (t.type) {
    case 'heading':
      if (t.depth === 1) { title = decode(t.text); break; }
      body.push(para(runs(t.tokens), { heading: t.depth === 2 ? d.HeadingLevel.HEADING_1 : d.HeadingLevel.HEADING_2, pageBreakBefore: t.depth === 2 && body.length > 0 }));
      break;
    case 'paragraph': {
      const img = t.tokens.length === 1 && t.tokens[0].type === 'image' ? t.tokens[0] : null;
      if (img) { body.push(...image(img.href, img.text)); break; }
      if (!body.length && !intro) { intro = runs(t.tokens); break; }
      body.push(para(runs(t.tokens)));
      break;
    }
    case 'list': list(t, 0, body); break;
    case 'table': body.push(table(t), para([], { spacing: { after: 120 } })); break;
    case 'code': body.push(...code(t)); break;
    case 'hr': case 'space': break;
    default: if (t.text) body.push(para([new d.TextRun(decode(t.text))]));
  }
}

// --- the cover and the contents ------------------------------------------------------------------------
const today = new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' });
const [main, sub] = title.split(/\s+[—-]\s+/);
const cover = [
  para([], { spacing: { before: 2600 } }),
  para([new d.TextRun({ text: ' ', size: 4 })], { border: { top: { style: d.BorderStyle.SINGLE, size: 36, color: RED, space: 1 } }, indent: { right: CONTENT_W - 2300 }, spacing: { after: 360 } }),
  para([new d.TextRun({ text: main, size: 64, bold: true, color: TEXT })], { spacing: { after: 120 } }),
  para([new d.TextRun({ text: sub || 'Developer Guide', size: 40, color: GREY })], { spacing: { after: 600 } }),
  para(intro ? intro.map((r) => r) : [], { spacing: { after: 600 } }),
  para([new d.TextRun({ text: 'Install, add to a project, every workflow — with diagrams and screenshots', size: 20, color: MUTED })], { spacing: { after: 120 } }),
  para([new d.TextRun({ text: `Netmedia  ·  ${today}`, size: 20, color: MUTED })], { spacing: { after: 60 } }),
  para([new d.ExternalHyperlink({ link: 'https://github.com/netmedia/lazyspec', children: [new d.TextRun({ text: 'github.com/netmedia/lazyspec', size: 20, color: '1D6FA5' })] })]),
];
const toc = [
  para([new d.TextRun({ text: 'Contents', size: 36, color: RED })], { spacing: { after: 200 } }),
  new d.TableOfContents('Contents', { hyperlink: true, headingStyleRange: '1-2' }),
];

const doc = new d.Document({
  creator: 'Netmedia', title, description: 'LazySpec developer guide',
  features: { updateFields: true },
  styles: {
    default: { document: { run: { font: FONT, size: 20, color: TEXT }, paragraph: { spacing: { after: 120, line: 276 } } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 34, color: RED }, paragraph: { spacing: { before: 0, after: 200 }, keepNext: true, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 25, bold: true, color: TEXT }, paragraph: { spacing: { before: 320, after: 120 }, keepNext: true, outlineLevel: 1 } },
    ],
  },
  numbering: {
    config: [
      { reference: 'bul', levels: [0, 1, 2].map((l) => ({ level: l, format: d.LevelFormat.BULLET, text: ['•', '–', '·'][l], alignment: d.AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 360 + 360 * l, hanging: 280 } } } })) },
      { reference: 'num', levels: [0, 1].map((l) => ({ level: l, format: l ? d.LevelFormat.LOWER_LETTER : d.LevelFormat.DECIMAL, text: `%${l + 1}.`, alignment: d.AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 360 + 360 * l, hanging: 300 } } } })) },
    ],
  },
  sections: [
    { properties: { page: { size: { width: PAGE_W, height: 16838 }, margin: { top: 1300, bottom: 1200, left: MARGIN, right: MARGIN } } },
      children: cover },
    { properties: { page: { size: { width: PAGE_W, height: 16838 }, margin: { top: 1300, bottom: 1200, left: MARGIN, right: MARGIN }, pageNumbers: { start: 2 } } },
      headers: { default: new d.Header({ children: [para([new d.TextRun({ text: 'LazySpec — Developer Guide', size: 16, color: MUTED })], { alignment: d.AlignmentType.RIGHT })] }) },
      footers: { default: new d.Footer({ children: [para([
        new d.TextRun({ text: 'Netmedia  ·  netmedia.agency', size: 16, color: MUTED }),
        new d.TextRun({ children: [new d.PositionalTab({ alignment: d.PositionalTabAlignment.RIGHT, relativeTo: d.PositionalTabRelativeTo.MARGIN, leader: d.PositionalTabLeader.NONE }), d.PageNumber.CURRENT, ' / ', d.PageNumber.TOTAL_PAGES], size: 16, color: MUTED }),
      ])] }) },
      children: [...toc, para([new d.PageBreak()]), ...body] },
  ],
});
d.Packer.toBuffer(doc).then((b) => { fs.writeFileSync(OUT, b); console.log('written', OUT, b.length); });

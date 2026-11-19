// How the formatted editor writes Markdown it hasn't changed: each .md of a folder through the editor (its
// bundled script, in headless Edge or Chrome), then the lines that differ. node scripts/roundtrip.js <folder> [out.json]
const cp = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const dir = path.resolve(process.argv[2] || path.join(__dirname, '..', '..', 'examples', 'acme-portal', 'openspec'));
const files = [];
(function walk(d) { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) { walk(p); } else if (e.name.endsWith('.md')) { files.push(p); } } })(dir);
const docs = files.map(f => ({ file: path.relative(dir, f), text: fs.readFileSync(f, 'utf8').replace(/\r/g, '') }));
const web = path.join(__dirname, '..', 'out', 'webview');
const page = path.join(os.tmpdir(), `lazyspec-roundtrip-${Date.now()}.html`);
fs.writeFileSync(page, `<!DOCTYPE html><html><head><meta charset="utf-8"><link rel="stylesheet" href="${'file:///' + path.join(web, 'editor.css').replace(/\\/g, '/')}"></head>
<body><div id="editor"></div><pre id="out">pending</pre>
<script src="${'file:///' + path.join(web, 'editor.js').replace(/\\/g, '/')}"></script>
<script>
const docs = ${JSON.stringify(docs).replace(/</g, '\\u003c')};
(async () => {
  const out = [];
  for (const d of docs) { try { out.push({ file: d.file, md: await window.lazyspecLoad(d.text) }); } catch (e) { out.push({ file: d.file, error: String(e) }); } }
  document.getElementById('out').textContent = JSON.stringify(out);
})();
</script></body></html>`);
const browser = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'].find(b => fs.existsSync(b));
const profile = path.join(os.tmpdir(), `lazyspec-roundtrip-profile-${Date.now()}`);
try {
  const dom = cp.execFileSync(browser, ['--headless=new', '--disable-gpu', '--allow-file-access-from-files', `--user-data-dir=${profile}`, '--virtual-time-budget=20000', '--dump-dom', 'file:///' + page.replace(/\\/g, '/')], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, timeout: 120000 });
  const m = /<pre id="out">([\s\S]*?)<\/pre>/.exec(dom);
  const raw = m ? m[1].replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&') : '';
  if (!raw || raw === 'pending') { console.log('no result (the editor did not finish)'); process.exit(1); }
  const out = JSON.parse(raw);
  let same = 0;
  for (const o of out) {
    const d = docs.find(x => x.file === o.file);
    if (o.error) { console.log(`ERROR ${o.file}: ${o.error}`); continue; }
    const a = d.text.trimEnd().split('\n'), b = o.md.trimEnd().split('\n');
    if (a.join('\n') === b.join('\n')) { same++; continue; }
    const diffs = [];
    for (let i = 0; i < Math.max(a.length, b.length) && diffs.length < 6; i++) { if (a[i] !== b[i]) { diffs.push(`  ${i + 1}: - ${a[i] ?? ''}\n  ${i + 1}: + ${b[i] ?? ''}`); } }
    console.log(`${o.file}: ${a.length} -> ${b.length} lines\n${diffs.join('\n')}`);
  }
  console.log(`\n${same} of ${out.length} unchanged`);
  if (process.argv[3]) { fs.writeFileSync(process.argv[3], JSON.stringify(out, null, 1)); }
} finally { fs.rmSync(page, { force: true }); fs.rmSync(profile, { recursive: true, force: true }); }

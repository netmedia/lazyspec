// LazySpec's kit (tools/lazyspec) into kit/: the extension exports and opens the terminal UI with it when
// the project has no copy of its own.
const fs = require('fs');
const path = require('path');

const from = path.join(__dirname, '..', '..', 'tools', 'lazyspec');
const to = path.join(__dirname, '..', 'kit');
fs.mkdirSync(to, { recursive: true });
for (const f of ['lazyspec.ps1', 'export-texts.json', 'kit.json', 'LAZYSPEC.md']) {
  fs.copyFileSync(path.join(from, f), path.join(to, f));
}
// The netmedia-document generator: Word and PDF exports are Netmedia documents (used when none is installed).
fs.rmSync(path.join(to, 'netmedia-document'), { recursive: true, force: true });
fs.cpSync(path.join(from, 'netmedia-document'), path.join(to, 'netmedia-document'), { recursive: true });
console.log(`kit: ${to}`);

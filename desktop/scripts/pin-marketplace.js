// The lazyspec entry of a marketplace.json (AIToolbelt's) pinned to a release: its GitHub source at that commit.
// Organization sync reads only the marketplace repository's pushes, so this change is what releases LazySpec to
// the organization; Claude Code compares plugin.json's version.
//   node pin-marketplace.js <marketplace.json> <commit sha> <version>
const fs = require('fs');
const [file, sha, version] = process.argv.slice(2);
if (!file || !/^[0-9a-f]{40}$/.test(sha || '') || !version) {
  console.error('usage: node pin-marketplace.js <marketplace.json> <40-character commit sha> <version>');
  process.exit(2);
}
const raw = fs.readFileSync(file, 'utf8');
const m = JSON.parse(raw);
const entry = {
  name: 'lazyspec',
  description: "LazySpec: a project's OpenSpec specs and changes as tools - read, find, edit, tick, out of date, undo, validate, archive, export, save as a pull request.",
  author: { name: 'Netmedia', email: 'netmedia@netmedia.hr', homepage: 'https://netmedia.agency' },
  source: { source: 'github', repo: 'netmedia/lazyspec', sha },
  category: 'development',
};
const at = m.plugins.findIndex(p => p.name === 'lazyspec');
if (at >= 0) { m.plugins[at] = { ...m.plugins[at], source: entry.source }; } else { m.plugins.push(entry); }
const nl = raw.includes('\r\n') ? '\r\n' : '\n';
fs.writeFileSync(file, JSON.stringify(m, null, 2).replace(/\n/g, nl) + nl);
console.log(`${file}: lazyspec ${version} at ${sha.slice(0, 12)}`);

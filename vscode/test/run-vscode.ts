// The extension in a real VS Code (downloaded into .vscode-test), on a copy of the demo project with groups
// added: npm run test:vscode.

import * as cp from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { runTests } from '@vscode/test-electron';

async function main() {
  const ext = path.resolve(__dirname, '..', '..');
  const work = fs.mkdtempSync(path.join(os.tmpdir(), 'lazyspec-vscode-ws-'));
  fs.cpSync(path.resolve(ext, '..', 'examples', 'acme-portal'), work, { recursive: true });
  fs.rmSync(path.join(work, '.lazyspec'), { recursive: true, force: true });
  // Groups: 01 in phase 1, 03 in phase 2 (requires 1); 02 ungrouped.
  const cfg = path.join(work, 'openspec', 'config.yaml');
  fs.writeFileSync(cfg, fs.readFileSync(cfg, 'utf8') + '\ngroupLabel: "Phase"\ngroups:\n  - id: 1\n    name: "Accounts"\n  - id: 2\n    name: "Orders"\n    requires: [1]\n');
  fs.writeFileSync(path.join(work, 'openspec', 'changes', '01-add-user-signup', '.openspec.yaml'), 'schema: spec-driven\nx-group: 1\n');
  fs.writeFileSync(path.join(work, 'openspec', 'changes', '03-add-order-history', '.openspec.yaml'), 'schema: spec-driven\nx-group: 2\n');
  // In git (undo), out-of-date documents watched.
  fs.writeFileSync(cfg, fs.readFileSync(cfg, 'utf8').replace('lazyspec:\n', 'lazyspec:\n  syncCheck: on\n'));
  const g = (...a: string[]) => cp.execFileSync('git', ['-c', 'user.name=t', '-c', 'user.email=t@t', ...a], { cwd: work, stdio: 'ignore' });
  g('init', '-q'); g('add', '-A'); g('commit', '-q', '-m', 'start');
  try {
    await runTests({
      extensionDevelopmentPath: ext,
      extensionTestsPath: path.join(__dirname, 'suite.js'),
      launchArgs: [work, '--disable-extensions', '--skip-welcome', '--skip-release-notes'],
      extensionTestsEnv: { LAZYSPEC_TEST_WORKSPACE: work },
    });
    // The project two levels below the opened folder (a monorepo): found, the sidebar shown.
    const mono = fs.mkdtempSync(path.join(os.tmpdir(), 'lazyspec-vscode-mono-'));
    fs.cpSync(work, path.join(mono, 'apps', 'portal'), { recursive: true });
    fs.mkdirSync(path.join(mono, 'node_modules', 'x', 'openspec', 'specs'), { recursive: true });
    try {
      await runTests({
        extensionDevelopmentPath: ext,
        extensionTestsPath: path.join(__dirname, 'suite.js'),
        launchArgs: [mono, '--disable-extensions', '--skip-welcome', '--skip-release-notes'],
        extensionTestsEnv: { LAZYSPEC_TEST_WORKSPACE: mono, LAZYSPEC_TEST_DEEP: '1' },
      });
    } finally { fs.rmSync(mono, { recursive: true, force: true }); }
  } finally { fs.rmSync(work, { recursive: true, force: true }); }
}
main().catch(e => { console.error(e); process.exit(1); });

// The agent (Claude Code), as LazySpec hands work to it: the prompt saved in .lazyspec/prompts/, then here (a
// terminal: it can ask, you answer), in the background (no questions; its output in a channel; answer it
// after: claude -c -p), or only the prompt saved. The project's choice is remembered (lazyspec: agent:).

import * as cp from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { Project } from './model';
import { agentInstruction, readSyncSnapshot, savePrompt, setConfigValue, setInSyncFromFile } from './ops';

let channel: vscode.OutputChannel | undefined;
let lastRoot = '';
const MODES = [
  { mode: 'here', label: '$(terminal) Here', description: 'Claude Code in a terminal: it may ask, you answer' },
  { mode: 'background', label: '$(sync) In the background', description: 'no questions: it decides and says what; answer it after' },
  { mode: 'prompt', label: '$(save) Save the prompt', description: 'the command copied, for later' },
];

/** claude (LAZYSPEC_AGENT: another command, the tests): its path, or ''. */
function agentTool(): string {
  if (process.env.LAZYSPEC_AGENT) { return process.env.LAZYSPEC_AGENT; }
  const exts = process.platform === 'win32' ? ['.exe', '.cmd', '.bat', ''] : [''];
  for (const dir of (process.env.PATH || process.env.Path || '').split(path.delimiter)) {
    for (const e of exts) { const f = path.join(dir, 'claude' + e); if (dir && fs.existsSync(f) && fs.statSync(f).isFile()) { return f; } }
  }
  return '';
}
function quote(a: string): string { return /^[\w./:=-]+$/.test(a) ? a : `"${a.replace(/"/g, '\\"')}"`; }

/** Snapshot files of runs started here (not offered again as saved prompts done outside). */
export const runningSyncs = new Set<string>();
let afterSync: () => void = () => undefined;
/** What to do after a change is marked as in sync (the views reloaded). */
export function onSynced(fn: () => void) { afterSync = fn; }

/** The work as a prompt, then how (asked; the project's last choice first). $sync: writes a sync prompt's
 *  snapshot (<prompt>.sync.json) from the prompt's path: the agent done, the change is marked as in sync
 *  against it - in the background when it ends with 0 and openspec validate passes; here: asked. */
export async function agentTask(p: Project, label: string, name: string, prompt: string, sync?: (rel: string) => string) {
  const rel = savePrompt(p, name, prompt);
  const syncFile = sync ? sync(rel) : '';
  const def = p.config.values['agent'] === 'run' ? 'here' : p.config.values['agent'];
  const items = [...MODES].sort((a, b) => (a.mode === def ? -1 : b.mode === def ? 1 : 0));
  const pick = await vscode.window.showQuickPick(items, { placeHolder: `${label}: the agent (Claude Code)`, title: 'LazySpec' });
  if (!pick) { void vscode.window.showInformationMessage(`Prompt saved: ${rel}`); return; }
  if (p.config.values['agent'] !== pick.mode) { try { setConfigValue(p, 'agent', pick.mode); } catch { /* read-only */ } }
  if (syncFile && pick.mode !== 'prompt') { runningSyncs.add(syncFile); }
  if (pick.mode === 'here') { here(p, label, rel, syncFile); }
  else if (pick.mode === 'background') {
    const code = await background(p, label, ['-p', agentInstruction(rel) + ' Do not ask questions: where something is unclear, decide sensibly, and at the end list what you decided.', '--permission-mode', 'acceptEdits'], !!syncFile);
    if (syncFile) { await completeSync(p, syncFile, code); }
  }
  else { await showPrompt(rel, ''); }
}
async function showPrompt(rel: string, why: string) {
  const cmd = `claude "${agentInstruction(rel)}"`;
  await vscode.env.clipboard.writeText(cmd);
  void vscode.window.showInformationMessage(`${why}Prompt saved: ${rel}. The command to give it is copied: ${cmd}`);
}
function here(p: Project, label: string, rel: string, syncFile = '') {
  const tool = agentTool();
  if (!tool) { runningSyncs.delete(syncFile); void showPrompt(rel, 'Claude Code (claude) is not installed. '); return; }
  const args = [agentInstruction(rel), '--permission-mode', 'acceptEdits'];
  if (!syncFile) {
    const t = vscode.window.createTerminal({ name: `Claude Code: ${label}`, cwd: p.root });
    t.show();
    t.sendText(`${quote(tool)} ${args.map(quote).join(' ')}`);
    return;
  }
  // A sync: Claude Code is the terminal's own process, so its end (and exit code) is known - then asked.
  const viaCmd = /\.(cmd|bat)$/i.test(tool);
  const t = vscode.window.createTerminal({
    name: `Claude Code: ${label}`, cwd: p.root,
    shellPath: viaCmd ? (process.env.ComSpec || 'cmd.exe') : tool,
    shellArgs: viaCmd ? ['/d', '/c', tool, ...args] : args,
  });
  const sub = vscode.window.onDidCloseTerminal(async closed => {
    if (closed !== t) { return; }
    sub.dispose();
    const code = closed.exitStatus?.code;
    runningSyncs.delete(syncFile);
    const name = readSyncSnapshot(syncFile)?.change || '';
    if (!name) { return; }
    // /exit ends it with 0 also when you stopped it halfway: asked (yes first).
    if (code !== undefined && code !== 0) { void vscode.window.showWarningMessage(`Claude Code ended with exit code ${code}: ${name} not marked as in sync.`); return; }
    const ok = await vscode.window.showInformationMessage(`${name}: mark as in sync? (Claude Code is done)`, 'Yes, Mark', 'No');
    if (ok === 'Yes, Mark') { mark(p, syncFile, 'updated by the agent, marked as in sync'); }
  });
  t.show();
}
function mark(p: Project, syncFile: string, how: string) {
  const n = setInSyncFromFile(p, syncFile);
  if (n) { void vscode.window.showInformationMessage(`${n}: ${how}.`); }
  afterSync();
}
/** A sync run in the background ended: 0 - validated (openspec validate <change>, its output in the channel),
 *  then marked; else not marked, said so. */
export async function completeSync(p: Project, syncFile: string, code: number) {
  channel ||= vscode.window.createOutputChannel('LazySpec: Claude Code');
  runningSyncs.delete(syncFile);
  const name = readSyncSnapshot(syncFile)?.change || '';
  if (!name) { return; }
  if (code !== 0) { void vscode.window.showWarningMessage(`${name}: not marked as in sync - the agent ended with exit code ${code} (Sync again, or mark it).`); return; }
  const cli = vscode.workspace.getConfiguration('lazyspec').get<string>('openspec', 'openspec');
  channel!.appendLine(`\n> ${cli} validate ${name} --strict --no-interactive`);
  const v = await run(p.root, cli, ['validate', name, '--strict', '--no-interactive']);
  if (v === -1) { channel!.appendLine('! not validated: the OpenSpec CLI isn\'t there (lazyspec.openspec)'); }
  else if (v !== 0) {
    void vscode.window.showWarningMessage(`${name}: not marked as in sync - openspec validate failed. Fix it, then sync again.`, 'Show Output').then(pick => { if (pick) { channel!.show(); } });
    return;
  }
  mark(p, syncFile, 'updated by the agent, marked as in sync');
}
/** A command's output in the channel; its exit code (-1: not started). npm's .cmd through cmd.exe. */
function run(cwd: string, tool: string, args: string[]): Promise<number> {
  return new Promise(resolve => {
    let child: cp.ChildProcess;
    try {
      child = process.platform === 'win32'
        ? cp.spawn(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', `"${[quote(tool), ...args.map(quote)].join(' ')}"`], { cwd, windowsVerbatimArguments: true, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true })
        : cp.spawn(tool, args, { cwd, stdio: ['ignore', 'pipe', 'pipe'] });
    } catch { resolve(-1); return; }
    child.stdout?.on('data', b => channel!.append(b.toString('utf8')));
    child.stderr?.on('data', b => channel!.append(b.toString('utf8')));
    child.on('error', () => resolve(-1));
    child.on('close', c => resolve(c ?? -1));
  });
}
/** A saved sync prompt done outside (a document it names changed, the change still out of date): marked? */
export async function offerDoneSync(p: Project, syncFile: string) {
  const name = readSyncSnapshot(syncFile)?.change || '';
  if (!name) { return; }
  const ok = await vscode.window.showInformationMessage(`${name}: its documents changed since the saved sync prompt. Mark them as in sync?`, 'Yes, in Sync', 'No');
  if (ok === 'Yes, in Sync') { mark(p, syncFile, 'marked as in sync (against the saved prompt\'s specs)'); }
}
async function background(p: Project, label: string, args: string[], quiet = false): Promise<number> {
  const tool = agentTool();
  if (!tool) { void vscode.window.showWarningMessage('Claude Code (claude) is not installed: npm install -g @anthropic-ai/claude-code'); return -1; }
  channel ||= vscode.window.createOutputChannel('LazySpec: Claude Code');
  channel.show(true);
  channel.appendLine(`\n> claude ${args.map(quote).join(' ')}`);
  lastRoot = p.root;
  const code = await vscode.window.withProgress({ location: vscode.ProgressLocation.Notification, title: `Claude Code: ${label}`, cancellable: true }, (_progress, token) =>
    new Promise<number>(resolve => {
      // npm's claude.cmd runs through cmd.exe; the native claude.exe directly.
      const viaCmd = /\.(cmd|bat)$/i.test(tool);
      const child = viaCmd
        ? cp.spawn(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', `"${[quote(tool), ...args.map(quote)].join(' ')}"`], { cwd: p.root, windowsVerbatimArguments: true, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true })
        : cp.spawn(tool, args, { cwd: p.root, stdio: ['ignore', 'pipe', 'pipe'], windowsHide: true });
      token.onCancellationRequested(() => child.kill());
      child.stdout.on('data', b => channel!.append(b.toString('utf8')));
      child.stderr.on('data', b => channel!.append(b.toString('utf8')));
      child.on('error', e => { channel!.appendLine(e.message); resolve(-1); });
      child.on('close', c => resolve(c ?? -1));
    }));
  // A sync goes on (validated, marked): what to do next is said after it.
  if (quiet && code === 0) { return code; }
  void vscode.window.showInformationMessage(code === 0 ? `Claude Code done: ${label}.` : `Claude Code ended with exit code ${code}: ${label}.`, 'Answer It', 'What It Changed', 'Show Output').then(async pick => {
    if (pick === 'Answer It') { await answer(p); }
    else if (pick === 'What It Changed') { void vscode.commands.executeCommand('lazyspec.undo.focus'); }
    else if (pick === 'Show Output') { channel!.show(); }
  });
  return code;
}
/** Its question answered, or more for it to do: the same conversation (claude -c -p). */
export async function answer(p?: Project) {
  const root = p?.root || lastRoot;
  if (!root) { void vscode.window.showInformationMessage('Nothing to answer: no agent ran in the background yet.'); return; }
  const v = await vscode.window.showInputBox({ prompt: 'Answer Claude Code: its question\'s option (1, 2 ...) or anything to go on with (claude -c)' });
  if (!v) { return; }
  await background({ root } as Project, 'your answer', ['-c', '-p', v, '--permission-mode', 'acceptEdits']);
}

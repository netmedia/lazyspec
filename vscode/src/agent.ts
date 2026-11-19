// The agent (Claude Code), as LazySpec hands work to it: the prompt saved in .lazyspec/prompts/, then here (a
// terminal: it can ask, you answer), in the background (no questions; its output in a channel; answer it
// after: claude -c -p), or only the prompt saved. The project's choice is remembered (lazyspec: agent:).

import * as cp from 'child_process';
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import { Project } from './model';
import { agentInstruction, savePrompt, setConfigValue } from './ops';

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

/** The work as a prompt, then how (asked; the project's last choice first). */
export async function agentTask(p: Project, label: string, name: string, prompt: string) {
  const rel = savePrompt(p, name, prompt);
  const def = p.config.values['agent'] === 'run' ? 'here' : p.config.values['agent'];
  const items = [...MODES].sort((a, b) => (a.mode === def ? -1 : b.mode === def ? 1 : 0));
  const pick = await vscode.window.showQuickPick(items, { placeHolder: `${label}: the agent (Claude Code)`, title: 'LazySpec' });
  if (!pick) { void vscode.window.showInformationMessage(`Prompt saved: ${rel}`); return; }
  if (p.config.values['agent'] !== pick.mode) { try { setConfigValue(p, 'agent', pick.mode); } catch { /* read-only */ } }
  if (pick.mode === 'here') { here(p, label, rel); }
  else if (pick.mode === 'background') { await background(p, label, ['-p', agentInstruction(rel) + ' Do not ask questions: where something is unclear, decide sensibly, and at the end list what you decided.', '--permission-mode', 'acceptEdits']); }
  else { await showPrompt(rel, ''); }
}
async function showPrompt(rel: string, why: string) {
  const cmd = `claude "${agentInstruction(rel)}"`;
  await vscode.env.clipboard.writeText(cmd);
  void vscode.window.showInformationMessage(`${why}Prompt saved: ${rel}. The command to give it is copied: ${cmd}`);
}
function here(p: Project, label: string, rel: string) {
  const tool = agentTool();
  if (!tool) { void showPrompt(rel, 'Claude Code (claude) is not installed. '); return; }
  const t = vscode.window.createTerminal({ name: `Claude Code: ${label}`, cwd: p.root });
  t.show();
  t.sendText(`${quote(tool)} ${quote(agentInstruction(rel))} --permission-mode acceptEdits`);
}
async function background(p: Project, label: string, args: string[]) {
  const tool = agentTool();
  if (!tool) { void vscode.window.showWarningMessage('Claude Code (claude) is not installed: npm install -g @anthropic-ai/claude-code'); return; }
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
  const pick = await vscode.window.showInformationMessage(code === 0 ? `Claude Code done: ${label}.` : `Claude Code ended with exit code ${code}: ${label}.`, 'Answer It', 'What It Changed', 'Show Output');
  if (pick === 'Answer It') { await answer(p); }
  else if (pick === 'What It Changed') { void vscode.commands.executeCommand('lazyspec.undo.focus'); }
  else if (pick === 'Show Output') { channel.show(); }
}
/** Its question answered, or more for it to do: the same conversation (claude -c -p). */
export async function answer(p?: Project) {
  const root = p?.root || lastRoot;
  if (!root) { void vscode.window.showInformationMessage('Nothing to answer: no agent ran in the background yet.'); return; }
  const v = await vscode.window.showInputBox({ prompt: 'Answer Claude Code: its question\'s option (1, 2 ...) or anything to go on with (claude -c)' });
  if (!v) { return; }
  await background({ root } as Project, 'your answer', ['-c', '-p', v, '--permission-mode', 'acceptEdits']);
}

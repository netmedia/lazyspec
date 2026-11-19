// A small MCP server over stdio (JSON-RPC 2.0, one message per line): tools and prompts, nothing else.
// No SDK: the whole server bundles into one file that Claude Desktop's own Node runs.

import * as readline from 'readline';

export interface ToolResult { text: string; isError?: boolean }
export interface Tool {
  name: string;
  title?: string;
  description: string;
  inputSchema: Record<string, unknown>;
  readOnly?: boolean;
  destructive?: boolean;
  run(args: Record<string, unknown>): Promise<ToolResult> | ToolResult;
}
export interface PromptArg { name: string; description: string; required?: boolean }
export interface Prompt {
  name: string;
  title?: string;
  description: string;
  arguments: PromptArg[];
  text(args: Record<string, string>): string;
}

const VERSIONS = ['2025-11-25', '2025-06-18', '2025-03-26', '2024-11-05'];

export class UserError extends Error {}

export function serve(info: { name: string; version: string; instructions: string }, tools: Tool[], prompts: Prompt[]) {
  const byName = new Map(tools.map(t => [t.name, t]));
  const send = (msg: unknown) => process.stdout.write(JSON.stringify(msg) + '\n');
  const reply = (id: unknown, result: unknown) => send({ jsonrpc: '2.0', id, result });
  const fail = (id: unknown, code: number, message: string) => send({ jsonrpc: '2.0', id, error: { code, message } });

  async function handle(msg: { id?: unknown; method?: string; params?: Record<string, unknown> }) {
    const { id, method, params = {} } = msg;
    const isRequest = id !== undefined && id !== null;
    switch (method) {
      case 'initialize': {
        const asked = String(params.protocolVersion || '');
        return reply(id, {
          protocolVersion: VERSIONS.includes(asked) ? asked : VERSIONS[0],
          capabilities: { tools: {}, prompts: {} },
          serverInfo: { name: info.name, version: info.version },
          instructions: info.instructions,
        });
      }
      case 'ping': return reply(id, {});
      case 'tools/list':
        return reply(id, {
          tools: tools.map(t => ({
            name: t.name, title: t.title, description: t.description, inputSchema: t.inputSchema,
            annotations: { title: t.title, readOnlyHint: !!t.readOnly, destructiveHint: !!t.destructive, openWorldHint: false },
          })),
        });
      case 'tools/call': {
        const tool = byName.get(String(params.name));
        if (!tool) { return fail(id, -32602, `Unknown tool: ${params.name}`); }
        try {
          const r = await tool.run((params.arguments as Record<string, unknown>) || {});
          return reply(id, { content: [{ type: 'text', text: r.text }], isError: !!r.isError });
        } catch (e) {
          const text = e instanceof UserError ? e.message : `${tool.name} failed: ${e instanceof Error ? e.stack || e.message : String(e)}`;
          return reply(id, { content: [{ type: 'text', text }], isError: true });
        }
      }
      case 'prompts/list':
        return reply(id, { prompts: prompts.map(p => ({ name: p.name, title: p.title, description: p.description, arguments: p.arguments })) });
      case 'prompts/get': {
        const p = prompts.find(x => x.name === params.name);
        if (!p) { return fail(id, -32602, `Unknown prompt: ${params.name}`); }
        const args = (params.arguments as Record<string, string>) || {};
        return reply(id, { description: p.description, messages: [{ role: 'user', content: { type: 'text', text: p.text(args) } }] });
      }
      case 'resources/list': return reply(id, { resources: [] });
      case 'resources/templates/list': return reply(id, { resourceTemplates: [] });
      default:
        if (isRequest) { fail(id, -32601, `Method not found: ${method}`); }
    }
  }

  const rl = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
  rl.on('line', line => {
    if (!line.trim()) { return; }
    let msg: unknown;
    try { msg = JSON.parse(line); } catch { return fail(null, -32700, 'Parse error'); }
    const list = Array.isArray(msg) ? msg : [msg];
    for (const m of list) { handle(m).catch(e => process.stderr.write(`lazyspec: ${e}\n`)); }
  });
  rl.on('close', () => process.exit(0));
}

#!/usr/bin/env node
// ha — small CLI for poking the Home Assistant on home.stromdahl.tech.
//
// Read:
//   ha state <entity_id>                         # slimmed: no last_*/context fields
//   ha entities [pattern]                        # glob (e.g. 'sensor.*temp*') or /regex/
//   ha services [domain[.service]]               # introspect /api/services
//   ha template '<jinja>'
//
// Write:
//   ha call <domain.service> '<json-data>'
//
// Config-flow integrations & helpers:
//   ha flow <handler> '<json>' ['<json>' ...]    # drive a config_entries flow; one JSON per step. Used for
//                                                #   config-flow helpers (history_stats, utility_meter,
//                                                #   derivative, threshold, ...) and integration setup.
//                                                #   Prints the final create_entry response. Aborts on form error.
//   ha entry list [domain]                       # list config entries; optional domain filter
//   ha entry get <entry_id>
//   ha entry delete <entry_id>
//   ha entry reload <entry_id>
//   ha entry flows                               # in-progress flows awaiting input
//
// Dashboards:
//   ha dash list
//   ha dash get <url_path> [file]                # default: stdout
//   ha dash save <url_path> <file>               # push file -> HA
//
// Automations:
//   ha auto list
//   ha auto get <id> [file]
//   ha auto save <id> <file>
//   ha auto delete <id>
//
// Scenes:
//   ha scene list
//   ha scene get <id> [file]
//   ha scene save <id> <file>                    # POST + scene.reload
//   ha scene delete <id>
//
// Collection helpers (input_*) — WS-based:
//   ha helper list
//   ha helper create <type> '<json>'             # type: input_number / input_button / ...
//   ha helper delete <type> <id>
//
// Registry — entities, devices, areas:
//   ha entity list                               # entity_id, name, area_id, device_id, disabled_by, hidden_by
//   ha entity get <entity_id>
//   ha entity update <entity_id> '<json>'        # e.g. {"name":"...","area_id":"...","new_entity_id":"..."}
//   ha entity remove <entity_id>
//   ha entity disable <entity_id>                # shortcut: update disabled_by=user
//   ha entity enable <entity_id>                 # shortcut: update disabled_by=null
//   ha device list                               # device_id, area_id, name_by_user, model
//   ha device update <device_id> '<json>'        # e.g. {"area_id":"kitchen","name_by_user":"Fridge"}
//   ha area list
//   ha area create '<json>'                      # {"name":"Fridge","icon":"mdi:fridge"}
//   ha area delete <area_id>
//
// Raw:
//   ha ws '<json>'                               # raw WS command, prints the result payload
//
// Global flags (any position):
//   --pretty                                     # pretty-print JSON output (default: compact, single-line)
//   --quiet | -q                                 # silence "saved"/"deleted" chatter on writes
//   -o <key.path> | --output <key.path>          # extract a field from JSON output; print scalar if leaf is primitive
//
// Auth: reads the bearer token from ~/.ha-token.json (the MCP-shaped file).
// Host: home.stromdahl.tech (HTTPS for REST, WSS for WebSocket).
//       Override with $HA_BASE — e.g. HA_BASE=http://192.168.1.99:8123 for LAN/sandbox
//       use. http:// implies ws://; https:// implies wss://.

import * as fs from 'node:fs';
import * as path from 'node:path';

// ---------- types ----------

interface Flags {
  pretty: boolean;
  quiet: boolean;
  output: string | null;
}

type CmdFn = (args: string[]) => Promise<void>;
interface CmdTree { [key: string]: CmdFn | CmdTree }

type WalkResult =
  | { fn: CmdFn; rest: string[] }
  | { fn?: undefined; node: CmdTree; i: number };

interface TokenFile {
  headers: { Authorization: string };
}

interface HAState {
  entity_id: string;
  state: string;
  attributes: Record<string, unknown>;
  last_changed?: string;
  last_reported?: string;
  last_updated?: string;
  context?: { id: string; parent_id: string | null; user_id: string | null };
}

interface HAStateSlim {
  entity_id: string;
  state: string;
  attributes: Record<string, unknown>;
}

interface HAServiceGroup {
  domain: string;
  services: Record<string, unknown>;
}

interface HAConfigEntry {
  entry_id: string;
  domain: string;
  title: string | null;
  state: string;
  source: string | null;
}

interface HAEntityRegistryEntry {
  entity_id: string;
  name: string | null;
  original_name: string | null;
  area_id: string | null;
  device_id: string | null;
  disabled_by: string | null;
  hidden_by: string | null;
}

interface HADeviceRegistryEntry {
  id: string;
  area_id: string | null;
  name: string | null;
  name_by_user: string | null;
  model: string | null;
}

interface HAAreaRegistryEntry {
  area_id: string;
  name: string;
  icon: string | null;
}

interface HALovelaceListEntry {
  url_path: string;
  title: string;
  icon: string | null;
}

interface HAFormFlowStep {
  type: 'form';
  flow_id: string;
  step_id: string;
  errors?: unknown;
  data_schema?: unknown;
}

interface HACreateEntryFlow {
  type: 'create_entry';
  flow_id: string;
  result: unknown;
}

interface HAAbortFlow {
  type: 'abort';
  reason?: string;
}

type HAFlowResponse = HAFormFlowStep | HACreateEntryFlow | HAAbortFlow;

interface WSResult {
  id: number;
  type: 'result';
  success: boolean;
  result?: unknown;
  error?: unknown;
}

interface WSAuthFrame {
  type: 'auth_required' | 'auth_ok' | 'auth_invalid';
}

type WSFrame = WSAuthFrame | WSResult;

interface WSClient {
  send: <T = unknown>(msg: object) => Promise<T>;
  close: () => void;
}

// ---------- config ----------

const TOKEN_FILE = path.join(process.env.HOME ?? '', '.ha-token.json');
const BASE = (process.env.HA_BASE ?? 'https://home.stromdahl.tech').replace(/\/+$/, '');
const WS_BASE = BASE.replace(/^http/, 'ws');

const FLAGS: Flags = { pretty: false, quiet: false, output: null };

// ---------- flag parsing ----------

function applyEqFlag(a: string): number {
  const eq = /^(?:--output|-o)=(.*)$/.exec(a);
  if (eq) { FLAGS.output = eq[1] ?? null; return 0; }
  return -1;
}

// Returns number of additional args consumed (0 or 1), or -1 if not a flag.
function applyFlag(a: string, next: string | undefined): number {
  if (a === '--pretty')               { FLAGS.pretty = true; return 0; }
  if (a === '--quiet' || a === '-q')  { FLAGS.quiet  = true; return 0; }
  if (a === '-o' || a === '--output') { FLAGS.output = next ?? null; return 1; }
  return applyEqFlag(a);
}

function parseArgs(argv: string[]): string[] {
  const positional: string[] = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    const adv = applyFlag(a, argv[i + 1]);
    if (adv < 0) positional.push(a);
    else i += adv;
  }
  return positional;
}

// ---------- auth & transport ----------

let TOKEN_CACHE: string | null = null;
function token(): string {
  if (TOKEN_CACHE !== null) return TOKEN_CACHE;
  const raw = fs.readFileSync(TOKEN_FILE, 'utf8');
  const j = JSON.parse(raw) as TokenFile;
  TOKEN_CACHE = j.headers.Authorization.replace(/^Bearer\s+/, '');
  return TOKEN_CACHE;
}

async function rest<T = unknown>(method: string, endpoint: string, body?: unknown): Promise<T> {
  const res = await fetch(`${BASE}/api${endpoint}`, {
    method,
    headers: {
      Authorization: 'Bearer ' + token(),
      'Content-Type': 'application/json',
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text}`);
  if (!text) return null as T;
  try { return JSON.parse(text) as T; }
  catch { return text as T; }
}

function makeWsClient(): WSClient {
  const ws = new WebSocket(`${WS_BASE}/api/websocket`);
  let nextId = 1;
  const pending = new Map<number, { res: (v: unknown) => void; rej: (e: Error) => void }>();
  let closed = false;
  const fail = (err: Error): void => {
    closed = true;
    for (const [, p] of pending) p.rej(err);
    pending.clear();
  };
  const ready = new Promise<void>((res, rej) => {
    ws.onmessage = (ev): void => {
      const m = JSON.parse(ev.data as string) as WSFrame;
      if (m.type === 'auth_required') { ws.send(JSON.stringify({ type: 'auth', access_token: token() })); return; }
      if (m.type === 'auth_ok') { res(); return; }
      if (m.type === 'auth_invalid') { closed = true; rej(new Error('auth_invalid')); return; }
      if (m.type === 'result') {
        const p = pending.get(m.id);
        if (!p) return;
        pending.delete(m.id);
        if (m.success) p.res(m.result);
        else p.rej(new Error(JSON.stringify(m.error)));
      }
    };
    ws.onerror = (e): void => {
      rej(new Error('WS ' + ('message' in e ? String((e as { message: unknown }).message) : 'error')));
      fail(new Error('WS error'));
    };
    ws.onclose = (): void => { fail(new Error('WS closed before result')); };
  });
  return {
    async send<T>(msg: object): Promise<T> {
      await ready;
      if (closed) throw new Error('WS closed');
      return new Promise<T>((res, rej) => {
        const id = nextId++;
        pending.set(id, { res: res as (v: unknown) => void, rej });
        ws.send(JSON.stringify({ ...msg, id }));
      });
    },
    close: () => { ws.close(); },
  };
}

async function withWs<T>(fn: (c: WSClient) => Promise<T>): Promise<T> {
  const c = makeWsClient();
  try { return await fn(c); }
  finally { c.close(); }
}

// ---------- formatting ----------

const STATE_NOISE: ReadonlySet<string> = new Set(['last_changed', 'last_reported', 'last_updated', 'context']);
function slim(s: HAState): HAStateSlim {
  return { entity_id: s.entity_id, state: s.state, attributes: s.attributes };
}

function pluck(obj: unknown, p: string): unknown {
  return p.split('.').reduce<unknown>(
    (o, k) => (o == null || typeof o !== 'object' ? undefined : (o as Record<string, unknown>)[k]),
    obj,
  );
}

function isPrimitive(v: unknown): v is string | number | boolean {
  return typeof v === 'string' || typeof v === 'number' || typeof v === 'boolean';
}

function formatValue(v: unknown): string {
  if (isPrimitive(v)) return String(v);
  return FLAGS.pretty ? JSON.stringify(v, null, 2) : JSON.stringify(v);
}

function printJSON(x: unknown): void {
  if (typeof x === 'string') { console.log(x); return; }
  const v = FLAGS.output !== null ? pluck(x, FLAGS.output) : x;
  if (v == null) return;
  console.log(formatValue(v));
}

function writeOrLog(file: string | undefined, data: unknown): void {
  if (file !== undefined) fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n');
  else printJSON(data);
}

function readJSON<T = unknown>(file: string): T {
  return JSON.parse(fs.readFileSync(file, 'utf8')) as T;
}

function say(msg: string): void {
  if (!FLAGS.quiet) console.log(msg);
}

// Glob (* ?) → RegExp. /…/ form is treated as raw regex.
function patternToRegex(pat: string): RegExp {
  if (pat.length >= 2 && pat.startsWith('/') && pat.endsWith('/')) return new RegExp(pat.slice(1, -1));
  const esc = pat.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\?/g, '.');
  return new RegExp('^' + esc + '$');
}

// ---------- subcommands ----------

const cmds: CmdTree = {
  state: async ([eid]: string[]): Promise<void> => {
    if (eid === undefined) throw new Error('usage: ha state <entity_id>');
    printJSON(slim(await rest<HAState>('GET', `/states/${eid}`)));
  },
  call: async ([service, dataJson]: string[]): Promise<void> => {
    if (service === undefined) throw new Error('usage: ha call <domain.service> [json]');
    const [domain, svc] = service.split('.', 2);
    const body: unknown = dataJson !== undefined ? JSON.parse(dataJson) : {};
    printJSON(await rest('POST', `/services/${domain}/${svc}`, body));
  },
  template: async ([tpl]: string[]): Promise<void> => {
    if (tpl === undefined) throw new Error('usage: ha template <jinja>');
    printJSON(await rest('POST', '/template', { template: tpl }));
  },
  ws: async ([json]: string[]): Promise<void> => {
    if (json === undefined) throw new Error('usage: ha ws <json-message>');
    const msg = JSON.parse(json) as object;
    await withWs(async (c) => { printJSON(await c.send(msg)); });
  },
  flow: async ([handler, ...stepArgs]: string[]): Promise<void> => {
    if (handler === undefined || stepArgs.length === 0) {
      throw new Error("usage: ha flow <handler> '<step1-json>' ['<step2-json>' ...]");
    }
    const steps: unknown[] = stepArgs.map((s, idx): unknown => {
      try { return JSON.parse(s) as unknown; }
      catch (e) { throw new Error(`step ${idx + 1} is not valid JSON: ${e instanceof Error ? e.message : String(e)}`); }
    });
    let resp = await rest<HAFlowResponse>('POST', '/config/config_entries/flow', { handler, show_advanced_options: false });
    for (let i = 0; i < steps.length; i++) {
      if (resp.type !== 'form') break;
      resp = await rest<HAFlowResponse>('POST', `/config/config_entries/flow/${resp.flow_id}`, steps[i]);
      if ('errors' in resp && resp.errors) throw new Error(`step ${i + 1} errors: ${JSON.stringify(resp.errors)}`);
    }
    if (resp.type === 'form') {
      throw new Error(`flow not finished — next step '${resp.step_id}' still needed. Schema:\n${JSON.stringify(resp.data_schema, null, 2)}`);
    }
    printJSON(resp);
  },
  entities: async ([pattern]: string[]): Promise<void> => {
    const states = await rest<HAState[]>('GET', '/states');
    const re = pattern !== undefined ? patternToRegex(pattern) : null;
    const rows = states
      .filter((s) => re === null || re.test(s.entity_id))
      .map((s) => {
        const fn = s.attributes.friendly_name;
        const dc = s.attributes.device_class;
        return `${s.entity_id}\t${s.state}\t${typeof fn === 'string' ? fn : '-'}\t${typeof dc === 'string' ? dc : '-'}`;
      })
      .sort();
    say('entity_id\tstate\tfriendly_name\tdevice_class');
    rows.forEach((r) => { console.log(r); });
  },
  services: async ([filter]: string[]): Promise<void> => {
    const list = await rest<HAServiceGroup[]>('GET', '/services');
    if (filter === undefined) {
      const out: string[] = [];
      for (const d of list) for (const s of Object.keys(d.services)) out.push(`${d.domain}.${s}`);
      out.sort();
      out.forEach((s) => { console.log(s); });
      return;
    }
    const [domain, svc] = filter.split('.', 2) as [string, string | undefined];
    const d = list.find((x) => x.domain === domain);
    if (!d) { console.error(`unknown domain: ${domain}`); process.exit(1); }
    if (svc === undefined) { printJSON(d.services); return; }
    if (!(svc in d.services)) { console.error(`unknown service: ${filter}`); process.exit(1); }
    printJSON(d.services[svc]);
  },

  dash: {
    list: async (): Promise<void> => {
      await withWs(async (c) => {
        const list = await c.send<HALovelaceListEntry[]>({ type: 'lovelace/dashboards/list' });
        list.forEach((d) => { console.log(`${d.url_path}\t${d.title}\t${d.icon ?? ''}`); });
      });
    },
    get: async ([urlPath, file]: string[]): Promise<void> => {
      if (urlPath === undefined) throw new Error('usage: ha dash get <url_path> [file]');
      await withWs(async (c) => {
        const cfg = await c.send({ type: 'lovelace/config', url_path: urlPath });
        writeOrLog(file, cfg);
      });
    },
    save: async ([urlPath, file]: string[]): Promise<void> => {
      if (urlPath === undefined || file === undefined) throw new Error('usage: ha dash save <url_path> <file>');
      const cfg = readJSON(file);
      await withWs(async (c) => {
        await c.send({ type: 'lovelace/config/save', url_path: urlPath, config: cfg });
        say('saved');
      });
    },
  },

  auto: {
    list: async (): Promise<void> => {
      const states = await rest<HAState[]>('GET', '/states');
      states
        .filter((s) => s.entity_id.startsWith('automation.'))
        .sort((a, b) => a.entity_id.localeCompare(b.entity_id))
        .forEach((s) => {
          const id = s.attributes.id;
          const fn = s.attributes.friendly_name;
          const idStr = typeof id === 'string' ? id : s.entity_id.replace('automation.', '');
          const fnStr = typeof fn === 'string' ? fn : '-';
          console.log(`${idStr}\t${fnStr}\t[${s.state}]`);
        });
    },
    get: async ([id, file]: string[]): Promise<void> => {
      if (id === undefined) throw new Error('usage: ha auto get <id> [file]');
      writeOrLog(file, await rest('GET', `/config/automation/config/${id}`));
    },
    save: async ([id, file]: string[]): Promise<void> => {
      if (id === undefined || file === undefined) throw new Error('usage: ha auto save <id> <file>');
      const cfg = readJSON(file);
      await rest('POST', `/config/automation/config/${id}`, cfg);
      await rest('POST', '/services/automation/reload');
      say('saved + reloaded');
    },
    delete: async ([id]: string[]): Promise<void> => {
      if (id === undefined) throw new Error('usage: ha auto delete <id>');
      await rest('DELETE', `/config/automation/config/${id}`);
      say('deleted');
    },
  },

  scene: {
    list: async (): Promise<void> => {
      const states = await rest<HAState[]>('GET', '/states');
      states
        .filter((s) => s.entity_id.startsWith('scene.'))
        .sort((a, b) => a.entity_id.localeCompare(b.entity_id))
        .forEach((s) => {
          const id = s.attributes.id;
          const fn = s.attributes.friendly_name;
          const idStr = typeof id === 'string' ? id : s.entity_id.replace('scene.', '');
          const fnStr = typeof fn === 'string' ? fn : '-';
          console.log(`${idStr}\t${fnStr}`);
        });
    },
    get: async ([id, file]: string[]): Promise<void> => {
      if (id === undefined) throw new Error('usage: ha scene get <id> [file]');
      writeOrLog(file, await rest('GET', `/config/scene/config/${id}`));
    },
    save: async ([id, file]: string[]): Promise<void> => {
      if (id === undefined || file === undefined) throw new Error('usage: ha scene save <id> <file>');
      const cfg = readJSON(file);
      await rest('POST', `/config/scene/config/${id}`, cfg);
      await rest('POST', '/services/scene/reload');
      say('saved + reloaded');
    },
    delete: async ([id]: string[]): Promise<void> => {
      if (id === undefined) throw new Error('usage: ha scene delete <id>');
      await rest('DELETE', `/config/scene/config/${id}`);
      say('deleted');
    },
  },

  entity: {
    list: async (): Promise<void> => {
      await withWs(async (c) => {
        const list = await c.send<HAEntityRegistryEntry[]>({ type: 'config/entity_registry/list' });
        list
          .sort((a, b) => a.entity_id.localeCompare(b.entity_id))
          .forEach((e) => {
            console.log([
              e.entity_id,
              e.name ?? e.original_name ?? '-',
              e.area_id ?? '-',
              e.device_id ?? '-',
              e.disabled_by ?? '',
              e.hidden_by ?? '',
            ].join('\t'));
          });
      });
    },
    get: async ([eid]: string[]): Promise<void> => {
      if (eid === undefined) throw new Error('usage: ha entity get <entity_id>');
      await withWs(async (c) => { printJSON(await c.send({ type: 'config/entity_registry/get', entity_id: eid })); });
    },
    update: async ([eid, json]: string[]): Promise<void> => {
      if (eid === undefined || json === undefined) {
        throw new Error('usage: ha entity update <entity_id> <json>  (e.g. {"name":"...","area_id":"...","new_entity_id":"..."})');
      }
      const payload = JSON.parse(json) as object;
      await withWs(async (c) => { printJSON(await c.send({ type: 'config/entity_registry/update', entity_id: eid, ...payload })); });
    },
    remove: async ([eid]: string[]): Promise<void> => {
      if (eid === undefined) throw new Error('usage: ha entity remove <entity_id>');
      await withWs(async (c) => { printJSON(await c.send({ type: 'config/entity_registry/remove', entity_id: eid })); });
    },
    disable: async ([eid]: string[]): Promise<void> => {
      if (eid === undefined) throw new Error('usage: ha entity disable <entity_id>');
      await withWs(async (c) => { printJSON(await c.send({ type: 'config/entity_registry/update', entity_id: eid, disabled_by: 'user' })); });
    },
    enable: async ([eid]: string[]): Promise<void> => {
      if (eid === undefined) throw new Error('usage: ha entity enable <entity_id>');
      await withWs(async (c) => { printJSON(await c.send({ type: 'config/entity_registry/update', entity_id: eid, disabled_by: null })); });
    },
  },

  device: {
    list: async (): Promise<void> => {
      await withWs(async (c) => {
        const list = await c.send<HADeviceRegistryEntry[]>({ type: 'config/device_registry/list' });
        list
          .sort((a, b) => (a.area_id ?? '').localeCompare(b.area_id ?? '') || a.id.localeCompare(b.id))
          .forEach((d) => { console.log(`${d.id}\t${d.area_id ?? '-'}\t${d.name_by_user ?? d.name ?? '-'}\t${d.model ?? '-'}`); });
      });
    },
    update: async ([deviceId, json]: string[]): Promise<void> => {
      if (deviceId === undefined || json === undefined) throw new Error('usage: ha device update <device_id> <json>');
      const payload = JSON.parse(json) as object;
      await withWs(async (c) => { printJSON(await c.send({ type: 'config/device_registry/update', device_id: deviceId, ...payload })); });
    },
  },

  area: {
    list: async (): Promise<void> => {
      await withWs(async (c) => {
        const list = await c.send<HAAreaRegistryEntry[]>({ type: 'config/area_registry/list' });
        list
          .sort((a, b) => a.area_id.localeCompare(b.area_id))
          .forEach((a) => { console.log(`${a.area_id}\t${a.name}\t${a.icon ?? '-'}`); });
      });
    },
    create: async ([json]: string[]): Promise<void> => {
      if (json === undefined) throw new Error('usage: ha area create <json>  (e.g. {"name":"Fridge","icon":"mdi:fridge"})');
      const payload = JSON.parse(json) as object;
      await withWs(async (c) => { printJSON(await c.send({ type: 'config/area_registry/create', ...payload })); });
    },
    delete: async ([areaId]: string[]): Promise<void> => {
      if (areaId === undefined) throw new Error('usage: ha area delete <area_id>');
      await withWs(async (c) => { printJSON(await c.send({ type: 'config/area_registry/delete', area_id: areaId })); });
    },
  },

  entry: {
    list: async ([domainFilter]: string[]): Promise<void> => {
      let list = await rest<HAConfigEntry[]>('GET', '/config/config_entries/entry');
      if (domainFilter !== undefined) list = list.filter((e) => e.domain === domainFilter);
      list.sort((a, b) => (a.domain).localeCompare(b.domain) || (a.title ?? '').localeCompare(b.title ?? ''));
      list.forEach((e) => { console.log(`${e.entry_id}\t${e.domain}\t${e.title ?? '-'}\t${e.state}\t${e.source ?? '-'}`); });
    },
    get: async ([entryId]: string[]): Promise<void> => {
      if (entryId === undefined) throw new Error('usage: ha entry get <entry_id>');
      const list = await rest<HAConfigEntry[]>('GET', '/config/config_entries/entry');
      const e = list.find((x) => x.entry_id === entryId);
      if (!e) { console.error(`unknown entry: ${entryId}`); process.exit(1); }
      printJSON(e);
    },
    delete: async ([entryId]: string[]): Promise<void> => {
      if (entryId === undefined) throw new Error('usage: ha entry delete <entry_id>');
      printJSON(await rest('DELETE', `/config/config_entries/entry/${entryId}`));
    },
    reload: async ([entryId]: string[]): Promise<void> => {
      if (entryId === undefined) throw new Error('usage: ha entry reload <entry_id>');
      printJSON(await rest('POST', `/config/config_entries/entry/${entryId}/reload`));
    },
    flows: async (): Promise<void> => {
      await withWs(async (c) => { printJSON(await c.send({ type: 'config_entries/flow/progress' })); });
    },
  },

  helper: {
    list: async (): Promise<void> => {
      const states = await rest<HAState[]>('GET', '/states');
      const HELPER_PREFIXES = ['input_number.', 'input_boolean.', 'input_button.', 'input_text.', 'input_select.', 'input_datetime.'];
      states
        .filter((s) => HELPER_PREFIXES.some((p) => s.entity_id.startsWith(p)))
        .sort((a, b) => a.entity_id.localeCompare(b.entity_id))
        .forEach((s) => {
          const fn = s.attributes.friendly_name;
          console.log(`${s.entity_id}\t${s.state}\t${typeof fn === 'string' ? fn : '-'}`);
        });
    },
    create: async ([type, json]: string[]): Promise<void> => {
      if (type === undefined || json === undefined) throw new Error('usage: ha helper create <type> <json>  (type: input_number, input_button, ...)');
      const payload = JSON.parse(json) as object;
      await withWs(async (c) => { printJSON(await c.send({ type: `${type}/create`, ...payload })); });
    },
    delete: async ([type, id]: string[]): Promise<void> => {
      if (type === undefined || id === undefined) throw new Error('usage: ha helper delete <type> <id>');
      await withWs(async (c) => { printJSON(await c.send({ type: `${type}/delete`, [`${type}_id`]: id })); });
    },
  },
};

// ---------- dispatcher ----------

function isCmdNode(x: CmdFn | CmdTree | undefined): x is CmdTree {
  return typeof x === 'object' && x !== null;
}

function walkCmd(argv: string[]): WalkResult {
  let node: CmdTree = cmds;
  let i = 0;
  while (i < argv.length) {
    const key = argv[i]!;
    const next = node[key];
    if (typeof next === 'function') return { fn: next, rest: argv.slice(i + 1) };
    if (!isCmdNode(next)) return { node, i };
    node = next;
    i++;
  }
  return { node, i };
}

function reportUnknown(argv: string[], node: CmdTree, i: number): never {
  if (i > 0) {
    const prefix = `ha ${argv.slice(0, i).join(' ')}`;
    const avail = Object.keys(node).join(', ');
    const msg = i < argv.length
      ? `${prefix}: unknown sub-verb '${argv[i] ?? ''}'. Available: ${avail}`
      : `${prefix}: subcommand required. Available: ${avail}`;
    console.error(msg);
  } else {
    console.error(`unknown command: ${argv.join(' ')}`);
  }
  process.exit(2);
}

async function main(): Promise<void> {
  const argv = parseArgs(process.argv.slice(2));
  if (argv.length === 0) {
    console.log('ha — Home Assistant CLI. See top of script for usage.');
    process.exit(0);
  }
  const result = walkCmd(argv);
  if (result.fn) { await result.fn(result.rest); return; }
  reportUnknown(argv, result.node, result.i);
}

main().catch((e: unknown) => {
  console.error(e instanceof Error ? e.message : String(e));
  process.exit(1);
});

// Suppress unused-warning for the bookkeeping constant that documents which
// fields slim() strips. (Kept as a hint for future refactors.)
void STATE_NOISE;

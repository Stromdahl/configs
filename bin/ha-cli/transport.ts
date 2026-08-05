import * as fs from 'node:fs';
import * as path from 'node:path';

import type { TokenFile, WSClient, WSFrame } from './types.ts';

const TOKEN_FILE = path.join(process.env.HOME ?? '', '.ha-token.json');
// HA answers on both home.stromdahl.tech and ha.home.stromdahl.tech. The default
// stays on the ha.* name on purpose: the public Cloudflare record is a wildcard,
// which does not match the apex, so only ha.* resolves while roaming.
const BASE = (process.env.HA_BASE ?? 'https://ha.home.stromdahl.tech').replace(/\/+$/, '');
const WS_BASE = BASE.replace(/^http/, 'ws');

let TOKEN_CACHE: string | null = null;
function token(): string {
  if (TOKEN_CACHE !== null) return TOKEN_CACHE;
  const raw = fs.readFileSync(TOKEN_FILE, 'utf8');
  const j = JSON.parse(raw) as TokenFile;
  TOKEN_CACHE = j.headers.Authorization.replace(/^Bearer\s+/, '');
  return TOKEN_CACHE;
}

export async function rest<T = unknown>(method: string, endpoint: string, body?: unknown): Promise<T> {
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

// Method-specific REST shortcuts. `del` because `delete` is a JS reserved word.
export function get<T = unknown>(endpoint: string): Promise<T> {
  return rest<T>('GET', endpoint);
}

export function post<T = unknown>(endpoint: string, body?: unknown): Promise<T> {
  return rest<T>('POST', endpoint, body);
}

export function del<T = unknown>(endpoint: string): Promise<T> {
  return rest<T>('DELETE', endpoint);
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

export async function withWs<T>(fn: (c: WSClient) => Promise<T>): Promise<T> {
  const c = makeWsClient();
  try { return await fn(c); }
  finally { c.close(); }
}

// Convenience: one-shot WS round-trip. Opens a connection, sends `msg`, waits
// for the result, closes. For multi-message sessions on the same socket, use
// `withWs` directly.
export function wsCall<T = unknown>(msg: object): Promise<T> {
  return withWs<T>((c) => c.send<T>(msg));
}

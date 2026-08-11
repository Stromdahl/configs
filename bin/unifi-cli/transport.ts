import * as fs from 'node:fs';
import * as https from 'node:https';
import * as path from 'node:path';

import type { Page, TokenFile } from './types.ts';

const TOKEN_FILE = path.join(process.env.HOME ?? '', '.unifi-token.json');
// The controller's cert is self-signed and CNs to the UDM's own hostname,
// never "10.0.0.1" — so trusting the CA (NODE_EXTRA_CA_CERTS) still fails
// hostname verification. `rejectUnauthorized: false` scoped to this one
// https.Agent is the honest way to talk to it, kept out of Node's global
// fetch/undici path entirely (no process-wide NODE_TLS_REJECT_UNAUTHORIZED).
const INSECURE_AGENT = new https.Agent({ rejectUnauthorized: false });
export const API_PREFIX = '/proxy/network/integration';

let CREDS_CACHE: TokenFile | null = null;
function creds(): TokenFile {
  if (CREDS_CACHE !== null) return CREDS_CACHE;
  const raw = fs.readFileSync(TOKEN_FILE, 'utf8');
  CREDS_CACHE = JSON.parse(raw) as TokenFile;
  return CREDS_CACHE;
}

function baseUrl(): string {
  return (process.env.UNIFI_BASE ?? creds().baseUrl ?? 'https://10.0.0.1').replace(/\/+$/, '');
}

export function siteId(): string {
  const s = process.env.UNIFI_SITE ?? creds().siteId;
  if (s === undefined) throw new Error('no siteId — set "siteId" in ~/.unifi-token.json or export UNIFI_SITE');
  return s;
}

function rawRequest<T>(method: string, url: string, body?: unknown): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const req = https.request(url, {
      method,
      agent: INSECURE_AGENT,
      headers: {
        'X-API-KEY': creds().apiKey,
        'Content-Type': 'application/json',
      },
    }, (res) => {
      let data = '';
      res.on('data', (chunk: Buffer) => { data += chunk.toString('utf8'); });
      res.on('end', () => {
        const status = res.statusCode ?? 0;
        if (status < 200 || status >= 300) { reject(new Error(`HTTP ${status}: ${data}`)); return; }
        if (data === '') { resolve(null as T); return; }
        try { resolve(JSON.parse(data) as T); }
        catch { resolve(data as T); }
      });
    });
    req.on('error', reject);
    if (body !== undefined) req.write(JSON.stringify(body));
    req.end();
  });
}

export function rest<T = unknown>(method: string, endpoint: string, body?: unknown): Promise<T> {
  return rawRequest<T>(method, `${baseUrl()}${endpoint}`, body);
}

export function get<T = unknown>(endpoint: string): Promise<T> {
  return rest<T>('GET', endpoint);
}

export function post<T = unknown>(endpoint: string, body?: unknown): Promise<T> {
  return rest<T>('POST', endpoint, body);
}

export function put<T = unknown>(endpoint: string, body?: unknown): Promise<T> {
  return rest<T>('PUT', endpoint, body);
}

export function patch<T = unknown>(endpoint: string, body?: unknown): Promise<T> {
  return rest<T>('PATCH', endpoint, body);
}

export function del<T = unknown>(endpoint: string): Promise<T> {
  return rest<T>('DELETE', endpoint);
}

// Site-scoped path (the vast majority of endpoints) vs. the handful under
// plain /v1/... (sites, info, dpi/*, countries, pending-devices).
export function sitePath(p: string): string {
  return `${API_PREFIX}/v1/sites/${siteId()}/${p}`;
}

export function v1Path(p: string): string {
  return `${API_PREFIX}/v1/${p}`;
}

// Every collection endpoint returns {offset, limit, count, totalCount, data}
// capped at limit<=200 per page. Loop until the full collection is fetched —
// a transport that stopped at page 1 would silently show 25 clients on a
// 60-client network and look complete.
export async function listAll<T>(basePath: string, filter?: string): Promise<T[]> {
  const out: T[] = [];
  let offset = 0;
  for (;;) {
    const qs = new URLSearchParams({ offset: String(offset), limit: '200' });
    if (filter !== undefined) qs.set('filter', filter);
    const page = await get<Page<T>>(`${basePath}?${qs.toString()}`);
    out.push(...page.data);
    offset += page.data.length;
    if (page.data.length === 0 || offset >= page.totalCount) break;
  }
  return out;
}

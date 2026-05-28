import * as fs from 'node:fs';

import { FLAGS } from './flags.ts';
import type { HAState, HAStateSlim } from './types.ts';

// Drops HA's noisy top-level state fields (last_changed, last_reported,
// last_updated, context) — pure overhead in transcripts.
export function slim(s: HAState): HAStateSlim {
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

export function printJSON(x: unknown): void {
  if (typeof x === 'string') { console.log(x); return; }
  const v = FLAGS.output !== null ? pluck(x, FLAGS.output) : x;
  if (v == null) return;
  console.log(formatValue(v));
}

export function writeOrLog(file: string | undefined, data: unknown): void {
  if (file !== undefined) fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n');
  else printJSON(data);
}

export function readJSON<T = unknown>(file: string): T {
  return JSON.parse(fs.readFileSync(file, 'utf8')) as T;
}

export function say(msg: string): void {
  if (!FLAGS.quiet) console.log(msg);
}

// Glob (* ?) → RegExp. /…/ form is treated as raw regex.
export function patternToRegex(pat: string): RegExp {
  if (pat.length >= 2 && pat.startsWith('/') && pat.endsWith('/')) return new RegExp(pat.slice(1, -1));
  const esc = pat.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*').replace(/\?/g, '.');
  return new RegExp('^' + esc + '$');
}

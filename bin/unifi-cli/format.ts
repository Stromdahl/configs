import * as fs from 'node:fs';

import { FLAGS } from './flags.ts';

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

export function readJSON<T = unknown>(file: string): T {
  return JSON.parse(fs.readFileSync(file, 'utf8')) as T;
}

export function say(msg: string): void {
  if (!FLAGS.quiet) console.log(msg);
}

// Gate for actions with real infrastructure blast radius (device restart,
// port power-cycle) — require --yes, otherwise print what would happen and
// exit without doing it.
export function confirm(msg: string): void {
  if (FLAGS.yes) return;
  console.error(`${msg} — re-run with --yes to actually do this.`);
  process.exit(1);
}

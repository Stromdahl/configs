import type { Flags } from './types.ts';

export const FLAGS: Flags = { pretty: false, quiet: false, help: false, output: null };

function applyEqFlag(a: string): number {
  const eq = /^(?:--output|-o)=(.*)$/.exec(a);
  if (eq) { FLAGS.output = eq[1] ?? null; return 0; }
  return -1;
}

// Each handler returns the number of additional args consumed (0 or 1).
const FLAG_HANDLERS = new Map<string, (next: string | undefined) => number>([
  ['--help',   () => { FLAGS.help   = true; return 0; }],
  ['-h',       () => { FLAGS.help   = true; return 0; }],
  ['--pretty', () => { FLAGS.pretty = true; return 0; }],
  ['--quiet',  () => { FLAGS.quiet  = true; return 0; }],
  ['-q',       () => { FLAGS.quiet  = true; return 0; }],
  ['-o',       (n) => { FLAGS.output = n ?? null; return 1; }],
  ['--output', (n) => { FLAGS.output = n ?? null; return 1; }],
]);

// Returns number of additional args consumed (0 or 1), or -1 if not a flag.
function applyFlag(a: string, next: string | undefined): number {
  const h = FLAG_HANDLERS.get(a);
  if (h) return h(next);
  return applyEqFlag(a);
}

export function parseArgs(argv: string[]): string[] {
  const positional: string[] = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i]!;
    const adv = applyFlag(a, argv[i + 1]);
    if (adv < 0) positional.push(a);
    else i += adv;
  }
  return positional;
}

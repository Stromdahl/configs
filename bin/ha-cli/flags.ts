import type { Flags } from './types.ts';

export const FLAGS: Flags = { pretty: false, quiet: false, output: null };

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

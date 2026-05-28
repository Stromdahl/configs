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

import { area } from './commands/area.ts';
import { auto } from './commands/auto.ts';
import { call, entities, flow, services, state, template, ws } from './commands/core.ts';
import { dash } from './commands/dash.ts';
import { device } from './commands/device.ts';
import { entity } from './commands/entity.ts';
import { entry } from './commands/entry.ts';
import { helper } from './commands/helper.ts';
import { scene } from './commands/scene.ts';
import { parseArgs } from './flags.ts';
import type { CmdFn, CmdTree, WalkResult } from './types.ts';

const cmds: CmdTree = {
  state, call, template, ws, flow, entities, services,
  dash, auto, scene, entity, device, area, entry, helper,
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

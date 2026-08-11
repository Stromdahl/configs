#!/usr/bin/env node
// unifi — small CLI for poking the UniFi Network Integration API on the
// Sensative office UDM Pro SE (10.0.0.1).
// Run `unifi --help` (or `unifi` with no args) to print the USAGE block below.

import { acl } from './commands/acl.ts';
import { client } from './commands/client.ts';
import { info, raw, site } from './commands/core.ts';
import { device } from './commands/device.ts';
import { dns } from './commands/dns.ts';
import { firewall } from './commands/firewall.ts';
import { country, dpi, radius, tag } from './commands/misc.ts';
import { network } from './commands/network.ts';
import { switching } from './commands/switching.ts';
import { tml } from './commands/tml.ts';
import { voucher } from './commands/voucher.ts';
import { vpn } from './commands/vpn.ts';
import { wan } from './commands/wan.ts';
import { wifi } from './commands/wifi.ts';
import { FLAGS, parseArgs } from './flags.ts';
import type { CmdFn, CmdTree, WalkResult } from './types.ts';

const USAGE = `\
unifi — small CLI for poking the UniFi Network Integration API.

Sites:
  unifi site list                              sites this controller manages
  unifi site current                           the siteId this CLI is using
  unifi info                                    GET /v1/info (controller version etc.)

Devices (gateway, switches, APs):
  unifi device list [filter]
  unifi device get <device_id>
  unifi device stats <device_id>               latest interface/radio statistics
  unifi device pending                         devices awaiting adoption
  unifi device adopt '<json>'                  {"macAddress":"...","ignoreDeviceLimit":false}
  unifi device delete <device_id>              forget/unadopt
  unifi device restart <device_id> --yes       drops the site if it's the gateway
  unifi device cycle-port <device_id> <port_idx> --yes

Clients:
  unifi client list [filter]
  unifi client get <client_id>
  unifi client authorize <client_id> ['<json>']    guest network access; json e.g. {"timeLimitMinutes":60}
  unifi client unauthorize <client_id>             disconnect + revoke guest access

Networks (VLANs):
  unifi network list [filter]
  unifi network get <network_id>
  unifi network refs <network_id>              what else references it — check before delete
  unifi network create '<json>'
  unifi network update <network_id> '<json>'   PUT replaces the whole network — GET+merge first
  unifi network delete <network_id>

WANs (read-only):
  unifi wan list [filter]

Wi-Fi broadcasts (SSIDs):
  unifi wifi list [filter]
  unifi wifi get <broadcast_id>
  unifi wifi create '<json>'
  unifi wifi update <broadcast_id> '<json>'    PUT replaces the whole SSID config
  unifi wifi delete <broadcast_id>

Firewall (only if zone-based firewall is enabled on the site):
  unifi firewall zone list|get|create|update|delete [id] ['<json>']
  unifi firewall policy list|get|create|update|patch|delete [id] ['<json>']
  unifi firewall policy order get
  unifi firewall policy order set '<json>'     ordered array of policy IDs

ACL rules (legacy per-network firewall rules):
  unifi acl list|get|create|update|delete [id] ['<json>']
  unifi acl order get
  unifi acl order set '<json>'                 ordered array of rule IDs

DNS policies:
  unifi dns list|get|create|update|delete [id] ['<json>']

Traffic-matching lists (reusable filters for firewall policies):
  unifi tml list|get|create|update|delete [id] ['<json>']

Hotspot vouchers:
  unifi voucher list|get|delete [id]
  unifi voucher create '<json>'                {"count":1,"name":"...","timeLimitMinutes":1440}
  unifi voucher delete-filter <filter>         bulk delete matching vouchers

VPN (read-only):
  unifi vpn server list [filter]
  unifi vpn tunnel list [filter]               site-to-site tunnels

Switching (read-only):
  unifi switching stack list|get [id]          switch stacks
  unifi switching mclag list|get [id]          MC-LAG domains
  unifi switching lag list|get [id]

Reference data (read-only):
  unifi tag list [filter]                      device tags
  unifi radius list [filter]                   RADIUS profiles
  unifi dpi categories|applications [filter]
  unifi country list [filter]

Raw:
  unifi raw <METHOD> <path> ['<json>']         path e.g. /v1/sites/current/devices
                                               ("current" resolves to the configured siteId)

Global flags (any position):
  --help, -h                                   print this message
  --pretty                                     pretty-print JSON output (default: compact, single-line)
  --quiet, -q                                  silence chatter on writes
  --yes, -y                                    required by actions with real blast radius
                                               (device restart, port cycle)
  -o <key.path>, --output <key.path>           extract a field from JSON output

Env:
  UNIFI_BASE                                   override the controller host (default https://10.0.0.1)
  UNIFI_SITE                                   override the siteId (default: from the token file)

Auth: reads {apiKey, baseUrl?, siteId?} from ~/.unifi-token.json. Mint the key in
UniFi OS → Settings → Control Plane → Integrations.
`;

const cmds: CmdTree = {
  site, info, raw,
  device, client, network, wan, wifi,
  firewall, acl, dns, tml, voucher,
  vpn, switching,
  tag, radius, dpi, country,
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
    const prefix = `unifi ${argv.slice(0, i).join(' ')}`;
    const avail = Object.keys(node).join(', ');
    const msg = i < argv.length
      ? `${prefix}: unknown sub-verb '${argv[i] ?? ''}'. Available: ${avail}`
      : `${prefix}: subcommand required. Available: ${avail}`;
    console.error(msg);
  } else {
    console.error(`unknown command: ${argv.join(' ')}`);
  }
  console.error("Run 'unifi --help' for usage.");
  process.exit(2);
}

async function main(): Promise<void> {
  const argv = parseArgs(process.argv.slice(2));
  if (FLAGS.help || argv.length === 0) {
    console.log(USAGE);
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

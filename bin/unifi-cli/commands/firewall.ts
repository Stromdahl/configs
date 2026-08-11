import {
  createFirewallPolicy,
  createFirewallZone,
  deleteFirewallPolicy,
  deleteFirewallZone,
  getFirewallPolicy,
  getFirewallPolicyOrder,
  getFirewallZone,
  listFirewallPolicies,
  listFirewallZones,
  patchFirewallPolicy,
  setFirewallPolicyOrder,
  updateFirewallPolicy,
  updateFirewallZone,
} from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

// Zone-based firewall is opt-in per site — a site still on the legacy rule
// model answers every one of these with a 400
// "api.firewall.zone-based-firewall-not-configured", not an empty list.

const zone: CmdTree = {
  list: async ([filter]) => { printJSON(await listFirewallZones(filter)); },
  get: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi firewall zone get <zone_id>');
    printJSON(await getFirewallZone(id));
  },
  create: async ([json]) => {
    if (json === undefined) throw new Error('usage: unifi firewall zone create <json>');
    printJSON(await createFirewallZone(JSON.parse(json) as object));
  },
  update: async ([id, json]) => {
    if (id === undefined || json === undefined) throw new Error('usage: unifi firewall zone update <zone_id> <json>  (PUT replaces the whole zone)');
    printJSON(await updateFirewallZone(id, JSON.parse(json) as object));
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi firewall zone delete <zone_id>');
    printJSON(await deleteFirewallZone(id));
  },
};

const policy: CmdTree = {
  list: async ([filter]) => { printJSON(await listFirewallPolicies(filter)); },
  get: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi firewall policy get <policy_id>');
    printJSON(await getFirewallPolicy(id));
  },
  create: async ([json]) => {
    if (json === undefined) throw new Error('usage: unifi firewall policy create <json>');
    printJSON(await createFirewallPolicy(JSON.parse(json) as object));
  },
  update: async ([id, json]) => {
    if (id === undefined || json === undefined) throw new Error('usage: unifi firewall policy update <policy_id> <json>  (PUT replaces the whole policy; use patch for a partial edit)');
    printJSON(await updateFirewallPolicy(id, JSON.parse(json) as object));
  },
  patch: async ([id, json]) => {
    if (id === undefined || json === undefined) throw new Error('usage: unifi firewall policy patch <policy_id> <json>');
    printJSON(await patchFirewallPolicy(id, JSON.parse(json) as object));
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi firewall policy delete <policy_id>');
    printJSON(await deleteFirewallPolicy(id));
  },
  order: {
    get: async () => { printJSON(await getFirewallPolicyOrder()); },
    set: async ([json]) => {
      if (json === undefined) throw new Error('usage: unifi firewall policy order set <json>  (ordered array of policy IDs)');
      printJSON(await setFirewallPolicyOrder(JSON.parse(json) as object));
    },
  },
};

export const firewall: CmdTree = { zone, policy };

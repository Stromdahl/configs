import { createDnsPolicy, deleteDnsPolicy, getDnsPolicy, listDnsPolicies, updateDnsPolicy } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const dns: CmdTree = {
  list: async ([filter]) => { printJSON(await listDnsPolicies(filter)); },
  get: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi dns get <policy_id>');
    printJSON(await getDnsPolicy(id));
  },
  create: async ([json]) => {
    if (json === undefined) throw new Error('usage: unifi dns create <json>');
    printJSON(await createDnsPolicy(JSON.parse(json) as object));
  },
  update: async ([id, json]) => {
    if (id === undefined || json === undefined) throw new Error('usage: unifi dns update <policy_id> <json>');
    printJSON(await updateDnsPolicy(id, JSON.parse(json) as object));
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi dns delete <policy_id>');
    printJSON(await deleteDnsPolicy(id));
  },
};

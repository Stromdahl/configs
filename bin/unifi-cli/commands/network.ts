import { createNetwork, deleteNetwork, getNetwork, getNetworkReferences, listNetworks, updateNetwork } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const network: CmdTree = {
  list: async ([filter]) => {
    const list = await listNetworks(filter);
    list
      .sort((a, b) => (a.vlanId ?? 0) - (b.vlanId ?? 0))
      .forEach((n) => { console.log(`${n.id}\t${n.name}\t${n.vlanId ?? '-'}\t${n.enabled ? 'enabled' : 'disabled'}\t${n.default ? 'default' : ''}`); });
  },
  get: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi network get <network_id>');
    printJSON(await getNetwork(id));
  },
  refs: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi network refs <network_id>  (what else references this network — check before delete)');
    printJSON(await getNetworkReferences(id));
  },
  create: async ([json]) => {
    if (json === undefined) throw new Error('usage: unifi network create <json>');
    printJSON(await createNetwork(JSON.parse(json) as object));
  },
  update: async ([id, json]) => {
    if (id === undefined || json === undefined) {
      throw new Error('usage: unifi network update <network_id> <json>  (PUT replaces the whole network — GET first and merge, or you will wipe config you didn\'t mean to touch)');
    }
    printJSON(await updateNetwork(id, JSON.parse(json) as object));
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi network delete <network_id>  (run `unifi network refs <id>` first)');
    printJSON(await deleteNetwork(id));
  },
};

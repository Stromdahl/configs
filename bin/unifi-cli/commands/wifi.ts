import { createWifiBroadcast, deleteWifiBroadcast, getWifiBroadcast, listWifiBroadcasts, updateWifiBroadcast } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const wifi: CmdTree = {
  list: async ([filter]) => {
    const list = await listWifiBroadcasts(filter);
    list.forEach((w) => { console.log(`${w.id}\t${w.name}\t${w.type}\t${w.enabled ? 'enabled' : 'disabled'}`); });
  },
  get: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi wifi get <broadcast_id>');
    printJSON(await getWifiBroadcast(id));
  },
  create: async ([json]) => {
    if (json === undefined) throw new Error('usage: unifi wifi create <json>');
    printJSON(await createWifiBroadcast(JSON.parse(json) as object));
  },
  update: async ([id, json]) => {
    if (id === undefined || json === undefined) {
      throw new Error('usage: unifi wifi update <broadcast_id> <json>  (PUT replaces the whole SSID config — GET first and merge)');
    }
    printJSON(await updateWifiBroadcast(id, JSON.parse(json) as object));
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi wifi delete <broadcast_id>');
    printJSON(await deleteWifiBroadcast(id));
  },
};

import { authorizeGuest, getClient, listClients, unauthorizeGuest } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const client: CmdTree = {
  list: async ([filter]) => {
    const list = await listClients(filter);
    list
      .sort((a, b) => (a.name ?? a.macAddress).localeCompare(b.name ?? b.macAddress))
      .forEach((c) => { console.log(`${c.id}\t${c.name ?? '-'}\t${c.type}\t${c.ipAddress ?? '-'}\t${c.macAddress}\t${c.connectedAt ?? '-'}`); });
  },
  get: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi client get <client_id>');
    printJSON(await getClient(id));
  },
  authorize: async ([id, json]) => {
    if (id === undefined) throw new Error('usage: unifi client authorize <client_id> [\'<json>\']  (e.g. {"timeLimitMinutes":60})');
    printJSON(await authorizeGuest(id, json !== undefined ? JSON.parse(json) as object : undefined));
  },
  unauthorize: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi client unauthorize <client_id>');
    printJSON(await unauthorizeGuest(id));
  },
};

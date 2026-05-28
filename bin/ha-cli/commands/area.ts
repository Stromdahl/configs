import { printJSON } from '../format.ts';
import { withWs } from '../transport.ts';
import type { CmdTree, HAAreaRegistryEntry } from '../types.ts';

export const area: CmdTree = {
  list: async () => {
    await withWs(async (c) => {
      const list = await c.send<HAAreaRegistryEntry[]>({ type: 'config/area_registry/list' });
      list
        .sort((a, b) => a.area_id.localeCompare(b.area_id))
        .forEach((a) => { console.log(`${a.area_id}\t${a.name}\t${a.icon ?? '-'}`); });
    });
  },
  create: async ([json]) => {
    if (json === undefined) throw new Error('usage: ha area create <json>  (e.g. {"name":"Fridge","icon":"mdi:fridge"})');
    const payload = JSON.parse(json) as object;
    await withWs(async (c) => { printJSON(await c.send({ type: 'config/area_registry/create', ...payload })); });
  },
  delete: async ([areaId]) => {
    if (areaId === undefined) throw new Error('usage: ha area delete <area_id>');
    await withWs(async (c) => { printJSON(await c.send({ type: 'config/area_registry/delete', area_id: areaId })); });
  },
};

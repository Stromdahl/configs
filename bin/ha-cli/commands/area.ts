import { createArea, deleteArea, listAreas } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const area: CmdTree = {
  list: async () => {
    const list = await listAreas();
    list
      .sort((a, b) => a.area_id.localeCompare(b.area_id))
      .forEach((a) => { console.log(`${a.area_id}\t${a.name}\t${a.icon ?? '-'}`); });
  },
  create: async ([json]) => {
    if (json === undefined) throw new Error('usage: ha area create <json>  (e.g. {"name":"Fridge","icon":"mdi:fridge"})');
    printJSON(await createArea(JSON.parse(json) as object));
  },
  delete: async ([areaId]) => {
    if (areaId === undefined) throw new Error('usage: ha area delete <area_id>');
    printJSON(await deleteArea(areaId));
  },
};

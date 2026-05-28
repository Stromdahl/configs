import { disableEntity, enableEntity, getEntity, listEntities, removeEntity, updateEntity } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const entity: CmdTree = {
  list: async () => {
    const list = await listEntities();
    list
      .sort((a, b) => a.entity_id.localeCompare(b.entity_id))
      .forEach((e) => {
        console.log([
          e.entity_id,
          e.name ?? e.original_name ?? '-',
          e.area_id ?? '-',
          e.device_id ?? '-',
          e.disabled_by ?? '',
          e.hidden_by ?? '',
        ].join('\t'));
      });
  },
  get: async ([eid]) => {
    if (eid === undefined) throw new Error('usage: ha entity get <entity_id>');
    printJSON(await getEntity(eid));
  },
  update: async ([eid, json]) => {
    if (eid === undefined || json === undefined) {
      throw new Error('usage: ha entity update <entity_id> <json>  (e.g. {"name":"...","area_id":"...","new_entity_id":"..."})');
    }
    printJSON(await updateEntity(eid, JSON.parse(json) as object));
  },
  remove: async ([eid]) => {
    if (eid === undefined) throw new Error('usage: ha entity remove <entity_id>');
    printJSON(await removeEntity(eid));
  },
  disable: async ([eid]) => {
    if (eid === undefined) throw new Error('usage: ha entity disable <entity_id>');
    printJSON(await disableEntity(eid));
  },
  enable: async ([eid]) => {
    if (eid === undefined) throw new Error('usage: ha entity enable <entity_id>');
    printJSON(await enableEntity(eid));
  },
};

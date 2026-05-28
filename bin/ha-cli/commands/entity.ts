import { printJSON } from '../format.ts';
import { withWs } from '../transport.ts';
import type { CmdTree, HAEntityRegistryEntry } from '../types.ts';

export const entity: CmdTree = {
  list: async () => {
    await withWs(async (c) => {
      const list = await c.send<HAEntityRegistryEntry[]>({ type: 'config/entity_registry/list' });
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
    });
  },
  get: async ([eid]) => {
    if (eid === undefined) throw new Error('usage: ha entity get <entity_id>');
    await withWs(async (c) => { printJSON(await c.send({ type: 'config/entity_registry/get', entity_id: eid })); });
  },
  update: async ([eid, json]) => {
    if (eid === undefined || json === undefined) {
      throw new Error('usage: ha entity update <entity_id> <json>  (e.g. {"name":"...","area_id":"...","new_entity_id":"..."})');
    }
    const payload = JSON.parse(json) as object;
    await withWs(async (c) => { printJSON(await c.send({ type: 'config/entity_registry/update', entity_id: eid, ...payload })); });
  },
  remove: async ([eid]) => {
    if (eid === undefined) throw new Error('usage: ha entity remove <entity_id>');
    await withWs(async (c) => { printJSON(await c.send({ type: 'config/entity_registry/remove', entity_id: eid })); });
  },
  disable: async ([eid]) => {
    if (eid === undefined) throw new Error('usage: ha entity disable <entity_id>');
    await withWs(async (c) => { printJSON(await c.send({ type: 'config/entity_registry/update', entity_id: eid, disabled_by: 'user' })); });
  },
  enable: async ([eid]) => {
    if (eid === undefined) throw new Error('usage: ha entity enable <entity_id>');
    await withWs(async (c) => { printJSON(await c.send({ type: 'config/entity_registry/update', entity_id: eid, disabled_by: null })); });
  },
};

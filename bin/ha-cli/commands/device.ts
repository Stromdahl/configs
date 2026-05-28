import { printJSON } from '../format.ts';
import { withWs } from '../transport.ts';
import type { CmdTree, HADeviceRegistryEntry } from '../types.ts';

export const device: CmdTree = {
  list: async () => {
    await withWs(async (c) => {
      const list = await c.send<HADeviceRegistryEntry[]>({ type: 'config/device_registry/list' });
      list
        .sort((a, b) => (a.area_id ?? '').localeCompare(b.area_id ?? '') || a.id.localeCompare(b.id))
        .forEach((d) => { console.log(`${d.id}\t${d.area_id ?? '-'}\t${d.name_by_user ?? d.name ?? '-'}\t${d.model ?? '-'}`); });
    });
  },
  update: async ([deviceId, json]) => {
    if (deviceId === undefined || json === undefined) throw new Error('usage: ha device update <device_id> <json>');
    const payload = JSON.parse(json) as object;
    await withWs(async (c) => { printJSON(await c.send({ type: 'config/device_registry/update', device_id: deviceId, ...payload })); });
  },
};

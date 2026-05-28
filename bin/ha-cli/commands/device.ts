import { listDevices, updateDevice } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const device: CmdTree = {
  list: async () => {
    const list = await listDevices();
    list
      .sort((a, b) => (a.area_id ?? '').localeCompare(b.area_id ?? '') || a.id.localeCompare(b.id))
      .forEach((d) => { console.log(`${d.id}\t${d.area_id ?? '-'}\t${d.name_by_user ?? d.name ?? '-'}\t${d.model ?? '-'}`); });
  },
  update: async ([deviceId, json]) => {
    if (deviceId === undefined || json === undefined) throw new Error('usage: ha device update <device_id> <json>');
    printJSON(await updateDevice(deviceId, JSON.parse(json) as object));
  },
};

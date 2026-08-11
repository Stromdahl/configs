import { adoptDevice, cyclePort, deleteDevice, getDevice, getDeviceStatistics, listDevices, listPendingDevices, restartDevice } from '../api.ts';
import { confirm, printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const device: CmdTree = {
  list: async ([filter]) => {
    const list = await listDevices(filter);
    list
      .sort((a, b) => a.name.localeCompare(b.name))
      .forEach((d) => { console.log(`${d.id}\t${d.name}\t${d.model}\t${d.ipAddress ?? '-'}\t${d.state}\t${d.firmwareVersion ?? '-'}`); });
  },
  get: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi device get <device_id>');
    printJSON(await getDevice(id));
  },
  stats: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi device stats <device_id>');
    printJSON(await getDeviceStatistics(id));
  },
  pending: async () => {
    printJSON(await listPendingDevices());
  },
  adopt: async ([json]) => {
    if (json === undefined) throw new Error('usage: unifi device adopt <json>  (e.g. {"macAddress":"...","ignoreDeviceLimit":false})');
    printJSON(await adoptDevice(JSON.parse(json) as object));
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi device delete <device_id>');
    printJSON(await deleteDevice(id));
  },
  restart: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi device restart <device_id> --yes');
    confirm(`this restarts device ${id} — if it's the gateway, it takes the whole site offline for a minute`);
    printJSON(await restartDevice(id));
  },
  'cycle-port': async ([deviceId, portIdx]) => {
    if (deviceId === undefined || portIdx === undefined) throw new Error('usage: unifi device cycle-port <device_id> <port_idx> --yes');
    confirm(`this power-cycles PoE on device ${deviceId} port ${portIdx}, dropping whatever is plugged into it`);
    printJSON(await cyclePort(deviceId, portIdx));
  },
};

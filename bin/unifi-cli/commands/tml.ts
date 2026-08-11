import { createTrafficMatchingList, deleteTrafficMatchingList, getTrafficMatchingList, listTrafficMatchingLists, updateTrafficMatchingList } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

// Traffic-matching lists — reusable IP/port sets referenced from firewall policies.
export const tml: CmdTree = {
  list: async ([filter]) => { printJSON(await listTrafficMatchingLists(filter)); },
  get: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi tml get <list_id>');
    printJSON(await getTrafficMatchingList(id));
  },
  create: async ([json]) => {
    if (json === undefined) throw new Error('usage: unifi tml create <json>');
    printJSON(await createTrafficMatchingList(JSON.parse(json) as object));
  },
  update: async ([id, json]) => {
    if (id === undefined || json === undefined) throw new Error('usage: unifi tml update <list_id> <json>');
    printJSON(await updateTrafficMatchingList(id, JSON.parse(json) as object));
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi tml delete <list_id>');
    printJSON(await deleteTrafficMatchingList(id));
  },
};

import { listWans } from '../api.ts';
import type { CmdTree } from '../types.ts';

export const wan: CmdTree = {
  list: async ([filter]) => {
    const list = await listWans(filter);
    list.forEach((w) => { console.log(`${w.id}\t${w.name}`); });
  },
};

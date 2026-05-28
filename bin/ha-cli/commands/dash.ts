import { readJSON, say, writeOrLog } from '../format.ts';
import { withWs } from '../transport.ts';
import type { CmdTree, HALovelaceListEntry } from '../types.ts';

export const dash: CmdTree = {
  list: async () => {
    await withWs(async (c) => {
      const list = await c.send<HALovelaceListEntry[]>({ type: 'lovelace/dashboards/list' });
      list.forEach((d) => { console.log(`${d.url_path}\t${d.title}\t${d.icon ?? ''}`); });
    });
  },
  get: async ([urlPath, file]) => {
    if (urlPath === undefined) throw new Error('usage: ha dash get <url_path> [file]');
    await withWs(async (c) => {
      const cfg = await c.send({ type: 'lovelace/config', url_path: urlPath });
      writeOrLog(file, cfg);
    });
  },
  save: async ([urlPath, file]) => {
    if (urlPath === undefined || file === undefined) throw new Error('usage: ha dash save <url_path> <file>');
    const cfg = readJSON(file);
    await withWs(async (c) => {
      await c.send({ type: 'lovelace/config/save', url_path: urlPath, config: cfg });
      say('saved');
    });
  },
};

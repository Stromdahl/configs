import { getDashboardConfig, listDashboards, saveDashboardConfig } from '../api.ts';
import { readJSON, say, writeOrLog } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const dash: CmdTree = {
  list: async () => {
    const list = await listDashboards();
    list.forEach((d) => { console.log(`${d.url_path}\t${d.title}\t${d.icon ?? ''}`); });
  },
  get: async ([urlPath, file]) => {
    if (urlPath === undefined) throw new Error('usage: ha dash get <url_path> [file]');
    writeOrLog(file, await getDashboardConfig(urlPath));
  },
  save: async ([urlPath, file]) => {
    if (urlPath === undefined || file === undefined) throw new Error('usage: ha dash save <url_path> <file>');
    await saveDashboardConfig(urlPath, readJSON(file));
    say('saved');
  },
};

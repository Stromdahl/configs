import { deleteAutomation, getAutomation, getStates, reloadAutomations, saveAutomation } from '../api.ts';
import { readJSON, say, writeOrLog } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const auto: CmdTree = {
  list: async () => {
    const states = await getStates();
    states
      .filter((s) => s.entity_id.startsWith('automation.'))
      .sort((a, b) => a.entity_id.localeCompare(b.entity_id))
      .forEach((s) => {
        const id = s.attributes.id;
        const fn = s.attributes.friendly_name;
        const idStr = typeof id === 'string' ? id : s.entity_id.replace('automation.', '');
        const fnStr = typeof fn === 'string' ? fn : '-';
        console.log(`${idStr}\t${fnStr}\t[${s.state}]`);
      });
  },
  get: async ([id, file]) => {
    if (id === undefined) throw new Error('usage: ha auto get <id> [file]');
    writeOrLog(file, await getAutomation(id));
  },
  save: async ([id, file]) => {
    if (id === undefined || file === undefined) throw new Error('usage: ha auto save <id> <file>');
    await saveAutomation(id, readJSON(file));
    await reloadAutomations();
    say('saved + reloaded');
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: ha auto delete <id>');
    await deleteAutomation(id);
    say('deleted');
  },
};

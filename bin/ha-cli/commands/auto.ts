import { readJSON, say, writeOrLog } from '../format.ts';
import { rest } from '../transport.ts';
import type { CmdTree, HAState } from '../types.ts';

export const auto: CmdTree = {
  list: async () => {
    const states = await rest<HAState[]>('GET', '/states');
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
    writeOrLog(file, await rest('GET', `/config/automation/config/${id}`));
  },
  save: async ([id, file]) => {
    if (id === undefined || file === undefined) throw new Error('usage: ha auto save <id> <file>');
    const cfg = readJSON(file);
    await rest('POST', `/config/automation/config/${id}`, cfg);
    await rest('POST', '/services/automation/reload');
    say('saved + reloaded');
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: ha auto delete <id>');
    await rest('DELETE', `/config/automation/config/${id}`);
    say('deleted');
  },
};

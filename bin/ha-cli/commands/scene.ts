import { deleteScene, getScene, getStates, reloadScenes, saveScene } from '../api.ts';
import { readJSON, say, writeOrLog } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const scene: CmdTree = {
  list: async () => {
    const states = await getStates();
    states
      .filter((s) => s.entity_id.startsWith('scene.'))
      .sort((a, b) => a.entity_id.localeCompare(b.entity_id))
      .forEach((s) => {
        const id = s.attributes.id;
        const fn = s.attributes.friendly_name;
        const idStr = typeof id === 'string' ? id : s.entity_id.replace('scene.', '');
        const fnStr = typeof fn === 'string' ? fn : '-';
        console.log(`${idStr}\t${fnStr}`);
      });
  },
  get: async ([id, file]) => {
    if (id === undefined) throw new Error('usage: ha scene get <id> [file]');
    writeOrLog(file, await getScene(id));
  },
  save: async ([id, file]) => {
    if (id === undefined || file === undefined) throw new Error('usage: ha scene save <id> <file>');
    await saveScene(id, readJSON(file));
    await reloadScenes();
    say('saved + reloaded');
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: ha scene delete <id>');
    await deleteScene(id);
    say('deleted');
  },
};

import { printJSON } from '../format.ts';
import { rest, withWs } from '../transport.ts';
import type { CmdTree, HAState } from '../types.ts';

const HELPER_PREFIXES = ['input_number.', 'input_boolean.', 'input_button.', 'input_text.', 'input_select.', 'input_datetime.'];

export const helper: CmdTree = {
  list: async () => {
    const states = await rest<HAState[]>('GET', '/states');
    states
      .filter((s) => HELPER_PREFIXES.some((p) => s.entity_id.startsWith(p)))
      .sort((a, b) => a.entity_id.localeCompare(b.entity_id))
      .forEach((s) => {
        const fn = s.attributes.friendly_name;
        console.log(`${s.entity_id}\t${s.state}\t${typeof fn === 'string' ? fn : '-'}`);
      });
  },
  create: async ([type, json]) => {
    if (type === undefined || json === undefined) throw new Error('usage: ha helper create <type> <json>  (type: input_number, input_button, ...)');
    const payload = JSON.parse(json) as object;
    await withWs(async (c) => { printJSON(await c.send({ type: `${type}/create`, ...payload })); });
  },
  delete: async ([type, id]) => {
    if (type === undefined || id === undefined) throw new Error('usage: ha helper delete <type> <id>');
    await withWs(async (c) => { printJSON(await c.send({ type: `${type}/delete`, [`${type}_id`]: id })); });
  },
};

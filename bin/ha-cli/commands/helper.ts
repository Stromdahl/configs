import { createHelper, deleteHelper, getStates } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

const HELPER_PREFIXES = ['input_number.', 'input_boolean.', 'input_button.', 'input_text.', 'input_select.', 'input_datetime.'];

export const helper: CmdTree = {
  list: async () => {
    const states = await getStates();
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
    printJSON(await createHelper(type, JSON.parse(json) as object));
  },
  delete: async ([type, id]) => {
    if (type === undefined || id === undefined) throw new Error('usage: ha helper delete <type> <id>');
    printJSON(await deleteHelper(type, id));
  },
};

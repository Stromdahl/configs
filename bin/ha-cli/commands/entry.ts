import { printJSON } from '../format.ts';
import { rest, withWs } from '../transport.ts';
import type { CmdTree, HAConfigEntry } from '../types.ts';

export const entry: CmdTree = {
  list: async ([domainFilter]) => {
    let list = await rest<HAConfigEntry[]>('GET', '/config/config_entries/entry');
    if (domainFilter !== undefined) list = list.filter((e) => e.domain === domainFilter);
    list.sort((a, b) => (a.domain).localeCompare(b.domain) || (a.title ?? '').localeCompare(b.title ?? ''));
    list.forEach((e) => { console.log(`${e.entry_id}\t${e.domain}\t${e.title ?? '-'}\t${e.state}\t${e.source ?? '-'}`); });
  },
  get: async ([entryId]) => {
    if (entryId === undefined) throw new Error('usage: ha entry get <entry_id>');
    const list = await rest<HAConfigEntry[]>('GET', '/config/config_entries/entry');
    const e = list.find((x) => x.entry_id === entryId);
    if (!e) { console.error(`unknown entry: ${entryId}`); process.exit(1); }
    printJSON(e);
  },
  delete: async ([entryId]) => {
    if (entryId === undefined) throw new Error('usage: ha entry delete <entry_id>');
    printJSON(await rest('DELETE', `/config/config_entries/entry/${entryId}`));
  },
  reload: async ([entryId]) => {
    if (entryId === undefined) throw new Error('usage: ha entry reload <entry_id>');
    printJSON(await rest('POST', `/config/config_entries/entry/${entryId}/reload`));
  },
  flows: async () => {
    await withWs(async (c) => { printJSON(await c.send({ type: 'config_entries/flow/progress' })); });
  },
};

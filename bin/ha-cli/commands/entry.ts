import {
  abortOptionsFlow,
  deleteConfigEntry,
  getConfigEntries,
  listConfigEntryFlows,
  reloadConfigEntry,
  startOptionsFlow,
  submitOptionsStep,
} from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const entry: CmdTree = {
  list: async ([domainFilter]) => {
    let list = await getConfigEntries();
    if (domainFilter !== undefined) list = list.filter((e) => e.domain === domainFilter);
    list.sort((a, b) => (a.domain).localeCompare(b.domain) || (a.title ?? '').localeCompare(b.title ?? ''));
    list.forEach((e) => { console.log(`${e.entry_id}\t${e.domain}\t${e.title ?? '-'}\t${e.state}\t${e.source ?? '-'}`); });
  },
  get: async ([entryId]) => {
    if (entryId === undefined) throw new Error('usage: ha entry get <entry_id>');
    const list = await getConfigEntries();
    const e = list.find((x) => x.entry_id === entryId);
    if (!e) { console.error(`unknown entry: ${entryId}`); process.exit(1); }
    printJSON(e);
  },
  delete: async ([entryId]) => {
    if (entryId === undefined) throw new Error('usage: ha entry delete <entry_id>');
    printJSON(await deleteConfigEntry(entryId));
  },
  reload: async ([entryId]) => {
    if (entryId === undefined) throw new Error('usage: ha entry reload <entry_id>');
    printJSON(await reloadConfigEntry(entryId));
  },
  flows: async () => {
    printJSON(await listConfigEntryFlows());
  },
  // Edit an existing entry in place. Worth reaching for even when `supports_reconfigure`
  // is false — an options flow often re-exposes fields the config flow set (ping's, for
  // one, includes the host), so repointing beats delete-and-recreate and keeps history.
  options: async ([entryId, payload]) => {
    if (entryId === undefined) throw new Error("usage: ha entry options <entry_id> ['<json>']");
    const start = await startOptionsFlow(entryId);
    if (start.type !== 'form') { printJSON(start); return; }
    if (payload === undefined) {
      await abortOptionsFlow(start.flow_id);
      printJSON({ step_id: start.step_id, data_schema: start.data_schema });
      return;
    }
    printJSON(await submitOptionsStep(start.flow_id, JSON.parse(payload) as unknown));
  },
};

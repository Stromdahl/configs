import { createAclRule, deleteAclRule, getAclRule, getAclRuleOrder, listAclRules, setAclRuleOrder, updateAclRule } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const acl: CmdTree = {
  list: async ([filter]) => { printJSON(await listAclRules(filter)); },
  get: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi acl get <rule_id>');
    printJSON(await getAclRule(id));
  },
  create: async ([json]) => {
    if (json === undefined) throw new Error('usage: unifi acl create <json>');
    printJSON(await createAclRule(JSON.parse(json) as object));
  },
  update: async ([id, json]) => {
    if (id === undefined || json === undefined) throw new Error('usage: unifi acl update <rule_id> <json>  (PUT replaces the whole rule)');
    printJSON(await updateAclRule(id, JSON.parse(json) as object));
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi acl delete <rule_id>');
    printJSON(await deleteAclRule(id));
  },
  order: {
    get: async () => { printJSON(await getAclRuleOrder()); },
    set: async ([json]) => {
      if (json === undefined) throw new Error('usage: unifi acl order set <json>  (ordered array of rule IDs)');
      printJSON(await setAclRuleOrder(JSON.parse(json) as object));
    },
  },
};

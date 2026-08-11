import { getLag, getMcLagDomain, getSwitchStack, listLags, listMcLagDomains, listSwitchStacks } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

// All read-only — the Integration API has no write endpoints for switch
// stacks, MC-LAG domains, or LAGs.
export const switching: CmdTree = {
  stack: {
    list: async ([filter]) => { printJSON(await listSwitchStacks(filter)); },
    get: async ([id]) => {
      if (id === undefined) throw new Error('usage: unifi switching stack get <stack_id>');
      printJSON(await getSwitchStack(id));
    },
  },
  mclag: {
    list: async ([filter]) => { printJSON(await listMcLagDomains(filter)); },
    get: async ([id]) => {
      if (id === undefined) throw new Error('usage: unifi switching mclag get <domain_id>');
      printJSON(await getMcLagDomain(id));
    },
  },
  lag: {
    list: async ([filter]) => { printJSON(await listLags(filter)); },
    get: async ([id]) => {
      if (id === undefined) throw new Error('usage: unifi switching lag get <lag_id>');
      printJSON(await getLag(id));
    },
  },
};

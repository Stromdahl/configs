import { listSiteToSiteTunnels, listVpnServers } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const vpn: CmdTree = {
  server: {
    list: async ([filter]) => { printJSON(await listVpnServers(filter)); },
  },
  tunnel: {
    list: async ([filter]) => { printJSON(await listSiteToSiteTunnels(filter)); },
  },
};

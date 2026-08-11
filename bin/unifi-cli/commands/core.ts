import { getInfo, listSites, raw as rawCall } from '../api.ts';
import { printJSON } from '../format.ts';
import { API_PREFIX, siteId } from '../transport.ts';
import type { CmdFn, CmdTree } from '../types.ts';

export const site: CmdTree = {
  list: async () => {
    const sites = await listSites();
    sites.forEach((s) => { console.log(`${s.id}\t${s.name}\t${s.internalReference}`); });
  },
  current: (): Promise<void> => {
    console.log(siteId());
    return Promise.resolve();
  },
};

export const info: CmdFn = async () => {
  printJSON(await getInfo());
};

// Resolves the "current" shorthand for the configured siteId, and prepends
// the API prefix stripped out by sitePath()/v1Path() everywhere else — so
// `unifi raw GET /v1/sites/current/devices` matches what the other commands
// actually hit.
function resolvePath(p: string): string {
  const withSite = p.replace('/sites/current/', `/sites/${siteId()}/`).replace(/\/sites\/current$/, `/sites/${siteId()}`);
  return `${API_PREFIX}${withSite}`;
}

export const raw: CmdFn = async ([method, endpoint, json]) => {
  if (method === undefined || endpoint === undefined) {
    throw new Error("usage: unifi raw <METHOD> <path> ['<json>']  (path e.g. /v1/sites/current/devices)");
  }
  const body: unknown = json !== undefined ? JSON.parse(json) : undefined;
  printJSON(await rawCall(method.toUpperCase(), resolvePath(endpoint), body));
};

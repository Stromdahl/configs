import { listCountries, listDeviceTags, listDpiApplications, listDpiCategories, listRadiusProfiles } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

// Read-only reference data with no dedicated command file of its own.
export const tag: CmdTree = {
  list: async ([filter]) => { printJSON(await listDeviceTags(filter)); },
};

export const radius: CmdTree = {
  list: async ([filter]) => { printJSON(await listRadiusProfiles(filter)); },
};

export const dpi: CmdTree = {
  categories: async ([filter]) => { printJSON(await listDpiCategories(filter)); },
  applications: async ([filter]) => { printJSON(await listDpiApplications(filter)); },
};

export const country: CmdTree = {
  list: async ([filter]) => { printJSON(await listCountries(filter)); },
};

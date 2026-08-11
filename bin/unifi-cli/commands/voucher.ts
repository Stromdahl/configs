import { createVouchers, deleteVoucher, deleteVouchersByFilter, getVoucher, listVouchers } from '../api.ts';
import { printJSON } from '../format.ts';
import type { CmdTree } from '../types.ts';

export const voucher: CmdTree = {
  list: async ([filter]) => { printJSON(await listVouchers(filter)); },
  get: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi voucher get <voucher_id>');
    printJSON(await getVoucher(id));
  },
  create: async ([json]) => {
    if (json === undefined) {
      throw new Error('usage: unifi voucher create <json>  (e.g. {"count":1,"name":"guest-wifi","timeLimitMinutes":1440})');
    }
    printJSON(await createVouchers(JSON.parse(json) as object));
  },
  delete: async ([id]) => {
    if (id === undefined) throw new Error('usage: unifi voucher delete <voucher_id>');
    printJSON(await deleteVoucher(id));
  },
  'delete-filter': async ([filter]) => {
    if (filter === undefined) throw new Error('usage: unifi voucher delete-filter <filter>  (bulk delete matching vouchers)');
    printJSON(await deleteVouchersByFilter(filter));
  },
};

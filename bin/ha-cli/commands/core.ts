import { patternToRegex, printJSON, say, slim } from '../format.ts';
import { rest, withWs } from '../transport.ts';
import type { CmdFn, HAFlowResponse, HAServiceGroup, HAState } from '../types.ts';

export const state: CmdFn = async ([eid]) => {
  if (eid === undefined) throw new Error('usage: ha state <entity_id>');
  printJSON(slim(await rest<HAState>('GET', `/states/${eid}`)));
};

export const call: CmdFn = async ([service, dataJson]) => {
  if (service === undefined) throw new Error('usage: ha call <domain.service> [json]');
  const [domain, svc] = service.split('.', 2);
  const body: unknown = dataJson !== undefined ? JSON.parse(dataJson) : {};
  printJSON(await rest('POST', `/services/${domain}/${svc}`, body));
};

export const template: CmdFn = async ([tpl]) => {
  if (tpl === undefined) throw new Error('usage: ha template <jinja>');
  printJSON(await rest('POST', '/template', { template: tpl }));
};

export const ws: CmdFn = async ([json]) => {
  if (json === undefined) throw new Error('usage: ha ws <json-message>');
  const msg = JSON.parse(json) as object;
  await withWs(async (c) => { printJSON(await c.send(msg)); });
};

export const flow: CmdFn = async ([handler, ...stepArgs]) => {
  if (handler === undefined || stepArgs.length === 0) {
    throw new Error("usage: ha flow <handler> '<step1-json>' ['<step2-json>' ...]");
  }
  const steps: unknown[] = stepArgs.map((s, idx): unknown => {
    try { return JSON.parse(s) as unknown; }
    catch (e) { throw new Error(`step ${idx + 1} is not valid JSON: ${e instanceof Error ? e.message : String(e)}`); }
  });
  let resp = await rest<HAFlowResponse>('POST', '/config/config_entries/flow', { handler, show_advanced_options: false });
  for (let i = 0; i < steps.length; i++) {
    if (resp.type !== 'form') break;
    resp = await rest<HAFlowResponse>('POST', `/config/config_entries/flow/${resp.flow_id}`, steps[i]);
    if ('errors' in resp && resp.errors) throw new Error(`step ${i + 1} errors: ${JSON.stringify(resp.errors)}`);
  }
  if (resp.type === 'form') {
    throw new Error(`flow not finished — next step '${resp.step_id}' still needed. Schema:\n${JSON.stringify(resp.data_schema, null, 2)}`);
  }
  printJSON(resp);
};

export const entities: CmdFn = async ([pattern]) => {
  const states = await rest<HAState[]>('GET', '/states');
  const re = pattern !== undefined ? patternToRegex(pattern) : null;
  const rows = states
    .filter((s) => re === null || re.test(s.entity_id))
    .map((s) => {
      const fn = s.attributes.friendly_name;
      const dc = s.attributes.device_class;
      return `${s.entity_id}\t${s.state}\t${typeof fn === 'string' ? fn : '-'}\t${typeof dc === 'string' ? dc : '-'}`;
    })
    .sort();
  say('entity_id\tstate\tfriendly_name\tdevice_class');
  rows.forEach((r) => { console.log(r); });
};

export const services: CmdFn = async ([filter]) => {
  const list = await rest<HAServiceGroup[]>('GET', '/services');
  if (filter === undefined) {
    const out: string[] = [];
    for (const d of list) for (const s of Object.keys(d.services)) out.push(`${d.domain}.${s}`);
    out.sort();
    out.forEach((s) => { console.log(s); });
    return;
  }
  const [domain, svc] = filter.split('.', 2) as [string, string | undefined];
  const d = list.find((x) => x.domain === domain);
  if (!d) { console.error(`unknown domain: ${domain}`); process.exit(1); }
  if (svc === undefined) { printJSON(d.services); return; }
  if (!(svc in d.services)) { console.error(`unknown service: ${filter}`); process.exit(1); }
  printJSON(d.services[svc]);
};

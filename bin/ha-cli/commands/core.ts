import {
  abortFlow,
  callService,
  getServices,
  getState,
  getStates,
  renderTemplate,
  sendRaw,
  startFlow,
  submitFlowStep,
} from '../api.ts';
import { patternToRegex, printJSON, say, slim } from '../format.ts';
import type { CmdFn } from '../types.ts';

export const state: CmdFn = async ([eid]) => {
  if (eid === undefined) throw new Error('usage: ha state <entity_id>');
  printJSON(slim(await getState(eid)));
};

export const call: CmdFn = async ([service, dataJson]) => {
  if (service === undefined) throw new Error('usage: ha call <domain.service> [json]');
  const [domain, svc] = service.split('.', 2) as [string, string | undefined];
  if (svc === undefined) throw new Error('usage: ha call <domain.service> [json]');
  const body: unknown = dataJson !== undefined ? JSON.parse(dataJson) : {};
  printJSON(await callService(domain, svc, body));
};

export const template: CmdFn = async ([tpl]) => {
  if (tpl === undefined) throw new Error('usage: ha template <jinja>');
  printJSON(await renderTemplate(tpl));
};

export const ws: CmdFn = async ([json]) => {
  if (json === undefined) throw new Error('usage: ha ws <json-message>');
  printJSON(await sendRaw(JSON.parse(json) as object));
};

// Start a flow purely to read its first step's schema, then abort it so it does
// not linger in `ha entry flows`. This is the reliable way to learn a handler's
// real field names — they differ per integration (sonarr wants verify_ssl inside
// a `more_options` section, radarr takes it flat).
async function probeFlowSchema(handler: string): Promise<void> {
  const probe = await startFlow(handler);
  if (probe.type !== 'form') {
    printJSON(probe);
    return;
  }
  await abortFlow(probe.flow_id);
  printJSON({ step_id: probe.step_id, data_schema: probe.data_schema });
}

export const flow: CmdFn = async ([handler, ...stepArgs]) => {
  if (handler === undefined) {
    throw new Error("usage: ha flow <handler> ['<step1-json>' ['<step2-json>' ...]]");
  }
  if (stepArgs.length === 0) return probeFlowSchema(handler);
  const steps: unknown[] = stepArgs.map((s, idx): unknown => {
    try { return JSON.parse(s) as unknown; }
    catch (e) { throw new Error(`step ${idx + 1} is not valid JSON: ${e instanceof Error ? e.message : String(e)}`); }
  });
  let resp = await startFlow(handler);
  for (let i = 0; i < steps.length; i++) {
    if (resp.type !== 'form') break;
    resp = await submitFlowStep(resp.flow_id, steps[i]);
    if ('errors' in resp && resp.errors) throw new Error(`step ${i + 1} errors: ${JSON.stringify(resp.errors)}`);
  }
  if (resp.type === 'form') {
    throw new Error(`flow not finished — next step '${resp.step_id}' still needed. Schema:\n${JSON.stringify(resp.data_schema, null, 2)}`);
  }
  printJSON(resp);
};

export const entities: CmdFn = async ([pattern]) => {
  const states = await getStates();
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
  const list = await getServices();
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

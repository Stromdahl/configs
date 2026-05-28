// Typed wrappers around the raw HA REST + WS transports. Every endpoint we
// talk to has a named function here; command modules call these instead of
// hand-rolling URLs / message types.

import { rest, withWs } from './transport.ts';
import type {
  HAAreaRegistryEntry,
  HAConfigEntry,
  HADeviceRegistryEntry,
  HAEntityRegistryEntry,
  HAFlowResponse,
  HALovelaceListEntry,
  HAServiceGroup,
  HAState,
} from './types.ts';

// ---- REST: reads ----

export function getStates(): Promise<HAState[]> {
  return rest<HAState[]>('GET', '/states');
}

export function getState(entityId: string): Promise<HAState> {
  return rest<HAState>('GET', `/states/${entityId}`);
}

export function getServices(): Promise<HAServiceGroup[]> {
  return rest<HAServiceGroup[]>('GET', '/services');
}

export function getConfigEntries(): Promise<HAConfigEntry[]> {
  return rest<HAConfigEntry[]>('GET', '/config/config_entries/entry');
}

export function getAutomation(id: string): Promise<unknown> {
  return rest('GET', `/config/automation/config/${id}`);
}

export function getScene(id: string): Promise<unknown> {
  return rest('GET', `/config/scene/config/${id}`);
}

// ---- REST: actions & writes ----

export function callService(domain: string, svc: string, body: unknown): Promise<unknown> {
  return rest('POST', `/services/${domain}/${svc}`, body);
}

export function renderTemplate(jinja: string): Promise<unknown> {
  return rest('POST', '/template', { template: jinja });
}

export async function saveAutomation(id: string, cfg: unknown): Promise<void> {
  await rest('POST', `/config/automation/config/${id}`, cfg);
}

export async function deleteAutomation(id: string): Promise<void> {
  await rest('DELETE', `/config/automation/config/${id}`);
}

export async function reloadAutomations(): Promise<void> {
  await rest('POST', '/services/automation/reload');
}

export async function saveScene(id: string, cfg: unknown): Promise<void> {
  await rest('POST', `/config/scene/config/${id}`, cfg);
}

export async function deleteScene(id: string): Promise<void> {
  await rest('DELETE', `/config/scene/config/${id}`);
}

export async function reloadScenes(): Promise<void> {
  await rest('POST', '/services/scene/reload');
}

export function deleteConfigEntry(entryId: string): Promise<unknown> {
  return rest('DELETE', `/config/config_entries/entry/${entryId}`);
}

export function reloadConfigEntry(entryId: string): Promise<unknown> {
  return rest('POST', `/config/config_entries/entry/${entryId}/reload`);
}

// ---- REST: config flow (multi-step) ----

export function startFlow(handler: string): Promise<HAFlowResponse> {
  return rest<HAFlowResponse>('POST', '/config/config_entries/flow', { handler, show_advanced_options: false });
}

export function submitFlowStep(flowId: string, payload: unknown): Promise<HAFlowResponse> {
  return rest<HAFlowResponse>('POST', `/config/config_entries/flow/${flowId}`, payload);
}

// ---- WebSocket: escape hatch for `ha ws '<json>'` ----

export function sendRaw(msg: object): Promise<unknown> {
  return withWs((c) => c.send(msg));
}

// ---- WebSocket: dashboards ----

export function listDashboards(): Promise<HALovelaceListEntry[]> {
  return withWs((c) => c.send<HALovelaceListEntry[]>({ type: 'lovelace/dashboards/list' }));
}

export function getDashboardConfig(urlPath: string): Promise<unknown> {
  return withWs((c) => c.send({ type: 'lovelace/config', url_path: urlPath }));
}

export async function saveDashboardConfig(urlPath: string, config: unknown): Promise<void> {
  await withWs((c) => c.send({ type: 'lovelace/config/save', url_path: urlPath, config }));
}

// ---- WebSocket: entity registry ----

export function listEntities(): Promise<HAEntityRegistryEntry[]> {
  return withWs((c) => c.send<HAEntityRegistryEntry[]>({ type: 'config/entity_registry/list' }));
}

export function getEntity(entityId: string): Promise<unknown> {
  return withWs((c) => c.send({ type: 'config/entity_registry/get', entity_id: entityId }));
}

export function updateEntity(entityId: string, payload: object): Promise<unknown> {
  return withWs((c) => c.send({ type: 'config/entity_registry/update', entity_id: entityId, ...payload }));
}

export function removeEntity(entityId: string): Promise<unknown> {
  return withWs((c) => c.send({ type: 'config/entity_registry/remove', entity_id: entityId }));
}

export function disableEntity(entityId: string): Promise<unknown> {
  return updateEntity(entityId, { disabled_by: 'user' });
}

export function enableEntity(entityId: string): Promise<unknown> {
  return updateEntity(entityId, { disabled_by: null });
}

// ---- WebSocket: device registry ----

export function listDevices(): Promise<HADeviceRegistryEntry[]> {
  return withWs((c) => c.send<HADeviceRegistryEntry[]>({ type: 'config/device_registry/list' }));
}

export function updateDevice(deviceId: string, payload: object): Promise<unknown> {
  return withWs((c) => c.send({ type: 'config/device_registry/update', device_id: deviceId, ...payload }));
}

// ---- WebSocket: area registry ----

export function listAreas(): Promise<HAAreaRegistryEntry[]> {
  return withWs((c) => c.send<HAAreaRegistryEntry[]>({ type: 'config/area_registry/list' }));
}

export function createArea(payload: object): Promise<unknown> {
  return withWs((c) => c.send({ type: 'config/area_registry/create', ...payload }));
}

export function deleteArea(areaId: string): Promise<unknown> {
  return withWs((c) => c.send({ type: 'config/area_registry/delete', area_id: areaId }));
}

// ---- WebSocket: config-entry flows in progress ----

export function listConfigEntryFlows(): Promise<unknown> {
  return withWs((c) => c.send({ type: 'config_entries/flow/progress' }));
}

// ---- WebSocket: collection helpers (input_*) ----

export function createHelper(helperType: string, payload: object): Promise<unknown> {
  return withWs((c) => c.send({ type: `${helperType}/create`, ...payload }));
}

export function deleteHelper(helperType: string, id: string): Promise<unknown> {
  return withWs((c) => c.send({ type: `${helperType}/delete`, [`${helperType}_id`]: id }));
}

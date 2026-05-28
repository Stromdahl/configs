// Type definitions for the ha CLI. Pure types only — no runtime.

export interface Flags {
  pretty: boolean;
  quiet: boolean;
  output: string | null;
}

export type CmdFn = (args: string[]) => Promise<void>;
export interface CmdTree { [key: string]: CmdFn | CmdTree }

export type WalkResult =
  | { fn: CmdFn; rest: string[] }
  | { fn?: undefined; node: CmdTree; i: number };

export interface TokenFile {
  headers: { Authorization: string };
}

// ---- HA REST/WS payload shapes ----

export interface HAState {
  entity_id: string;
  state: string;
  attributes: Record<string, unknown>;
  last_changed?: string;
  last_reported?: string;
  last_updated?: string;
  context?: { id: string; parent_id: string | null; user_id: string | null };
}

export interface HAStateSlim {
  entity_id: string;
  state: string;
  attributes: Record<string, unknown>;
}

export interface HAServiceGroup {
  domain: string;
  services: Record<string, unknown>;
}

export interface HAConfigEntry {
  entry_id: string;
  domain: string;
  title: string | null;
  state: string;
  source: string | null;
}

export interface HAEntityRegistryEntry {
  entity_id: string;
  name: string | null;
  original_name: string | null;
  area_id: string | null;
  device_id: string | null;
  disabled_by: string | null;
  hidden_by: string | null;
}

export interface HADeviceRegistryEntry {
  id: string;
  area_id: string | null;
  name: string | null;
  name_by_user: string | null;
  model: string | null;
}

export interface HAAreaRegistryEntry {
  area_id: string;
  name: string;
  icon: string | null;
}

export interface HALovelaceListEntry {
  url_path: string;
  title: string;
  icon: string | null;
}

export interface HAFormFlowStep {
  type: 'form';
  flow_id: string;
  step_id: string;
  errors?: unknown;
  data_schema?: unknown;
}

export interface HACreateEntryFlow {
  type: 'create_entry';
  flow_id: string;
  result: unknown;
}

export interface HAAbortFlow {
  type: 'abort';
  reason?: string;
}

export type HAFlowResponse = HAFormFlowStep | HACreateEntryFlow | HAAbortFlow;

// ---- WebSocket framing ----

export interface WSResult {
  id: number;
  type: 'result';
  success: boolean;
  result?: unknown;
  error?: unknown;
}

export interface WSAuthFrame {
  type: 'auth_required' | 'auth_ok' | 'auth_invalid';
}

export type WSFrame = WSAuthFrame | WSResult;

export interface WSClient {
  send: <T = unknown>(msg: object) => Promise<T>;
  close: () => void;
}

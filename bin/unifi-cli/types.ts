// Type definitions for the unifi CLI. Pure types only — no runtime.

export interface Flags {
  pretty: boolean;
  quiet: boolean;
  help: boolean;
  yes: boolean;
  output: string | null;
}

export type CmdFn = (args: string[]) => Promise<void>;
export interface CmdTree { [key: string]: CmdFn | CmdTree }

export type WalkResult =
  | { fn: CmdFn; rest: string[] }
  | { fn?: undefined; node: CmdTree; i: number };

export interface TokenFile {
  apiKey: string;
  baseUrl?: string;
  siteId?: string;
}

// ---- UniFi Network Integration API payload shapes ----

// Every collection endpoint returns this envelope. `offset`/`limit`/`count`
// describe the page actually returned; `totalCount` is the full collection
// size — transport.ts pages through this automatically.
export interface Page<T> {
  offset: number;
  limit: number;
  count: number;
  totalCount: number;
  data: T[];
}

export interface Site {
  id: string;
  internalReference: string;
  name: string;
}

// Row shapes for the handful of `list` verbs that print human-readable
// columns instead of raw JSON. Everything else is treated as `unknown` and
// printed with printJSON — see api.ts. Fields verified against a live
// controller (10.5.67), not transcribed from the spec.
export interface DeviceOverview {
  id: string;
  name: string;
  model: string;
  ipAddress?: string;
  macAddress: string;
  state: string;
  firmwareVersion?: string;
}

export interface ClientOverview {
  id: string;
  name?: string;
  type: string;
  ipAddress?: string;
  macAddress: string;
  connectedAt?: string;
}

export interface NetworkOverview {
  id: string;
  name: string;
  enabled: boolean;
  vlanId?: number;
  default: boolean;
}

export interface WanOverview {
  id: string;
  name: string;
}

export interface WifiBroadcastOverview {
  id: string;
  name: string;
  enabled: boolean;
  type: string;
}

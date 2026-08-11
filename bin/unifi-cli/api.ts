// Typed wrappers around the raw UniFi Integration API transport. The API is
// uniformly RESTful — every collection is list/get/create/update/delete at
// the same shapes — so each wrapper here is a one-liner over the generic
// helpers below rather than hand-rolled per endpoint.

import { del, get, listAll, patch, post, put, rest, sitePath, v1Path } from './transport.ts';
import type { ClientOverview, DeviceOverview, NetworkOverview, Site, WanOverview, WifiBroadcastOverview } from './types.ts';

// ---- generic collection helpers ----

function list<T>(coll: string, filter?: string): Promise<T[]> {
  return listAll<T>(sitePath(coll), filter);
}

function listTop<T>(coll: string, filter?: string): Promise<T[]> {
  return listAll<T>(v1Path(coll), filter);
}

function getOne<T>(coll: string, id: string): Promise<T> {
  return get<T>(sitePath(`${coll}/${id}`));
}

function create<T>(coll: string, body: unknown): Promise<T> {
  return post<T>(sitePath(coll), body);
}

function update<T>(coll: string, id: string, body: unknown): Promise<T> {
  return put<T>(sitePath(`${coll}/${id}`), body);
}

function patchOne<T>(coll: string, id: string, body: unknown): Promise<T> {
  return patch<T>(sitePath(`${coll}/${id}`), body);
}

function remove<T>(coll: string, id: string): Promise<T> {
  return del<T>(sitePath(`${coll}/${id}`));
}

// ---- sites & info (not site-scoped) ----

export function listSites(): Promise<Site[]> {
  return listTop<Site>('sites');
}

export function getInfo(): Promise<unknown> {
  return get(v1Path('info'));
}

// ---- devices ----

export function listDevices(filter?: string): Promise<DeviceOverview[]> {
  return list('devices', filter);
}

export function getDevice(id: string): Promise<unknown> {
  return getOne('devices', id);
}

export function deleteDevice(id: string): Promise<unknown> {
  return remove('devices', id);
}

export function adoptDevice(body: unknown): Promise<unknown> {
  return post(sitePath('devices'), body);
}

export function getDeviceStatistics(id: string): Promise<unknown> {
  return get(sitePath(`devices/${id}/statistics/latest`));
}

export function restartDevice(id: string): Promise<unknown> {
  return post(sitePath(`devices/${id}/actions`), { action: 'RESTART' });
}

export function cyclePort(deviceId: string, portIdx: string): Promise<unknown> {
  return post(sitePath(`devices/${deviceId}/interfaces/ports/${portIdx}/actions`), { action: 'POWER_CYCLE' });
}

export function listPendingDevices(): Promise<unknown[]> {
  return listTop('pending-devices');
}

export function listDeviceTags(filter?: string): Promise<unknown[]> {
  return list('device-tags', filter);
}

// ---- clients ----

export function listClients(filter?: string): Promise<ClientOverview[]> {
  return list('clients', filter);
}

export function getClient(id: string): Promise<unknown> {
  return getOne('clients', id);
}

export function authorizeGuest(id: string, extra?: object): Promise<unknown> {
  return post(sitePath(`clients/${id}/actions`), { action: 'AUTHORIZE_GUEST_ACCESS', ...extra });
}

export function unauthorizeGuest(id: string): Promise<unknown> {
  return post(sitePath(`clients/${id}/actions`), { action: 'UNAUTHORIZE_GUEST_ACCESS' });
}

// ---- networks ----

export function listNetworks(filter?: string): Promise<NetworkOverview[]> {
  return list('networks', filter);
}

export function getNetwork(id: string): Promise<unknown> {
  return getOne('networks', id);
}

export function createNetwork(body: unknown): Promise<unknown> {
  return create('networks', body);
}

// PUT replaces the whole resource — the API has no PATCH for networks.
// Callers that only want to tweak one field must GET first and merge; see
// `unifi network update`'s usage text.
export function updateNetwork(id: string, body: unknown): Promise<unknown> {
  return update('networks', id, body);
}

export function deleteNetwork(id: string): Promise<unknown> {
  return remove('networks', id);
}

export function getNetworkReferences(id: string): Promise<unknown> {
  return get(sitePath(`networks/${id}/references`));
}

// ---- WANs (read-only) ----

export function listWans(filter?: string): Promise<WanOverview[]> {
  return list('wans', filter);
}

// ---- Wi-Fi broadcasts (SSIDs) ----

export function listWifiBroadcasts(filter?: string): Promise<WifiBroadcastOverview[]> {
  return list('wifi/broadcasts', filter);
}

export function getWifiBroadcast(id: string): Promise<unknown> {
  return getOne('wifi/broadcasts', id);
}

export function createWifiBroadcast(body: unknown): Promise<unknown> {
  return create('wifi/broadcasts', body);
}

export function updateWifiBroadcast(id: string, body: unknown): Promise<unknown> {
  return update('wifi/broadcasts', id, body);
}

export function deleteWifiBroadcast(id: string): Promise<unknown> {
  return remove('wifi/broadcasts', id);
}

// ---- firewall zones ----

export function listFirewallZones(filter?: string): Promise<unknown[]> {
  return list('firewall/zones', filter);
}

export function getFirewallZone(id: string): Promise<unknown> {
  return getOne('firewall/zones', id);
}

export function createFirewallZone(body: unknown): Promise<unknown> {
  return create('firewall/zones', body);
}

export function updateFirewallZone(id: string, body: unknown): Promise<unknown> {
  return update('firewall/zones', id, body);
}

export function deleteFirewallZone(id: string): Promise<unknown> {
  return remove('firewall/zones', id);
}

// ---- firewall policies ----

export function listFirewallPolicies(filter?: string): Promise<unknown[]> {
  return list('firewall/policies', filter);
}

export function getFirewallPolicy(id: string): Promise<unknown> {
  return getOne('firewall/policies', id);
}

export function createFirewallPolicy(body: unknown): Promise<unknown> {
  return create('firewall/policies', body);
}

export function updateFirewallPolicy(id: string, body: unknown): Promise<unknown> {
  return update('firewall/policies', id, body);
}

export function patchFirewallPolicy(id: string, body: unknown): Promise<unknown> {
  return patchOne('firewall/policies', id, body);
}

export function deleteFirewallPolicy(id: string): Promise<unknown> {
  return remove('firewall/policies', id);
}

export function getFirewallPolicyOrder(): Promise<unknown> {
  return get(sitePath('firewall/policies/ordering'));
}

export function setFirewallPolicyOrder(body: unknown): Promise<unknown> {
  return put(sitePath('firewall/policies/ordering'), body);
}

// ---- ACL rules ----

export function listAclRules(filter?: string): Promise<unknown[]> {
  return list('acl-rules', filter);
}

export function getAclRule(id: string): Promise<unknown> {
  return getOne('acl-rules', id);
}

export function createAclRule(body: unknown): Promise<unknown> {
  return create('acl-rules', body);
}

export function updateAclRule(id: string, body: unknown): Promise<unknown> {
  return update('acl-rules', id, body);
}

export function deleteAclRule(id: string): Promise<unknown> {
  return remove('acl-rules', id);
}

export function getAclRuleOrder(): Promise<unknown> {
  return get(sitePath('acl-rules/ordering'));
}

export function setAclRuleOrder(body: unknown): Promise<unknown> {
  return put(sitePath('acl-rules/ordering'), body);
}

// ---- DNS policies ----

export function listDnsPolicies(filter?: string): Promise<unknown[]> {
  return list('dns/policies', filter);
}

export function getDnsPolicy(id: string): Promise<unknown> {
  return getOne('dns/policies', id);
}

export function createDnsPolicy(body: unknown): Promise<unknown> {
  return create('dns/policies', body);
}

export function updateDnsPolicy(id: string, body: unknown): Promise<unknown> {
  return update('dns/policies', id, body);
}

export function deleteDnsPolicy(id: string): Promise<unknown> {
  return remove('dns/policies', id);
}

// ---- traffic-matching lists (reusable filters for firewall policies) ----

export function listTrafficMatchingLists(filter?: string): Promise<unknown[]> {
  return list('traffic-matching-lists', filter);
}

export function getTrafficMatchingList(id: string): Promise<unknown> {
  return getOne('traffic-matching-lists', id);
}

export function createTrafficMatchingList(body: unknown): Promise<unknown> {
  return create('traffic-matching-lists', body);
}

export function updateTrafficMatchingList(id: string, body: unknown): Promise<unknown> {
  return update('traffic-matching-lists', id, body);
}

export function deleteTrafficMatchingList(id: string): Promise<unknown> {
  return remove('traffic-matching-lists', id);
}

// ---- hotspot vouchers ----

export function listVouchers(filter?: string): Promise<unknown[]> {
  return list('hotspot/vouchers', filter);
}

export function getVoucher(id: string): Promise<unknown> {
  return getOne('hotspot/vouchers', id);
}

export function createVouchers(body: unknown): Promise<unknown> {
  return create('hotspot/vouchers', body);
}

export function deleteVoucher(id: string): Promise<unknown> {
  return remove('hotspot/vouchers', id);
}

export function deleteVouchersByFilter(filter: string): Promise<unknown> {
  return del(sitePath(`hotspot/vouchers?filter=${encodeURIComponent(filter)}`));
}

// ---- VPN ----

export function listVpnServers(filter?: string): Promise<unknown[]> {
  return list('vpn/servers', filter);
}

export function listSiteToSiteTunnels(filter?: string): Promise<unknown[]> {
  return list('vpn/site-to-site-tunnels', filter);
}

// ---- switching (read-only) ----

export function listSwitchStacks(filter?: string): Promise<unknown[]> {
  return list('switching/switch-stacks', filter);
}

export function getSwitchStack(id: string): Promise<unknown> {
  return getOne('switching/switch-stacks', id);
}

export function listMcLagDomains(filter?: string): Promise<unknown[]> {
  return list('switching/mc-lag-domains', filter);
}

export function getMcLagDomain(id: string): Promise<unknown> {
  return getOne('switching/mc-lag-domains', id);
}

export function listLags(filter?: string): Promise<unknown[]> {
  return list('switching/lags', filter);
}

export function getLag(id: string): Promise<unknown> {
  return getOne('switching/lags', id);
}

// ---- misc read-only reference data ----

export function listRadiusProfiles(filter?: string): Promise<unknown[]> {
  return list('radius/profiles', filter);
}

export function listDpiCategories(filter?: string): Promise<unknown[]> {
  return listTop('dpi/categories', filter);
}

export function listDpiApplications(filter?: string): Promise<unknown[]> {
  return listTop('dpi/applications', filter);
}

export function listCountries(filter?: string): Promise<unknown[]> {
  return listTop('countries', filter);
}

// ---- raw escape hatch ----

// `endpoint` is the full path under the API prefix, e.g.
// "/v1/sites/<id>/devices" — the "current" shorthand for the configured
// siteId is resolved in commands/core.ts before this is called.
export function raw<T = unknown>(method: string, endpoint: string, body?: unknown): Promise<T> {
  return rest<T>(method, endpoint, body);
}

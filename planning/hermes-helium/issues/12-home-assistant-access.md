# Decide how Hermes reaches Home Assistant, and what it may read

Type: grilling
Status: open
Blocked by: 06

## Question

**How does Hermes authenticate to Home Assistant, reach it over the network, and
which entities may it read?**

Graduated from `05`'s carry-forward once that ticket established the brief's
contract. Nothing in `03` provisioned HA access — it settled the compose service,
the state volume and the vault mount, and HA never came up. So today there is **no
token, no decided network path, and no entity allowlist**.

Blocked by `06` because `06` decides *whether the brief carries household data at
all*. If it rules HA out, this ticket closes unresolved as out of scope. If it rules
HA in, this ticket is a hard prerequisite for building the brief.

### Why this is a ticket and not a footnote

**HA is the original crime scene.** The v0.14 morning briefing shipped hardcoded
fake weather (11.3 °C / Sunny) that *never queried HA* for an unknown span. `05`'s
**D2** answers the fabrication half — provenance timestamps mean a constant has no
`last_changed` to report — but D2 assumes a working HA query to *have* provenance
from. **An unprovisioned integration and a fabricated one are indistinguishable in
the brief**, so the access path has to be real and verified before D2's control means
anything.

### What the answer must settle

1. **The credential.** A long-lived access token, where it is stored (per `03`: the
   single sops-fed `.env` inside the state volume), and what happens when it is
   revoked — it must surface as `STATUS=ERROR` with stale provenance, never as a
   quiet missing section (`05` **D2**).
2. **The network path.** HA is at `192.168.1.99`, off-box. Hermes is a container in
   helium's stack, and `03` established the deployment shape. Settle whether it
   reaches HA over the LAN directly or the NetBird mesh, and confirm that adds **no
   listening port** — `046` kept its whole slice outbound-only and helium's PRD
   forbids public exposure.
3. **The read surface.** Which entities, and read-only or not. HA holds ~222
   entities including household presence; this map's egress posture (map Notes)
   means **whatever Hermes reads goes to a third-party inference endpoint**. That
   posture was argued for vault and mail content specifically — it does **not**
   automatically extend to live household telemetry like presence, and this ticket
   should not assume it does.
4. **Whether the dependency runs the other way too.** `05`'s **D3** puts Hermes'
   own liveness alarms *into* HA via the existing MQTT→HA path. That direction is
   already settled and needs no token — it is docker2mqtt's publish, not Hermes'.
   Keep the two directions distinct; only the read path is open here.

### Inherited (don't re-derive)

- **`05` **D2**:** every source emits the upstream's own last-updated time. For HA
  that is the entity's **`last_changed`**, which is the specific control against the
  fake-weather class.
- **`05` **D3**:** the MQTT broker at `192.168.1.99` already carries helium's metrics
  as outbound-only publishes (`issues/046`, effectively landed). If a read path is
  wanted, check whether MQTT can serve it before adding an HA API token — reusing a
  wired transport beats a second credential.
- **`046`:** entity **`state`** is the liveness signal; the **`health`** entity does
  **not** clear when a container stops.

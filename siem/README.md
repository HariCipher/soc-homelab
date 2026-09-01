# SIEM

**Status:** ⚠️ DEGRADED — see [STATUS.md](../STATUS.md) · **Phase 2**

## Purpose
Collect, correlate and search everything the lab produces.

| Tier | Tool | Role |
|---|---|---|
| Primary | **Wazuh** | detection engine — agents, rules, decoders, ATT&CK mapping |
| Secondary | **Splunk Free** | search + dashboards (familiar tooling) |
| Future | ELK | after a hardware upgrade — see [decision 001](../docs/decisions.md) |

## Data flow
```
DC01 ──Wazuh agent (1514/tcp)──┐
pfSense ──syslog (514/udp)─────┼──► Wazuh manager ──► alerts.json ──► Splunk
Suricata (host) ───────────────┘     rules + ATT&CK              index=wazuh
```

## Open items
- Splunk is installed but **not running** and has **no systemd unit**
- Splunk `indexes.conf` / `inputs.conf` / `props.conf` are written but **unverified**
- Wazuh has **no web interface** — see [`wazuh/README.md`](wazuh/README.md)

## My changes
*(to be filled in)*

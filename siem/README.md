# SIEM — Wazuh

**Status:** BUILDING manager running · indexer + dashboard PLANNED · **Phase 2**

## Purpose
Collect, correlate, detect and display everything the lab produces. **Wazuh is the
only SIEM in this lab** — Splunk was removed, see [decision 006](../docs/decisions.md).

| Component | Role | Status |
|---|---|---|
| **Manager** | agents, decoders, rules, ATT&CK mapping | BUILDING running |
| **Indexer** (OpenSearch) | stores and searches events | PLANNED |
| **Dashboard** | the web UI | PLANNED |

## Data flow
```
DC01 ──Wazuh agent (1514/tcp)──┐
pfSense ──syslog (514/udp)─────┼──► Wazuh Manager ──filebeat──► Indexer ──► Dashboard
Suricata (host, eve.json) ─────┘        rules + ATT&CK                        │
                                                                              └──► n8n
```

## NOTE: The memory constraint
The dashboard requires the indexer, and the indexer is the largest consumer in the
lab. It only fits because:
1. Splunk was removed
2. DC01 dropped 4 GB → 3 GB
3. **The JVM heap is capped at 1 GB before first start** — the default will OOM this host

Details and the exact steps: [`docs/SETUP-GUIDE.md`](../docs/SETUP-GUIDE.md) §2.

## Version discipline
Manager, indexer, dashboard and **every agent** must be the same Wazuh version.
```bash
/var/ossec/bin/wazuh-control info     # the version everything else must match
```

## Verify
```bash
systemctl is-active wazuh-manager wazuh-indexer wazuh-dashboard
sudo /var/ossec/bin/agent_control -l
curl -sk -u admin:<pw> https://127.0.0.1:9200/_cluster/health?pretty
free -h                                # need ≥1 GB free with both VMs up
```

## Upstream
Wazuh (manager · indexer · dashboard · agents)

## My changes
*(to be filled in — custom rules live in `../detection/wazuh-rules/`)*

# Wazuh

**Status:** ⚠️ DEGRADED · manager running, nothing proven end-to-end

## The web interface problem

The official **Wazuh Dashboard requires the Wazuh indexer (OpenSearch)**. On this
host that is not affordable — see [decision 005](../../docs/decisions.md). But a CLI-only
SIEM is not a SIEM you can demonstrate, so an interface is required.

### Options

| # | Option | RAM | Trade-off |
|---|---|---|---|
| A | **Wazuh alerts → Splunk dashboards** | 0 extra | Uses tooling already installed and already known. No native Wazuh agent-management UI. |
| B | **Full Wazuh indexer + dashboard, heap-tuned** | ~2–3 G | The real product, real agent management. Tight on this host; feasible after a RAM upgrade. |
| C | **Wazuh indexer + dashboard, started on demand** | ~2–3 G when up | Full UI when needed; stop it to reclaim RAM. Adds start/stop friction. |
| D | **Wazuh REST API (`:55000`) + custom views** | ~0 | Full control, most work, no ready-made UI. |

### Chosen approach — 📋 to confirm

**Now:** Option A — Splunk as the visual layer for Wazuh alerts (0 extra RAM,
Phase 2 already routes `alerts.json` into `index=wazuh`).
**After a 32 GB upgrade:** Option B — the real Wazuh Dashboard.

Option C is the fallback if agent-management UI is needed sooner than the upgrade.

> ⚠️ **Verify before relying on it:** the official *Wazuh App for Splunk* has had
> patchy support across recent Wazuh versions. Confirm compatibility with the
> installed manager version before committing to it — otherwise build the Splunk
> dashboards directly against `index=wazuh`, which always works.

## Verify
```bash
systemctl is-active wazuh-manager
sudo /var/ossec/bin/agent_control -l          # agents enrolled
ss -lntup | grep -E '1514|1515|55000'         # manager listeners
```

## Upstream
Wazuh — manager 4.14.3 (**agents must match this version**)

## My changes
*(to be filled in — custom rules live in `detection/wazuh-rules/`)*

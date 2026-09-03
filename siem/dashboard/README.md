# Wazuh dashboard

**Status:** PLANNED · **Phase 2**

The web UI — agent management, alert search, MITRE ATT&CK views, rule browsing.
This is what makes the lab demonstrable, and the reason the indexer is worth its
memory cost.

## Verify
```bash
systemctl status wazuh-dashboard
curl -sk -o /dev/null -w '%{http_code}\n' https://127.0.0.1/     # expect 200/302
```

screenshot Capture into `evidence/siem/` once live: overview page, agent list, an alert
detail view, and a MITRE ATT&CK view.

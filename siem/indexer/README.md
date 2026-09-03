# Wazuh indexer

**Status:** PLANNED · **Phase 2**

OpenSearch-based storage and search backend. Required by the dashboard.

## Non-negotiable settings on this host
```bash
# /etc/wazuh-indexer/jvm.options.d/heap.options
-Xms1g
-Xmx1g
```
Set this **before the first start**. The default heap sizing assumes a dedicated
server and will consume most of this 15 GB host.

Single-node cluster — `"status": "yellow"` is normal and expected.

## Retention
This host cannot hold months of logs. Configure an index state management policy in
the dashboard to delete `wazuh-alerts-*` after a small number of days.

## Verify
```bash
curl -sk -u admin:<pw> https://127.0.0.1:9200/_cluster/health?pretty
systemctl status wazuh-indexer
```

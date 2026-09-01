# Splunk

**Status:** ⚠️ DEGRADED — installed at `/opt/splunk`, **not running**, no systemd unit

## Role
Search and dashboard layer. Secondary to Wazuh — see [decision 001](../../docs/decisions.md).

## Limits of Splunk Free (know these before designing around it)
- 500 MB/day ingest cap
- no authentication
- no alerting, no scheduled searches

Fine as a search UI and visual layer. Not the detection engine.

## Indexes
| Index | Source |
|---|---|
| `wazuh` | `/var/ossec/logs/alerts/alerts.json` |
| `pfsense` | syslog UDP 5514 |

## Open items
- Not running · make it a boot service: `sudo /opt/splunk/bin/splunk enable boot-start`
- UDP 5514 input written but never observed binding — re-test once Splunk is up

## Verify
```bash
sudo /opt/splunk/bin/splunk status
ss -lntup | grep -E '8000|5514'
```

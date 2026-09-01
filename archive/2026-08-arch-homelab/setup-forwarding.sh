#!/usr/bin/env bash
# Wire Wazuh + pfSense logs into Splunk.  Run:  sudo bash setup-forwarding.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

SPLUNK=/opt/splunk
OSSEC=/var/ossec

echo "==> [1/4] Splunk: index 'wazuh' + 'pfsense'"
mkdir -p "$SPLUNK/etc/system/local"
cat > "$SPLUNK/etc/system/local/indexes.conf" <<'EOF'
[wazuh]
homePath   = $SPLUNK_DB/wazuh/db
coldPath   = $SPLUNK_DB/wazuh/colddb
thawedPath = $SPLUNK_DB/wazuh/thaweddb
maxTotalDataSizeMB = 5000

[pfsense]
homePath   = $SPLUNK_DB/pfsense/db
coldPath   = $SPLUNK_DB/pfsense/colddb
thawedPath = $SPLUNK_DB/pfsense/thaweddb
maxTotalDataSizeMB = 5000
EOF

echo "==> [2/4] Splunk: file monitor on Wazuh alerts + syslog UDP 5514"
cat > "$SPLUNK/etc/system/local/inputs.conf" <<'EOF'
[monitor:///var/ossec/logs/alerts/alerts.json]
disabled    = false
index       = wazuh
sourcetype  = wazuh:alerts
crcSalt     = <SOURCE>

[monitor:///var/ossec/logs/archives/archives.log]
disabled    = true
index       = wazuh
sourcetype  = wazuh:archives

# pfSense also sends a copy straight to Splunk (Wazuh takes 514, Splunk takes 5514)
[udp://5514]
disabled    = false
index       = pfsense
sourcetype  = pfsense:syslog
connection_host = ip
EOF

cat > "$SPLUNK/etc/system/local/props.conf" <<'EOF'
[wazuh:alerts]
INDEXED_EXTRACTIONS = json
KV_MODE             = none
TIMESTAMP_FIELDS    = timestamp
SHOULD_LINEMERGE    = false
TRUNCATE            = 0
EOF

echo "==> [3/4] Wazuh: enable syslog listener on 514/udp for the lab subnet"
cp -n "$OSSEC/etc/ossec.conf" "$OSSEC/etc/ossec.conf.bak.$(date +%F)" || true
if grep -q "<connection>syslog</connection>" "$OSSEC/etc/ossec.conf"; then
  echo "    syslog remote block already present - skipping"
else
  python3 - "$OSSEC/etc/ossec.conf" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
block="""
  <remote>
    <connection>syslog</connection>
    <port>514</port>
    <protocol>udp</protocol>
    <allowed-ips>192.168.50.0/24</allowed-ips>
  </remote>
"""
# insert before the LAST </ossec_config>
i=s.rindex("</ossec_config>")
open(p,"w").write(s[:i]+block+s[i:])
print("    inserted <remote> syslog block")
PY
fi

echo "==> [4/4] Restart services"
systemctl restart wazuh-manager
"$SPLUNK/bin/splunk" restart --accept-license --answer-yes --no-prompt >/dev/null

echo
echo "==> Verify"
sleep 5
ss -lun | grep -E ':(514|5514) ' || echo "  !! syslog ports not listening yet"
ss -ltn | grep -E ':(1514|8000) ' || true
echo
echo "DONE. Now in pfSense GUI:"
echo "  Status -> System Logs -> Settings -> Remote Logging"
echo "    Enable, Source Address = LAN, Remote server 1 = 192.168.50.2:514"
echo "                                  Remote server 2 = 192.168.50.2:5514"
echo "    Tick: Firewall events, DHCP, System, VPN, Portal Auth"
echo
echo "Then in Splunk (http://localhost:8000):  index=wazuh OR index=pfsense"

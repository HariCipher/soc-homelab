> ARCHIVED **ARCHIVED — previous work, not the current environment.**
> Kept for reference and component migration. Any status claims below
> reflect 2026-08-08 and are **not** current. Live status: [STATUS.md](../../STATUS.md)

---

# RESUME HERE
**Saved:** 2026-08-08 · session paused after pfSense General Setup was filled in

---

## Snapshot of state at pause

| Component | State |
|---|---|
| pfSense VM | **shut off** (was fully configured + General Setup completed) |
| ad-dc VM (DC01) | **shut off** (AD DS + DNS promoted, healthy) |
| VM autostart | **disabled** on both — must start manually |
| Wazuh manager | active · 1514/1515/55000 · **syslog listener on 514/udp is UP** |
| Splunk | running · web :8000 |
| Splunk configs | `indexes.conf`, `inputs.conf`, `props.conf` written DONE |
| Splunk UDP :5514 input | NOTE: **not listening** — needs checking (see below) |

`setup-forwarding.sh` **was run** — Wazuh's 514 listener and all three Splunk
conf files are in place. Only the 5514 UDP input didn't come up.

---

## Start the lab back up

```bash
virsh -c qemu:///system start pfsense
virsh -c qemu:///system start ad-dc

# give pfSense ~60s, DC01 ~90s, then verify:
ping -c3 192.168.50.1
curl -sk -o /dev/null -w '%{http_code}\n' https://192.168.50.1/     # expect 200
ping -c3 192.168.50.10
```

Optional — make them come up with the host:
```bash
sudo virsh -c qemu:///system autostart pfsense
sudo virsh -c qemu:///system autostart ad-dc
```

### Full health check (paste as one block)
```bash
python3 - <<'EOF'
import socket,struct,random
def q(name,qtype=1,server='192.168.50.10'):
    hdr=struct.pack('>HHHHHH',random.randint(0,65535),0x0100,1,0,0,0)
    qn=b''.join(bytes([len(l)])+l.encode() for l in name.split('.'))+b'\x00'
    s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); s.settimeout(6)
    s.sendto(hdr+qn+struct.pack('>HH',qtype,1),(server,53))
    d,_=s.recvfrom(4096); return d[3]&0xF, struct.unpack('>H',d[6:8])[0]
for n,t in [('dc01.homelab.lan',1),('archlinux.org',1),('_ldap._tcp.homelab.lan',33)]:
    try:
        r,a=q(n,t); print(f"{n:30} rcode={r} answers={a} {'OK' if r==0 and a else 'FAIL'}")
    except Exception as e: print(f"{n:30} ERROR {e}")
EOF
```

---

## Pick up exactly here — next 3 things

### 1. Fix the Splunk UDP:5514 input (5 min)
It's configured but not bound. Check why:
```bash
sudo /opt/splunk/bin/splunk restart
ss -lun | grep 5514
sudo tail -50 /opt/splunk/var/log/splunk/splunkd.log | grep -i udp
```

### 2. pfSense remote syslog (GUI, 5 min)
`Status → System Logs → Settings → Remote Logging`
- Enable Remote Logging DONE
- Source Address: **LAN**
- Remote server 1: `192.168.50.2:514`   ← Wazuh
- Remote server 2: `192.168.50.2:5514`  ← Splunk
- Tick: Firewall events, DHCP, System, VPN, Portal Auth

Verify: `index=pfsense` in Splunk, and `sudo tail -f /var/ossec/logs/alerts/alerts.json`

### 3. Wazuh agent on DC01 (10 min)
Manager is **4.14.3** — agent version must match.
```powershell
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.3-1.msi -OutFile C:\wazuh.msi
msiexec /i C:\wazuh.msi /q WAZUH_MANAGER="192.168.50.2" WAZUH_REGISTRATION_SERVER="192.168.50.2" WAZUH_AGENT_NAME="DC01"
NET START Wazuh
```
Verify from host: `sudo /var/ossec/bin/agent_control -l`

---

## Then (not urgent)
- `virsh snapshot-create-as pfsense healthy` + same for ad-dc ← **do this first thing once both boot clean**
- pfSense DHCP scope: Services → DHCP Server → LAN → DNS = `192.168.50.10`, domain `homelab.lan`
- DC01 time sync: `w32tm /config /manualpeerlist:192.168.50.1 /syncfromflags:manual /update`
- Honeypot VM at 192.168.50.20 (see 75HARD-UPDATE.md Tier 2)

---

## Credentials (lab only)
- pfSense: `admin` / `Homelab2026!` → https://192.168.50.1/
- DC01: `Administrator` / `Homelab2026!` · domain `homelab.lan` · NetBIOS `HOMELAB`
- Splunk: http://localhost:8000

## Key addresses
| Host | IP |
|---|---|
| Arch host on labnet | 192.168.50.2 |
| pfSense LAN | 192.168.50.1 |
| pfSense WAN | DHCP on 192.168.122.0/24 |
| DC01 | 192.168.50.10 |
| Honeypot (planned) | 192.168.50.20 |

## Files in this repo
- `CLAUDE.md` — project context + current state
- `HOMELAB.md` — topology, runbook, pfSense settings table, roadmap
- `75HARD-UPDATE.md` — the write-up with flowcharts (ASCII + Mermaid)
- `setup-forwarding.sh` — log forwarding setup (already run)
- `RESUME-HERE.md` — this file

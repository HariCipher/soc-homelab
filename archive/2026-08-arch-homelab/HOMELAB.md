> ARCHIVED **ARCHIVED — previous work, not the current environment.**
> Kept for reference and component migration. Any status claims below
> reflect 2026-08-08 and are **not** current. Live status: [STATUS.md](../../STATUS.md)

---

# Homelab — Topology, Runbook, Roadmap
Last verified: 2026-08-08

## 1. Topology / Traffic Flow

```
                    ┌──────────────────────────────────────────┐
                    │            INTERNET                      │
                    └───────────────────┬──────────────────────┘
                                        │
                              wlp0s20f3 (10.94.63.108/24)
                                        │  host NAT
                    ┌───────────────────▼──────────────────────┐
                    │  ARCH HOST "larper"                      │
                    │  Wazuh manager · Splunk · libvirt/KVM    │
                    └──┬──────────────────────────┬────────────┘
                       │                          │
        virbr0 "default" 192.168.122.1/24   virbr-lab "labnet" 192.168.50.2/24
              (NAT, has internet)               (isolated, no NAT)
                       │                          │
                  ┌────▼─────┐                    │
                  │ vtnet0   │                    │
                  │  WAN     │                    │
              ┌───┴──────────┴───┐                │
              │   pfSense VM     │                │
              │  firewall/router │                │
              │  DNS resolver    │                │
              │  DHCP server     │                │
              └───┬──────────────┘                │
                  │ vtnet1 LAN 192.168.50.1/24    │
                  └──────────────┬────────────────┘
                                 │  (virbr-lab L2 segment)
                    ┌────────────┴─────────────┐
                    │                          │
            ┌───────▼────────┐         ┌───────▼────────┐
            │  DC01 (AD-DC)  │         │  host tap      │
            │ Win Server2025 │         │ 192.168.50.2   │
            │ 192.168.50.10  │         │ (mgmt access)  │
            │ AD DS + DNS    │         └────────────────┘
            │ homelab.lan    │
            └────────────────┘
```

### DNS resolution flow
```
Domain client / DC01
        │  query "google.com"
        ▼
  DC01 DNS (192.168.50.10)   ── authoritative for homelab.lan
        │  not local → forwarder
        ▼
  pfSense resolver (192.168.50.1)
        │
        ▼
  Host NAT (virbr0) → wlp0s20f3 → Internet
```

### Log / monitoring flow (to build)
```
DC01 Windows Event Log ─┐
pfSense filter/system  ─┼─► Wazuh manager (host) ─► alerts
Honeypot (planned)     ─┘         │
                                  └─► Splunk (host) ─► dashboards/search
```

---

## 2. Proof-it-works runbook (run these to demo the lab)

Run each, screenshot/paste output. This is your "everything works" evidence pack.

```bash
# A. VMs are up
virsh -c qemu:///system list --all

# B. pfSense LAN reachable + Web GUI serving
ping -c3 192.168.50.1
curl -sk -o /dev/null -w '%{http_code}\n' https://192.168.50.1/     # expect 200

# C. DC reachable
ping -c3 192.168.50.10

# D. DC DNS answers internal AND external (the key integration test)
dig @192.168.50.10 dc01.homelab.lan +short
dig @192.168.50.10 archlinux.org    +short
dig @192.168.50.10 _ldap._tcp.homelab.lan SRV +short   # AD SRV records

# E. Host services
systemctl is-active wazuh-manager
systemctl is-active splunk   # or: /opt/splunk/bin/splunk status
```

On DC01 console (virsh console ad-dc / screenshot):
```powershell
Get-ADDomain | fl Name,DNSRoot,NetBIOSName,DomainMode
Get-Service NTDS,DNS,Netlogon,kdc | ft Name,Status
Resolve-DnsName archlinux.org      # external via own DNS
nltest /dsgetdc:homelab.lan        # DC locator works
dcdiag /q                          # empty output = healthy
```

---

## 3. pfSense — what to answer in the setup wizard / General Info

When pfSense asks (System → General Setup or the first-boot wizard):

| Field | Put this |
|---|---|
| Hostname | `pfsense` |
| Domain | `homelab.lan` |
| Primary DNS Server | `192.168.50.10` (DC01) — **only if** you check "Do not use the DNS Forwarder as a DNS server for the firewall" is left UNCHECKED carefully |
| Secondary DNS | `1.1.1.1` or `8.8.8.8` |
| DNS Server Override (DHCP WAN) | **uncheck** — don't let upstream DHCP overwrite your DNS |
| Timezone | your local zone (e.g. `Asia/Kolkata` / `Etc/UTC`) |
| NTP server | `pool.ntp.org` (time sync matters — Kerberos breaks at >5 min skew) |
| WAN interface | DHCP (it's on the NAT net), leave "Block RFC1918 private networks" **UNCHECKED** (your WAN *is* RFC1918) |
| WAN "Block bogon networks" | uncheck for lab |
| LAN IP | `192.168.50.1 / 24` |
| Admin password | `Homelab2026!` |

**Important DNS design note:** on a lab with AD, the correct pattern is:
- Domain members point ONLY at DC01 (192.168.50.10)
- DC01 forwards to pfSense (192.168.50.1)
- pfSense forwards/resolves to internet

Do **not** hand out 1.1.1.1 to domain clients via DHCP — it breaks domain join.
In pfSense: Services → DHCP Server → LAN → DNS servers = `192.168.50.10`.

---

## 4. Work still pending (nothing blocking, all additive)

| # | Item | Why |
|---|---|---|
| 1 | pfSense DHCP scope on LAN with DNS = 192.168.50.10, domain = homelab.lan | so future clients auto-join correctly |
| 2 | Set DC01 to static (already static) + disable IPv6 on labnet or leave (fine) | tidiness |
| 3 | NTP: point DC01 at pfSense as time source (`w32tm /config /manualpeerlist:192.168.50.1 /syncfromflags:manual /update`) | Kerberos needs tight time |
| 4 | Wazuh agent on DC01 → host manager 192.168.50.2 | get Windows events into Wazuh |
| 5 | pfSense remote syslog → 192.168.50.2 (Wazuh/Splunk) | firewall visibility |
| 6 | Splunk inputs for Wazuh alerts (`/var/ossec/logs/alerts/alerts.json`) | single pane |
| 7 | Snapshot both VMs once healthy (`virsh snapshot-create-as`) | rollback point |
| 8 | Add a Windows 10/11 client VM and domain-join it | proves AD end-to-end |
| 9 | Honeypot VM back onto labnet (see §6) | the fun part |

---

## 5. Must-do practices (do these, they're the difference between a lab and a mess)

1. **Snapshot before every experiment.** `virsh snapshot-create-as <vm> pre-<change>`
2. **Document every IP/credential in this repo** — you already lost time twice to
   "which interface was WAN again".
3. **One change, one verification.** Never stack 3 config changes then test.
4. **Time sync everywhere.** AD/Kerberos silently dies on clock skew.
5. **Never put lab creds anywhere near real accounts.** `Homelab2026!` is a lab-only password.
6. **Keep the lab isolated.** labnet has no NAT by design — the only route out is
   through pfSense, which is exactly what makes it a useful security lab.
7. **Back up AD**: `wbadmin start systemstatebackup` or just snapshot DC01 weekly.
8. **Log everything to the host, not the VM.** VMs get rebuilt; logs shouldn't vanish.

## 6. Future practice / attack-lab roadmap

**Tier 1 — visibility (do first)**
- Wazuh agent on DC01 + pfSense syslog → confirm you see a failed logon in Wazuh
- Enable Windows Advanced Audit Policy (logon, process creation 4688, PowerShell 4104)
- Sysmon on DC01 with a good config (SwiftOnSecurity baseline)

**Tier 2 — honeypot migration (from your old lab)**
- Rebuild the honeypot as its own VM on `labnet`, e.g. 192.168.50.20
- Options: **T-Pot** (all-in-one, needs ~8GB RAM), or lightweight **Cowrie** (SSH/Telnet)
  + **Dionaea** (malware) on a small Debian VM
- Firewall it in pfSense as its own segment/VLAN so it can't reach DC01 —
  create an alias `HONEYPOT` and a rule: `HONEYPOT → LAN net = BLOCK`
- Forward honeypot logs → Wazuh/Splunk, build a "attacks seen today" dashboard
- Port-forward on pfSense WAN → honeypot for the ports you want probed

**Tier 3 — adversary emulation**
- Kali/Parrot VM on labnet as the attacker box
- Run: BloodHound collection, Kerberoasting, AS-REP roasting, LLMNR poisoning
  (Responder), pass-the-hash — then hunt each one in Wazuh/Splunk
- Atomic Red Team for repeatable technique-by-technique detection testing
- Map your detections to MITRE ATT&CK; track coverage in a simple spreadsheet

**Tier 4 — hardening loop**
- Apply a CIS/STIG baseline to DC01, re-run the attacks, see what broke
- LAPS, tiered admin model, gMSA
- pfSense: Suricata/Snort IDS on LAN, pfBlockerNG

# ROADMAP

Build order is **bottom-up by layer**: L2 → L3 → DNS → service → telemetry →
detection → response. Every failure in the previous lab was a layer problem, so
each phase must fully pass before the next begins.

**Rule for every step:** one change → one verification → one screenshot → one commit.

---

## RAM budget — the hard constraint

```
Host total        15.0 G
Host baseline      8.1 G   (desktop + Wazuh manager)
Available          6.9 G
```

| Workload | RAM | Notes |
|---|---|---|
| pfSense | 1.0 G | Suricata moved to host, so no bump needed |
| DC01 | 3.0 G | reduced from 4 G |
| Suricata | ~0.5 G | **on host**, sniffing `virbr-lab` — no VM |
| n8n | ~0.5 G | host container |
| Attack tooling | 0 G | **run from the host**, no Kali VM |
| Honeytokens | 0 G | AD objects, not a machine |
| Honeypot container | ~0.3 G | optional, host container |

**Total ≈ 5.3 G of 6.9 G — all six phases fit without a hardware upgrade.**
A 32 GB upgrade later unlocks: Wazuh Dashboard/indexer, a Windows client VM,
a dedicated attacker VM, and ELK alongside.

---

## Phase 1 — Foundation

Prove what already exists actually works today.

| # | Step |
|---|---|
| 1.1 | Boot pfSense (wait 60 s) |
| 1.2 | Boot DC01 (wait 90 s) |
| 1.3 | Give the host an address on labnet — `192.168.50.2/24` on `virbr-lab`, **made persistent** |
| 1.4 | Make Splunk a systemd service so it survives reboot |
| 1.5 | pfSense DHCP scope: DNS = `192.168.50.10`, domain = `homelab.lan` |
| 1.6 | DC01 time sync → pfSense (Kerberos fails on >5 min skew) |
| 1.7 | Snapshot both VMs as `healthy` — the moment they are clean |

**Exit criteria** — `scripts/verify/01-foundation.sh` exits 0:
- pfSense and DC01 both reply to ping, 0% loss
- pfSense web GUI returns HTTP 200
- DC01 resolves internal (`dc01.homelab.lan`), external (`archlinux.org`) and AD SRV records
- `dcdiag /q` produces no output

📸 pfSense dashboard · `Get-ADDomain` output · verify script passing

---

## Phase 2 — Telemetry

Get logs off the boxes and into the pipeline.

| # | Step |
|---|---|
| 2.1 | Wazuh agent on DC01 → manager `192.168.50.2` (**agent version must match manager**) |
| 2.2 | Windows advanced audit policy: logon/logoff, **4688** process creation, **4104** PowerShell script block |
| 2.3 | Sysmon + SwiftOnSecurity config on DC01 |
| 2.4 | pfSense remote syslog → `192.168.50.2:514` |
| 2.5 | Splunk ingests `/var/ossec/logs/alerts/alerts.json` → `index=wazuh` |
| 2.6 | Stand up a **Wazuh web interface** — see `siem/wazuh/README.md` |

**Exit criteria:** deliberately fail a logon on DC01 → event **4625** visible in
Wazuh → same event visible in Splunk. One end-to-end test proves the whole layer.

📸 agent Active · the 4625 alert · a Sysmon process-creation event

---

## Phase 3 — Detection

| # | Step |
|---|---|
| 3.1 | Suricata **on the host**, sniffing `virbr-lab` in promiscuous mode |
| 3.2 | Tune out false positives — an untuned IDS is noise, not detection |
| 3.3 | Write custom Wazuh rules for the gaps found |
| 3.4 | Map every detection to a MITRE ATT&CK technique |
| 3.5 | Validate each with Atomic Red Team |

**Exit criteria:** ≥5 detections that fire reliably, each mapped to a technique and
each reproducible by a documented test.

📸 Suricata alert · MITRE coverage table · a custom rule firing

---

## Phase 4 — Deception

| # | Step |
|---|---|
| 4.1 | **Honeytokens first** — a decoy AD account and a decoy file share with auditing. Zero RAM, high signal. |
| 4.2 | Alert on any touch of either |
| 4.3 | *(optional)* containerised honeypot on labnet, **firewalled off from DC01 first** |

A honeypot that can reach the domain controller is just a compromised host. The
isolation rule is written before the honeypot is deployed, never after.

📸 the honeytoken alert firing

---

## Phase 5 — Automation (n8n SOAR)

| # | Playbook |
|---|---|
| 5.1 | **Enrich** — alert in, IP/hash reputation out |
| 5.2 | **Notify** — formatted alert to a chat/mail sink |
| 5.3 | **Contain** — block a source IP on pfSense via its API |

**Exit criteria:** one alert travels Wazuh → n8n → action with zero manual steps.

📸 workflow canvas · a successful execution log

---

## Phase 6 — Practice (attack → hunt → harden)

Attack tooling runs **from the Arch host**, which already sits on labnet — no
attacker VM required.

| Attack | Hunt it in | Outcome |
|---|---|---|
| Kerberoasting | Wazuh · event 4769 | detection rule |
| AS-REP roasting | Wazuh · audit log | detection rule |
| LLMNR/NBT-NS poisoning | Suricata | detection rule |
| BloodHound / LDAP enumeration | LDAP query volume | detection rule |
| Pass-the-hash | event 4624 logon type 9 | detection rule |

The point is never the attack — it is whether the detection fired. Each one becomes
a writeup in `operations/investigations/`.

Then harden: CIS baseline on DC01, LAPS, tiered admin — and re-run every attack to
see what stops working.

---

## Documenting

Documentation is not a final phase — it happens inside every phase:

| When | Where |
|---|---|
| During work | `lab-journal/YYYY-MM-DD.md` — what I did, what broke |
| On a verify pass | `STATUS.md` + screenshot in `evidence/` |
| On a design decision | `docs/decisions.md` — the why, and what was rejected |
| On phase completion | folder README — Design · Verify · Upstream · My changes |

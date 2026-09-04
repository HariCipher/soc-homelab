# ROADMAP — build plan

**Scope: build the platform.** Adversary emulation and hunting practice are deferred
until every phase below is verified.

Build order is **bottom-up by layer**: L2 → L3 → DNS → SIEM → telemetry → detection
→ response. Every failure in the previous lab was a layer problem.

**Rule for every step:** one change → one verification → one screenshot → one commit.

---

## RAM budget — the hard constraint

Wazuh replaces Splunk, and the Wazuh **Dashboard requires the indexer (OpenSearch)**.
That is the expensive part, so everything else is trimmed to pay for it.

```
Host total                    15.0 G
Host OS + desktop baseline     ~6.5 G
Budget for lab + SIEM          ~8.5 G
```

| Workload | RAM | Note |
|---|---|---|
| pfSense | 1.0 G | Suricata moved to host, so no bump |
| DC01 | **3.0 G** | reduced from 4 G — Server Core runs fine |
| Wazuh manager | ~0.5 G | already running |
| Wazuh indexer | **~1.5 G** | JVM heap **capped at 1 G** — not default |
| Wazuh dashboard | ~0.6 G | |
| Suricata | ~0.5 G | on host, sniffs `virbr-lab` |
| **Total** | **~7.6 G** | fits, with ~1 G margin |

**Three things make it fit:**
1. Splunk removed — reclaims 4 GB disk and its memory footprint
2. DC01 dropped 4 G → 3 G
3. Indexer JVM heap pinned to 1 G (the default sizing will OOM this host)

**Accept the trade-off:** short log retention. Tune index lifecycle to days, not
months. A 32 GB upgrade later removes this constraint entirely.

---

## Phase 1 — Foundation BUILDING *(nearly done)*

| # | Step | State |
|---|---|---|
| 1.1 | pfSense and DC01 booting | yes done |
| 1.2 | Host address `192.168.50.2/24` on `virbr-lab` | yes set, **not persistent** |
| 1.3 | Make the host labnet address persistent | |
| 1.4 | Reduce DC01 memory 4 G → 3 G | |
| 1.5 | pfSense DHCP scope: DNS `192.168.50.10`, domain `homelab.lan` | |
| 1.6 | DC01 time sync → pfSense | |
| 1.7 | **Snapshot both VMs as `healthy`** | **blocking** |

**Exit criteria:** `scripts/verify/01-foundation.sh` exits 0 (11/11).
Currently 9/11 — only the two snapshot checks fail.

screenshot pfSense dashboard · `Get-ADDomain` output · verify script passing

---

## Phase 2 — SIEM platform (Wazuh)

| # | Step |
|---|---|
| 2.1 | Remove Splunk — stop it, uninstall, reclaim `/opt/splunk` |
| 2.2 | Install Wazuh indexer (single node) |
| 2.3 | **Cap JVM heap at 1 G** before first start — `-Xms1g -Xmx1g` |
| 2.4 | Install Wazuh dashboard, point it at the indexer |
| 2.5 | Connect manager → indexer (filebeat) |
| 2.6 | Aggressive index lifecycle — short retention |

**Exit criteria:** dashboard loads over HTTPS, shows the manager, and displays live
events. Host still has ≥1 GB free with both VMs running.

screenshot Wazuh dashboard overview · `free -h` proving headroom

---

## Phase 3 — Telemetry

| # | Step |
|---|---|
| 3.1 | Wazuh agent on DC01 → manager `192.168.50.2`. **Agent version must match the manager.** |
| 3.2 | Windows advanced audit policy: logon/logoff, **4688** process creation |
| 3.3 | PowerShell **4104** script-block logging |
| 3.4 | Sysmon + SwiftOnSecurity config on DC01 |
| 3.5 | pfSense remote syslog → `192.168.50.2:514` |

**Exit criteria:** deliberately fail a logon on DC01 → **event 4625 visible in the
Wazuh dashboard**. One end-to-end test proves the whole layer.

screenshot agent Active · the 4625 alert in the dashboard · a Sysmon process event

---

## Phase 4 — Network IDS

| # | Step |
|---|---|
| 4.1 | Suricata on the host, `af-packet` on `virbr-lab`, promiscuous |
| 4.2 | ET Open ruleset + `suricata-update` |
| 4.3 | Baseline normal traffic, then tune out false positives |
| 4.4 | Ship `eve.json` into Wazuh |

**Exit criteria:** a deliberate probe from the host to DC01 produces a Suricata alert
that lands in the Wazuh dashboard. False-positive rate documented.

screenshot Suricata alert in the dashboard

---

## Phase 5 — Detection engineering

| # | Step |
|---|---|
| 5.1 | Identify gaps the default ruleset misses |
| 5.2 | Write custom Wazuh rules for them |
| 5.3 | Map each detection to a MITRE ATT&CK technique |
| 5.4 | Write a repeatable test per detection |

**Exit criteria:** ≥5 custom detections, each mapped, each with a test that
reproduces it. **A rule without a test is a guess, not a detection.**

screenshot custom rule firing · MITRE coverage table

---


## After the build — practice DEFERRED

Attack → hunt → harden, run from the host (no attacker VM needed). Kerberoasting,
AS-REP roasting, LLMNR poisoning, LDAP enumeration, pass-the-hash. Each becomes an

**Not started until Phase 7 is verified.**

---

## Documenting

| When | Where |
|---|---|
| On a verify pass | `STATUS.md` + screenshot in `evidence/` |
| On a design decision | `docs/decisions.md` |
| On phase completion | folder README — Design · Verify · Upstream · My changes |

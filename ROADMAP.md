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
| Suricata | **~0.87 G** | on host, sniffs `virbr-lab`; measured 2026-09-11, was budgeted 0.5 G |
| n8n (SOAR) | ~0.4 G | single Node process, idle most of the time |
| **Total** | **~7.9 G** | fits, with ~0.6 G margin |

**Suricata is 370 MiB over budget.** Measured at 870 MiB steady, not the 0.5 G
assumed here. The trimmed ruleset only recovers ~11% (see STATUS, "Suricata's
cost"); the earlier claim that trimming cut it to 230 MiB was a measurement
error. This eats a third of the margin and is the reason the indexer stays
manual-start rather than boot-enabled (issue 9).

**Three things make it fit:**
1. Splunk removed — reclaimed 6.2 GB of disk (it was not running, so almost no RAM)
2. DC01 dropped 4 G → 3 G
3. Indexer JVM heap pinned to 1 G (the default sizing will OOM this host)

**Accept the trade-off:** short log retention. Tune index lifecycle to days, not
months. A 32 GB upgrade later removes this constraint entirely.

---

## Phase 1 — Foundation

| # | Step |
|---|---|
| 1.1 | pfSense and DC01 booting |
| 1.2 | Host address `192.168.50.2/24` on `virbr-lab` |
| 1.3 | Make the host labnet address persistent |
| 1.4 | Reduce DC01 memory 4 G → 3 G |
| 1.5 | pfSense DHCP scope: DNS `192.168.50.10`, domain `homelab.lan` |
| 1.6 | DC01 time sync → pfSense |
| 1.7 | **Snapshot both VMs as `healthy`** |

**Exit criteria:** all 11 foundation checks pass — both libvirt networks present,
the host's labnet address persistent, pfSense GUI answering, DC01 reachable, AD DNS
resolving internal, external and SRV records, and both VMs snapshotted.

screenshot pfSense dashboard · `Get-ADDomain` output · the foundation checks passing

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


## Phase 6 — SOAR automation

| # | Step |
|---|---|
| 6.1 | Install n8n on the host |
| 6.2 | Create a read-only Wazuh API user for n8n |
| 6.3 | Tier 1 playbook — enrich: on alert, pull agent, rule and recent host history |
| 6.4 | Tier 2 playbook — notify: format and deliver a readable summary |
| 6.5 | Wire Wazuh active response to call the n8n webhook |
| 6.6 | Tier 3 playbook — contain: block a source IP on pfSense, disable an AD account |
| 6.7 | Write the reverse action for every containment action, and test it |

**Exit criteria:** a detection from Phase 5 fires, n8n enriches it automatically, and
a containment playbook blocks a test source IP and unblocks it again — both runs
visible in the n8n execution log.

**Safety rule:** Tier 3 runs only against an explicit target list. Never a wildcard,
never DC01's Administrator.

screenshot n8n execution log with an enriched alert - pfSense rule created by the playbook

---

## After the build — practice DEFERRED

Attack, hunt, harden - run from the host, no attacker VM needed. Kerberoasting,
AS-REP roasting, LLMNR poisoning, LDAP enumeration, pass-the-hash. Each one becomes
a detection test that either fires or exposes a gap.

**Not started until Phase 6 is verified.**

---

## Documenting

| When | Where |
|---|---|
| On a verify pass | screenshot in `evidence/` |
| On a design decision | `docs/decisions.md` |
| On phase completion | folder README — Design · Verify · Upstream · My changes |

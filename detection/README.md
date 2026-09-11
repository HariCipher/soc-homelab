# Detection engineering

**Status:** BUILDING · **Phase 4–5**

## Purpose
Turn raw telemetry into alerts that fire reliably — and prove each one with a
repeatable test. This is the core of the lab.

## Contents
| Folder | What |
|---|---|
| `wazuh-rules/` | custom rules and decoders |
| `suricata-rules/` | custom network rules + tuning notes |
| `attack-coverage/` | MITRE ATT&CK coverage matrix |

## Standard for a finished detection
1. Fires on the technique — validated with Atomic Red Team or a manual repro
2. Mapped to a MITRE ATT&CK technique ID
3. False-positive rate understood and documented
4. A written test that reproduces it
5. A screenshot in `evidence/detection/`

A rule without a test is not a detection — it is a guess.

## Upstream
Wazuh ruleset · Suricata ET Open · Sigma · Atomic Red Team · MITRE ATT&CK

## My changes

### Suricata false-positive baseline (Phase 4, step 4.3)

**Window:** 2026-09-08T17:46Z → 2026-09-11T09:21Z (63.6 h of lab uptime).
**Source:** `wazuh-alerts-*` in the indexer, filtered on
`location: /var/log/suricata/eve.json` — read back from the indexer, never
from `eve.json`, so the count proves the whole pipeline and not just the
sensor.

**24 alerts total. 10 deliberate, 14 ambient. Zero malicious.**

| sid | Signature | Count | Verdict | Action |
|---|---|---|---|---|
| 9000001 | SOC-HOMELAB phase4 pipeline probe | 10 | deliberate — the exit-criterion probe | keep |
| 2210054 | SURICATA STREAM excessive retransmissions | 5 | **false positive** — all DC01 ↔ Microsoft CDN over the NAT'd uplink, port 80 | suppress for `192.168.50.0/24` src, keep internal |
| 2067085 | ET INFO NTLM Session Setup Request - Negotiate | 3 | true — my own `rpcclient`/`smbclient` runs from `.2` | **keep** |
| 2067086 | ET INFO NTLMv1 Session Setup Response - Challenge | 3 | true — same sessions, DC01 replying | **keep** |
| 2067087 | ET INFO NTLM Session Setup Request - Auth | 1 | true — same sessions | **keep** |
| 2031071 | ET INFO Microsoft Connection Test | 1 | **false positive** — DC01 NCSI probe, fires every boot | disable |

**Ambient false-positive rate: 6 alerts / 63.6 h = 0.09/hour (≈2.3/day),
against 14 ambient alerts total — a 43% false-positive rate on a base of
almost nothing.**

### What the baseline actually proves

The roadmap assumed tuning would be the work of 4.3. It is not. On this
network ET Open produces **two false positives and eight INFO-class hits in
two and a half days**. There is nothing to tune because there is almost
nothing firing.

The three NTLM rules are the entire ET Open contribution to detecting SMB
authentication here, and they are `INFO`, not `ATTACK`. They are kept for
exactly that reason: they are the only upstream coverage that touches
T1021.002, and Phase 5 builds on them.

**The honest conclusion: ET Open is a perimeter ruleset pointed at an
internal flat network. Phase 5 custom rules are not a bonus on top of ET
Open — on this lab they are the detection capability.**

### Correction to the Phase 4 record

STATUS.md claimed *"The nmap scan of DC01 produced 5 SURICATA STREAM
excessive retransmissions in the indexer."* **That is wrong.** Queried
directly:

- Non-probe Suricata alerts on 2026-09-08, the day of the scan: **0**
- The 5 retransmission alerts are dated 2026-09-09 10:11–10:30Z, between
  DC01 and `167.82.58.172:80` / `167.82.62.172:80` — external HTTP, a day
  after the scan and nothing to do with it.

**The nmap `--top-ports 100` scan against DC01 produced no Suricata alert of
any kind.** The count matched by coincidence and was attributed to the scan
without checking src/dest or date.

This is the fifth instance of the class already named in issues 14, 15, 16
and the `PROMISC` check — a reading that proves something other than what it
claims. See issue 17.

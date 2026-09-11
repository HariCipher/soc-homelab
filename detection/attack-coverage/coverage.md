# MITRE ATT&CK coverage

Phase 5, step 5.3. What this lab can actually detect, and what it cannot.

**Status of every row below: UNVERIFIED.** The rules are written; none has been
observed firing. `scripts/verify/05-detections.sh` is the instrument. Until it
returns PASS for a row, that row is a hypothesis. This file will be wrong in the
usual direction — too generous — until it is measured.

## Why custom rules are the detection layer here

ET Open, measured over 63.6 hours on this network (`detection/README.md`, 4.3):

- 24 alerts total: 10 deliberate probes, 14 ambient, 0 malicious
- a 100-port nmap of the domain controller produced **zero** alerts
- the entire ET contribution to internal detection was three NTLM `INFO` rules
- two false positives, tuned out (2210054, 2031071)

ET Open is a perimeter ruleset pointed at an internal flat network. On this lab
the custom rules below are not a bonus on top of it — they are the capability.

## Coverage

| Rule | Detection | Technique | Tactic | Telemetry | Source proven by | Test |
|---|---|---|---|---|---|---|
| 100100 | Kerberoasting — RC4 service ticket for a user SPN | T1558.003 | Credential Access | 4769 | `02-telemetry.sh` | `05-detections.sh triggers` |
| 100101 | AS-REP roasting — TGT without pre-auth | T1558.004 | Credential Access | 4768 | `02-telemetry.sh` | `05-detections.sh triggers` |
| 100102 | Encoded PowerShell | T1059.001 | Execution | 4104 | `02-telemetry.sh` | `05-detections.sh triggers` |
| 100103 | Service installed with interpreter image path | T1543.003 | Persistence / PrivEsc | 7045 | **not proven** — System channel | `05-detections.sh triggers` |
| 100104 | Internal port scan — firewall drop burst | T1046 | Discovery | filterlog → 87701 | **not proven** — no drop observed | not written |

Rules 100100–100102 depend only on telemetry `02-telemetry.sh` already verifies
(4624/4625/4688, 4104, Sysmon), so they are unblocked by the filterlog work that
consumed most of this session.

## The two gaps, stated plainly

**100103 has an unproven source.** 7045 is on the Windows *System* channel.
`02-telemetry.sh` proves Security and Sysmon/Operational are collected; it says
nothing about System. If that channel is not in the shared `agent.conf`, this
rule cannot fire and the failure is silent — indistinguishable from "no service
was installed". `05-detections.sh` checks for the channel before the rule, for
that reason.

**100104 is not written, deliberately.** It is the most valuable rule of the
five: it closes the exact hole Phase 4 measured, and it is the reason the
filterlog investigation mattered. It will be a frequency rule over stock rule
87701 (pfSense firewall drop) grouped by `srcip`.

It is blocked on one measurement. Decoding is confirmed working — the `pf`
decoder extracts every field, and 87700 fires at level 0 on pass traffic, which
writes no alert *by design*. 87701 is the only pfSense rule above level 0, and
it has not yet been observed. A `nc -vz -w3 192.168.50.1 9999` from the host
timed out, which means the packet was silently dropped rather than rejected —
the right outcome, and the trigger that should produce 87701. The indexer count
confirming it has not been read back yet.

Writing 100104 before that count exists would repeat this session's most
expensive mistake twice over: three days were spent theorising about a missing
pfSense decoder that was never missing, and two conclusions were drawn from
`wazuh-logtest` runs fed hand-typed input the manager never receives.

## What is out of scope, and why

Lateral movement, C2 and exfiltration are not covered. There is one Windows
host. Detections for movement *between* hosts cannot be tested here, and by this
repo's own rule an untestable rule is a guess. Adding them would inflate this
table without adding capability.

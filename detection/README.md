# Detection engineering

**Status:** PLANNED · **Phase 3**

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
*(to be filled in — this section is the point of the repository)*

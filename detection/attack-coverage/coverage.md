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
| 100100 | Kerberoasting — RC4 service ticket for a user SPN | T1558.003 | Credential Access | 4769 | 95 docs in retention | **FIRED 2026-09-18 14:04:45** — `svc_test`, enc `0x17`, level 12 |
| 100101 | AS-REP roasting — TGT without pre-auth | T1558.004 | Credential Access | 4768 | **collected + archived — proven 2026-09-18 15:53** | UNTESTED — rule correct, trigger never produced `preAuthType 0` |
| 100102 | Encoded PowerShell | T1059.001 | Execution | 4688 commandLine | 2691 docs, stock owner 67027 | **FIRED 2026-09-18 15:42:11** — `-enc`, level 10 |
| 100103 | Service installed with interpreter image path | T1543.003 | Persistence / PrivEsc | 7045 | 3 docs incl. real `KsID` boot driver | **FIRED 2026-09-18 14:05:09** — `phase5test`, level 12 |
| 100104 | Internal port scan — firewall drop burst | T1046 | Discovery | filterlog → 87701 | **not proven** — no drop observed | drafted, inert (not deployed) |

**100101 is the one rule here that is neither proven nor disproven.** The
telemetry question is fully closed: a real 4768 from `svc_test` was pulled from
`archives.json` at 15:53 with every field intact, decoder `windows_eventchannel`,
`AUDIT_SUCCESS`. The event is collected, decoded and archived. What was never
produced is the *condition*: every 4768 measured so far carries
`preAuthType 2` (encrypted timestamp = normal pre-auth). The rule requires `0`.

To finish it, three steps must run **in this order, with the middle one
actually executed** — the attempt on 09-18 toggled the flag on and straight
back off without generating a ticket in between:

  1. DC01:  Set-ADAccountControl -Identity svc_test -DoesNotRequirePreAuth $true
  2. host:  KRB5_CONFIG=/tmp/krb5-homelab.conf kinit svc_test@HOMELAB.LAN
  3. DC01:  Set-ADAccountControl -Identity svc_test -DoesNotRequirePreAuth $false

Step 3 is not optional: leaving pre-auth off is a standing weakness in the AD,
not a test artifact. Until step 2 runs, this rule stays UNTESTED. Do not tune
it — there is nothing yet to tune it against.

**Ambient baseline measured the same day:** normal Kerberos traffic on this
domain carries `ticketEncryptionType 0x12` (AES256), with `0x17` appearing only
on `preAuthEncryptionType`. That is independent support for 100100's `^0x17$`
anchor on the ticket field being genuinely anomalous rather than ambient.

**2026-09-18: three rules moved from hypothesis to measurement.** 100102 was
fixed and proven later the same day; its first deploy chained to 92027, which
was asserted to own 4688 on the strength of a `rule.id` aggregation over a
commandLine query where the eventID of the matching docs was never checked.
92027 owns Sysmon EID 1. The rule required `^4688$` under a parent carrying
only EID 1 and could not match by construction. Re-anchored to 67027, the
measured owner of 4688, it fired on the first trigger. Twelfth instance of the
check-that-cannot-fail class, and the first authored in this repo rather than
inherited: the rule was never run against the two `-enc` docs already sitting
in retention, which would have exposed the contradiction before deployment.

A single `-enc` run produces two independent documents — 4688 on Security
(100102, level 10) and Sysmon EID 1 (stock 92027, level 4). A second rule
against the Sysmon path would survive 4688 command-line auditing being
disabled; worth having if 100104 stays blocked on issue 13.

100100 and 100103 fired at level 12 against triggers run on DC01, read back from the
indexer. They are detections now, not guesses.

**Why they had not fired before, and what it cost.** All four rules were
written as atomic rules keyed on `<decoded_as>windows_eventchannel</decoded_as>`.
They were loaded and enabled — the manager API confirmed every field condition
parsed correctly — and a 4769 satisfying all three of 100100's conditions was
sitting in the indexer. Stock rule 60106 alerted on it at level 3 instead.
`local_rules.xml` loads last and analysisd stops at the first matching atomic
rule, so the custom rules were never reached. Chaining each to its stock parent
(60106 for 4769, 91816 for 4104, 61138 for 7045 — each measured from real
documents, not guessed) fixed it on the first attempt.

The lesson matches the rest of this repo's history: the rules were correct the
whole time, and a check that reported "no detections" was reporting on a rule
that was never evaluated. A passing-looking absence again meant nothing.

**Retracted 2026-09-18, same day.** The paragraph that stood here claimed 100101
and 100102 were blocked on telemetry DC01 was not producing. Both halves were
wrong, and wrong by the same mechanism that has now bitten this repo eleven
times.

The manager runs `logall no` and `logall_json no` with `log_alert_level 3`.
`wazuh-alerts-*` therefore holds **alerts, not events**. An event that arrives,
decodes cleanly, and matches no rule at level ≥ 3 is discarded and leaves no
record anywhere. For a benign event, a count of zero is precisely what a
healthy pipeline looks like. Every "0 docs all-time" reading taken in this
session was taken against that channel.

- **4768 is audited and collected.** Measured by sending a real AS-REQ from the
  host (`kinit nosuchuser@HOMELAB.LAN`, KDC 192.168.50.10:88). DC01 logged it,
  the agent shipped it, and stock rule **60104** alerted at level 5 with
  `status 0x6` 14 seconds later. The earlier zero meant only that every prior
  4768 was a *success*, which no stock rule alerts on. `auditpol` confirms
  Kerberos Authentication Service is Success and Failure. 100101 is still
  unfired, but for the reachability reason, not a telemetry reason — and its
  parent cannot be guessed, because a success 4768 may well have a different
  owner than the failure 60104 just measured.
- **100102 has a content bug that no chaining can fix.** It matches
  `-enc\s|-encodedcommand|frombase64string` against
  `win.eventdata.scriptBlockText`. 4104 records the *deobfuscated* script block:
  running `powershell.exe -enc <b64>` of `Get-Date` logs the text `Get-Date`.
  The marker is on the command line, which 4104 does not carry. The rule
  searches the decoded output for the encoding artefact that decoding removes,
  so it can only fire on nested encoding. `ScriptBlockLogging` is `1`; that was
  never the problem. The command line is in **4688**, which has 2234 docs.

## The two gaps, stated plainly

**CLOSED 2026-09-18.** 100103 fired on a `phase5test` service created on DC01,
read back from the indexer at level 12. The System channel is collected and the
rule works end to end. The reasoning below is kept as the record of how the
question was actually settled, not as an open item.

**100103 has an unproven source — now narrowed to one half of the problem.**
7045 is on the Windows *System* channel. `02-telemetry.sh` proves Security and
Sysmon/Operational are collected; it says nothing about System. If that channel
is not collected, this rule cannot fire and the failure is silent —
indistinguishable from "no service was installed". `05-detections.sh` checks for
the channel before the rule, for that reason.

Measured 2026-09-14, manager-side, with the lab parked:

    sudo grep -o '<location>[^<]*</location>' /var/ossec/etc/shared/default/agent.conf
    Security / Microsoft-Windows-Sysmon/Operational /
    Microsoft-Windows-PowerShell/Operational / System      (4 localfile blocks)

So **the declaration is correct and always has been.** The guard in
`phase3-manager.sh` skips the write if Sysmon is already present, which raised
the possibility that an earlier three-channel version had been deployed and
every later run silently left it alone. It did not happen: the one backup,
`agent.conf.20260906-171929.bak`, is **76 bytes** and dated Aug 4 — the stock
stub. The Sep 6 run was the first real write, and it wrote all four channels in
one heredoc. `merged.mg` carries the same 17:19 timestamp, so the file agents
pull was regenerated from it.

**What this does not prove.** Declared manager-side is not collected agent-side.
It does not show that DC01 pulled `merged.mg`, merged it, and is reading the
System channel — only a real 7045 landing in the indexer shows that, and the
indexer is down. Treat 100103's source as *configured, collection unverified*,
not as solved. This is the same distinction issue 7 is about: the config is not
the evidence.

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

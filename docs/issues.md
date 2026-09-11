# Issues log

Every problem in this build that cost real time, what actually caused it, and how it
was fixed. Written down because the failures are the part worth reading — a lab that
works tells you nothing about how it got there.

Entries are ordered by how much they taught, not by date.

---

## 1 — Filebeat died 80 ms after start, five times, then systemd gave up

**Symptom.** Filebeat aborted immediately on every start:

```
runtime/cgo: pthread_create failed: Operation not permitted
SIGABRT: abort
```

systemd retried five times and stopped with `start-limit-hit`. The binary ran fine
by hand. The unit set no limits, no capabilities, no seccomp of its own.

**Cause.** Not systemd. libbeat installs **its own seccomp BPF filter** at startup,
and the 7.10.2 whitelist predates `clone3` — the syscall glibc 2.34+ uses for
`pthread_create`. The first cgo thread on the Elasticsearch output path (DNS
resolution) tried to spawn, hit the filter, and got EPERM.

An old syscall whitelist on a modern libc. The program forbids itself.

**Fix.** `seccomp.enabled: false` in `/etc/filebeat/filebeat.yml`.

**Verified properly.** Reproduced the abort with the filter on, then a clean run with
it off. A fix you cannot switch back on to reproduce the failure is a guess.

---

## 2 — The dashboard crashlooped 54 times on its own packaged config

**Symptom.** The Wazuh dashboard restarted every few seconds, indefinitely.

**Cause.** Two faults stacked. The shipped config points at
`/etc/wazuh-dashboard/certs/dashboard-key.pem`, and the package leaves that file
**empty**, so Node died with ENOENT. The unit is `Restart=always` with no
`RestartSec` and no start limit, so instead of failing once and stopping, it
respawned forever at roughly 6 s of CPU per attempt.

A missing file that presents as a config error, and a restart policy that hides it.

**Fix.** Deploy the certificates, then **assert they exist and are readable by the
`wazuh-dashboard` user before writing a config that references them**. Separately, a
drop-in caps restarts at 3 in 120 s:

```ini
# /etc/systemd/system/wazuh-dashboard.service.d/restart-limit.conf
[Unit]
StartLimitIntervalSec=120
StartLimitBurst=3
```

**Lesson.** `Restart=always` with no limit converts a hard failure into background
noise. Make services fail loudly.

---

## 3 — The manager API bound to a port the kernel could steal

**Symptom.** Intermittent `EADDRINUSE` on 55000 at boot. Non-deterministic. Presented
as "Wazuh randomly broken".

**Cause.** Wazuh's API port **55000 sits inside the ephemeral range**
(`net.ipv4.ip_local_port_range` = 32768–60999). If any outbound connection was
assigned 55000 before the manager bound it, the manager lost the race.

**Fix.**

```
# /etc/sysctl.d/30-wazuh-reserved-ports.conf
net.ipv4.ip_local_reserved_ports = 55000
```

The dashboard's own 5601 is below the range and unaffected. The build now refuses any
listener port inside the ephemeral range.

**Lesson.** A service listening inside the ephemeral range is a race, not a
configuration. It will work almost every time, which is worse than never working.

---

## 4 — The indexer would not start: one orphaned YAML list item

**Symptom.** Three failed starts. `opensearch.yml` was invalid YAML.

**Cause.** A config edit replaced the `cluster.initial_master_nodes:` key with an
inline list but left the original block-list item `- "node-1"` stranded on the next
line — valid text, invalid YAML.

**Fix.** The edit now consumes block-list items belonging to the key it replaces, and
the file is parsed before any start:

```bash
python3 -c 'import yaml; yaml.safe_load(open("/etc/wazuh-indexer/opensearch.yml"))'
```

**Lesson.** Editing YAML with regexes is fine — shipping it without parsing it is not.

---

## 5 — Two verification checks passed for the wrong reasons

**Symptom.** The telemetry verification reported 4688 and 4104 as missing while the
indexer plainly held 229 and 10 of them.

**Cause.** Both checks searched alerts for `"id":"<event number>"`. In Wazuh's JSON
alerts, `id` is the **rule** id — the Windows event number lives at
`data.win.system.eventID`. The checks could never have matched.

A worse one hid next to it: the pfSense check searched for the bare string
`192.168.50.1`, which also matches DC01's `192.168.50.10`. It would have reported
"pfSense syslog seen" while pfSense sent nothing at all.

**Fix.** Event checks query the indexer by `data.win.system.eventID`; the pfSense
check is anchored on the full `"location":"192.168.50.1"` field.

**Lesson.** The false negative wasted an hour. The false positive was the dangerous
one — it would have marked a phase complete on another host's events. A check that
can pass for the wrong reason is not a check.

---

## 6 — `virsh shutdown` returns success and does nothing

**Symptom.** DC01 kept running after `virsh shutdown`, which reported success. The
memory it was meant to free never came back, leaving the indexer ~1 GB short.

**Cause.** `virsh shutdown` sends an **ACPI power-button event**. The Windows guest
ignored it. libvirt reports that the event was delivered, not that anything happened.

**Fix.** Shut the guest down from inside (`Stop-Computer -Force`) and wait on the
domain state rather than trusting the return code:

```bash
until virsh -c qemu:///system domstate ad-dc | grep -q 'shut off'; do sleep 5; done
```

pfSense honours ACPI and shuts down normally, which made the asymmetry confusing at
first.

---

## 7 — pfSense never sends firewall logs (was: "nothing parses them")

**Status: transport fixed 2026-09-11, decoding and indexing unverified.** The
remediation was a pfSense setting, not a manager decoder — confirmed by fixing it.

**Fix applied 2026-09-11.** Status → System Logs → Settings → Remote Logging →
**Firewall events** ticked. The earlier saves had returned HTTP 403 on CSRF failure
and never committed; this one did. `filterlog` now arrives on the wire:

```
<134>Sep 11 23:10:18 filterlog[56519]: 79,,,100000101,vtnet1,match,pass,in,4,0x0,,128,
35993,0,none,17,udp,86,192.168.50.10,8.8.8.8,58404,53,66
```

Captured with `tcpdump -lni virbr-lab -A udp port 514`. Transport is **proven**.

**Still unproven, and not to be claimed until measured:**

- **Decoding — still unknown. Two measurements attempted 2026-09-12, both void.**

  **Retracted:** an entry here claimed decoding was broken because `wazuh-logtest`
  returned decoder `FreePBX`, rule 70000. A second run with a hostname inserted
  returned `No decoder matched`. Neither result is evidence, because both inputs
  were pasted straight from `tcpdump` and still carried the `<134>` PRI prefix.
  `remoted` strips the PRI before decoding, so no such line ever reaches the
  decoders. Phase 1 printed `full event` and no `timestamp`, `hostname` or
  `program_name` in **both** runs — pre-decoding failed on the malformed header
  each time, and whatever matched afterwards matched an unparsed blob.

  **Tenth instance of the 14/15/16 class, and the sharpest one.** The previous
  nine were checks that reported absence without looking. This one ran, produced
  detailed output, named a decoder, and was written into this file as a finding —
  all from an input the system under test never receives. Verbose output is not
  validity. **Before believing a logtest verdict, confirm the input matches what
  the manager actually stores.**

  **Measured correctly 2026-09-12, PRI stripped, hostname present.** Decoding is
  not broken. Pre-decoding yields `timestamp`, `hostname: pfSense`,
  `program_name: filterlog`; decoder **`pf`** matches and extracts the full field
  set — `action: pass`, `srcip`, `dstip`, `srcport`, `dstport`, `protocol`, rule
  `id`, `length`. Rule **87700** fires at **level 0**, group `pfsense`. Child rule
  **87701 — pfSense firewall drop event** is tried and correctly does not match,
  because the event is a pass.

  **Level 0 writes no alert.** For pass traffic, absence from `wazuh-alerts-*` is
  the designed outcome, not a fault. Every count of zero taken against pass events
  in this issue's history was consistent with a perfectly working pipeline. The
  decoder that three days were spent hunting was never missing and never wrong.

  **The one thing still open: the wire has no hostname.** Captured events read
  `<134>Sep 11 23:10:18 filterlog[56519]:` — timestamp straight to tag. The test
  above only decodes because a hostname was typed in by hand. Pre-decoding needs
  `TIMESTAMP HOSTNAME TAG:` to populate `program_name`, and the `pf` decoder keys
  on `program_name`. Re-run the same line **without** `pfSense` to settle it:
  `Sep 11 23:10:18 filterlog[56519]: 79,,,100000101,...`
  If that fails to decode, the remaining defect is a pfSense hostname setting, and
  the manager side needs no change at all.
- **Indexing.** The captured events are all `match,pass`. Wazuh scores routine
  passes at level 0 and writes no alert, so a zero count in `wazuh-alerts-*` is
  correct behaviour here, not a failure. Generate a genuine **block** to test the
  indexed path, or read `archives.log` with `logall_json` enabled.

**Volume warning.** These lines come from the LAN allow rule with logging enabled,
so every permitted packet now generates an event. On a lab already 370 MiB over the
Suricata budget with a hand-started indexer, leave only block logging on once the
pipeline is proven.

**Check fixed.** `scripts/verify/02-telemetry.sh` reported "pfSense syslog: PASS" on
`syslogd: restart` heartbeats while firewall visibility was zero. Renamed to
`pfSense reachable by syslog (heartbeat only)` and a separate wire-level
`filterlog` check added beside it.

**Two more instances of the 14/15/16 class, both found while fixing this.** Neither
was a lab fault; both were checks that reported absence without looking.

1. `sudo ss -lunp` with stderr to `/dev/null`: sudo failed for want of a terminal,
   the `||` branch printed "no UDP 514 listener", and 514/udp was listening the
   whole time. A conclusion printed by a command that never ran.
2. `tcpdump -A | grep filterlog`: grep block-buffers when stdout is not a terminal,
   so matching packets produced a blank screen. Then `grep -c` on an unbounded
   `tcpdump` — a count that prints only at EOF, from a stream that has no EOF.
   Both read as clean negatives.

**Lesson, sharpened.** The original entry theorised about a decoder for three days
over content that was never sent, while the firewall sat in the indexer logging the
403 evidence of its own misconfiguration. Before believing a zero: prove the command
ran, prove it could have printed, and prove it terminates.

**What the record used to say.** That the manager received exactly one event (rule
1005, "Syslogd restarted") and that it matched **no decoder** (`decoder: null`), so
pfSense content was arriving unparsed.

**What is actually true.** Measured against the indexer on 2026-09-11, over every
`wazuh-alerts-*` index in retention:

| From `location: 192.168.50.1` | Count | Decoder |
|---|---|---|
| `syslogd` — "restart" | 6 | none (rule 1005) |
| `nginx` — GUI access log | 5 | `web-accesslog` (rule 31101) |
| `filterlog` — **the firewall log** | **0** | — never received |

Three corrections follow.

1. **It was never one event.** Twelve arrived across five days.
2. **Decoding is not broken.** Five of them decode cleanly through `web-accesslog`
   into rule 31101. The pipeline parses pfSense content correctly whenever pfSense
   sends content that has a decoder.
3. **`decoder: null` on rule 1005 is normal Wazuh behaviour, not a fault.** The
   pre-decoder extracts `program_name: syslogd` from the syslog header and rule 1005
   matches on that alone. A bare `syslogd: restart` line has no fields to decode.
   Reading `decoder: null` as "parsing is broken" was the mistake.

**The real gap.** `filterlog` — the pfSense firewall log, the only category that
carries block/pass decisions, ports, and directions — has **never reached the
manager**. Not unparsed: absent. Nothing on the Wazuh side can fix that, because
nothing is being sent.

**Probable reason it was never enabled.** The same query surfaced five `nginx`
events: `POST /status_logs_settings.php` returning **HTTP 403**, from `192.168.50.2`
(the host browser), on 09-08 and 09-10. That is the Status → System Logs → Settings
page rejecting the save — pfSense returns 403 on a CSRF-token failure. The remote
logging settings were very likely never committed. The firewall logged the evidence
of its own misconfiguration, and it sat in the indexer for three days.

**Why it matters.** Unchanged, and now sharper: there is no firewall visibility. A
"pfSense syslog: PASS" check passes on `syslogd: restart` heartbeats and proves
nothing about firewall logging.

**Next.** In the pfSense GUI, tick **Firewall events** under Status → System Logs →
Settings → Remote Logging, confirm the save actually returns 200, then re-run the
filterlog count below and expect it to be non-zero.

**Seventh instance of the issues 14/15/16 class.** A reading — `decoder: null` — was
real, and the cause attached to it was invented. The check proved something other
than what it claimed. Confirm *absence* before theorising about *processing*.

---

## 8 — The manager API is exposed with a shipped default credential

**Status: open, accepted for an isolated lab.**

The manager API listens on `0.0.0.0:55000` and `[::]:55000` with the packaged
credential `wazuh-wui:wazuh-wui`. Anything that can route to the host can
authenticate to it.

This is exposure, not a bug, and it is distinct from the port race in issue 3. It is
tolerable only because the segment is isolated and has no route in. **It must be
changed — password rotated and the API bound to loopback — before this lab touches an
untrusted network.** Recorded rather than quietly fixed, because knowing an accepted
risk is open is the point.

---

## 9 — A snapshot whose name did not match its contents

**Symptom.** A rollback point named `healthy-3gb` was taken *before* the guest had
actually rebooted at 3 GB, so it captured the 4 GB state under a 3 GB name.

**Fix.** Re-taken after the real reboot.

**Lesson.** A rollback point you are wrong about is worse than none — you would
restore it under pressure and trust the result. Snapshot names are claims; verify them
like any other claim.

---

## Smaller things, recorded so they are not rediscovered

| Thing | Reality |
|---|---|
| The indexer reports version `7.10.2`, not the real OpenSearch `2.19.4` | Deliberate. `compatibility.override_main_response_version: true` is required because Filebeat 7.10.2 is an Elasticsearch client and refuses any server not identifying as ES 7.x. Looks like a version mismatch; is not. |
| Removing Splunk reclaimed 6.2 GB of **disk** and almost no RAM | It was not running. Disk pressure and memory pressure are different problems; freeing one does not help the other. |
| `virsh console ad-dc` shows a blank screen | Windows does not write to a serial port unless EMS/SAC is enabled. Use `virt-viewer` (VNC). Cost time looking for a broken console that was fine. |
| Filebeat is enabled at boot, the indexer is not | On a cold boot filebeat retries into nothing until the indexer starts. Not data loss — filebeat keeps its registry position and drains — but the journal fills with errors and the lab looks broken when it is not. A deliberate RAM-budget choice, not an oversight. |
| Audit policy on a domain controller | Default Domain Controllers Policy overrides anything `auditpol` sets locally at the next GPO refresh. If a subcategory silently stops producing events, that is the cause. Set it in the GPO to make it stick. |
| A verify script that greps a log file for a success string | The string may have been written by a previous run. `engine started` was still in `suricata.log` from the last restart, so the readiness wait returned instantly and the probe tested a half-started engine. Record the file's byte offset before the action and read only past it — or check the outcome directly instead of a log narrating it. |
| A check that has never been observed to fail | Issues 14, 15 and the `PROMISC` check all passed or failed for reasons unrelated to the thing under test. A check is not evidence until you have made it fail on purpose. |
| ET Open against an internal port scan | An nmap `--top-ports 100` against the DC produced **no Suricata alert at all** — not one signature. ET Open is aimed at malware C2 and exploits crossing a perimeter, not at recon inside a flat lab net. Custom rules do the work here. *(Corrected 2026-09-11 — see the row below for what this claim originally said.)* |
| A count that matches the story you expect | The row above used to read "produced exactly one signature, `SURICATA STREAM excessive retransmissions`", and STATUS.md said the scan produced 5 of them. Queried by date and address, the non-probe alert count on the day of the scan is **0**; those 5 retransmission alerts are dated a day later and are DC01 talking to a Microsoft CDN on port 80. The number 5 was real, the attribution was invented. Fifth instance of issues 14/15/16 and the `PROMISC` check: filter on the identifiers — date, src, dest — before attributing a count to a cause. |
| Trimming a Suricata ruleset to save RAM | Cutting 15% of the rules cut memory ~11% (976 -> 870 MiB). Roughly linear with rule count; there is no cheap win. *(Corrected 2026-09-11 — this row previously claimed a 76% steady-state cut and concluded "steady state is the pattern matcher, the peak is rule parsing." Both were inferred from one mis-timed sample. See the row below.)* |
| `MemoryCurrent` sampled before a service has settled | A cold-start trajectory: 17 MiB at 15 s, 870 MiB at 30 s, flat to 135 s and at 23 min. The 230 MiB "steady state" in STATUS was taken inside the load window, filed as a real data point, and generated a false lesson that survived three months. The tell was already in the table: every honest row had steady/peak ≈ 0.96; the bad row diverged by 4x. When one row in a table disagrees with the shape of the others, re-measure it before theorising about it. Sample only after two consecutive reads agree. |
| A config grep that reports a setting disabled | YAML list entries may be bare (`- smb`) or mappings (`- smb:`). A pattern written for one form reports the other as absent, and a negative grep looks identical whether the setting is off or the pattern is wrong. Run the pattern against a value you know is present before believing a zero. |

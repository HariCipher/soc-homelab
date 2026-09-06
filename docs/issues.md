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

## 7 — pfSense syslog arrives but nothing parses it

**Status: open.** Carried into the network-IDS phase.

**Symptom.** Remote syslog was enabled on pfSense and the manager received exactly one
event — rule 1005, "Syslogd restarted", logged at the moment the setting was saved.
Transport confirmed. But that event matched **no decoder** (`decoder: null`).

**Why it matters.** The pipe works; the content is not being turned into fields. It
would be easy to see "pfSense syslog: PASS" and assume firewall visibility exists. It
does not yet.

**Next.** Confirm which log categories pfSense is actually sending, then check the
`pf`/`filterlog` decoders on the manager.

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

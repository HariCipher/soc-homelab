# Decision log

Each entry: what was decided, why, and what was rejected.

---

## 001 — Wazuh is the SIEM (superseded in part by 006)

**Decision.** Wazuh is the detection engine and the system to build skill in.

**Why.** Wazuh is the skill gap worth closing; it is open source, agent-based, and
maps natively to MITRE ATT&CK.

**Rejected.** ELK — a third stack to run and learn at the same time. Revisit after
a hardware upgrade.

---

## 002 — Suricata runs on the host, not on pfSense

**Decision.** Deploy Suricata on the Arch host, sniffing `virbr-lab` in promiscuous
mode, rather than as a pfSense package.

**Why.** pfSense + Suricata needs roughly 3 GB; the host has 12 cores and can run
the same sensor for ~0.5 GB with no VM growth. It also sees the whole lab L2
segment, not just traffic transiting the firewall.

**Rejected.** Suricata as a pfSense package — costs ~2 GB the lab does not have.

---

## 003 — No Kali VM; attack tooling runs from the host

**Decision.** Run adversary-emulation tooling from the Arch host, which already has
an interface on labnet.

**Why.** A Kali VM costs ~3 GB for tools that are all installable natively. The host
is already inside the segment at 192.168.50.2.

**Rejected.** Dedicated attacker VM — revisit at 32 GB.

---

## 004 — Deception deferred

**Status.** Out of scope until Phase 5 is verified.

**Context.** Deception was considered for the original design. It is recorded here
so the reasoning is not lost, but nothing is built and no folder exists for it yet.

**Reasoning kept.** AD honeytokens (a decoy SPN'd account, an audited decoy share)
cost no memory and detect the behaviour an attacker on a domain actually performs.
That is a better first step than a honeypot VM. Revisit after the build.


## 005 — No Wazuh indexer on this host

**Decision.** Do not deploy the Wazuh indexer (OpenSearch) on the current host.

**Why.** OpenSearch plus the Wazuh dashboard needs several GB; the host has ~6.9 GB
free for the entire lab. A web interface is still needed — options and the chosen
approach are recorded in `siem/README.md`.

**Revisit.** After a 32 GB upgrade.

---

## 006 — Splunk removed entirely; Wazuh is the only SIEM

**Decision.** Remove Splunk from the design and from the host. Wazuh manager +
indexer + dashboard is the complete stack.

**Why.** Two SIEMs on a 15 GB host means neither runs well. Splunk Free is capped at
500 MB/day with no auth, no alerting and no scheduled searches, so it was never
going to be the engine — it was only a UI. Wazuh has its own dashboard, so keeping
Splunk purely for visuals costs memory and disk for nothing. Building on one stack
properly beats half-configuring two.

**Consequence.** The Wazuh indexer (OpenSearch) becomes mandatory, and it is the
single largest memory consumer in the lab. This is paid for by removing Splunk,
reducing DC01 from 4 GB to 3 GB, and capping the indexer JVM heap at 1 GB.

**Trade-off accepted.** Short log retention on current hardware.

**Supersedes.** Decision 005 (no indexer on this host) and the "Splunk as Wazuh's
UI" option previously recorded in `siem/README.md`.

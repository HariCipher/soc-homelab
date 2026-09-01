# Decision log

Each entry: what was decided, why, and what was rejected.

---

## 001 — Wazuh is the primary SIEM, Splunk secondary

**Decision.** Wazuh is the detection engine and the system to build skill in.
Splunk stays as the familiar search/dashboard layer.

**Why.** Wazuh is the skill gap worth closing; it is open source, agent-based, and
maps natively to MITRE ATT&CK. Splunk Free is capped at 500 MB/day with no auth,
no alerting and no scheduled searches — usable as a search UI, not as the engine.

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

## 004 — Honeytokens before honeypots

**Decision.** Start deception with AD honeytokens (a decoy account and a decoy audited
share) rather than a honeypot VM.

**Why.** Zero RAM, near-zero false positives, and it exercises the audit-policy and
detection pipeline rather than adding another machine to maintain. A containerised
honeypot can follow.

**Rejected.** OpenCanary / T-Pot VM as the starting point.

---

## 005 — No Wazuh indexer on this host

**Decision.** Do not deploy the Wazuh indexer (OpenSearch) on the current host.

**Why.** OpenSearch plus the Wazuh dashboard needs several GB; the host has ~6.9 GB
free for the entire lab. A web interface is still needed — options and the chosen
approach are recorded in `siem/wazuh/README.md`.

**Revisit.** After a 32 GB upgrade.

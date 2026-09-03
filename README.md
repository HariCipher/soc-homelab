# soc-homelab

A self-built **Home SOC / security lab** for detection engineering, log analysis and
incident investigation — a segmented virtual network (pfSense firewall + Active
Directory domain) monitored end-to-end by **Wazuh**.

> **Status:** BUILDING building — Phase 1 nearly complete.
> Nothing here is claimed as working until it is verified by a script and
> screenshotted. Live state: **[STATUS.md](STATUS.md)**.

---

## Architecture

```mermaid
flowchart TB
    NET(["Internet"])

    subgraph HOST["Arch host - KVM/libvirt + SIEM"]
        WZM["Wazuh Manager<br>1514 / 1515 / 55000"]
        WZI["Wazuh Indexer<br>OpenSearch"]
        WZD["Wazuh Dashboard<br>web UI"]
        SUR["Suricata<br>sniffs virbr-lab"]
        N8N["n8n SOAR"]
    end

    subgraph LAB["labnet 192.168.50.0/24 - ISOLATED, no NAT"]
        PF["pfSense<br>WAN dhcp<br>LAN 192.168.50.1"]
        DC["DC01 Windows Server 2025 Core<br>192.168.50.10<br>AD DS + DNS homelab.lan"]
        HP["Honeytokens / honeypot"]
    end

    NET --> HOST
    HOST --> PF
    PF --- DC
    PF --- HP
    DC --> WZM
    PF --> WZM
    SUR --> WZM
    HP --> WZM
    WZM --> WZI
    WZI --> WZD
    WZM --> N8N
    N8N --> PF
```

<details>
<summary>Text version of the topology</summary>

```
Internet
 |
Arch host (KVM/libvirt)  --  Wazuh Manager + Indexer + Dashboard
 | Suricata (sniffs virbr-lab)
 | n8n SOAR
 | virbr0 192.168.122.0/24 (NAT) host is also 192.168.50.2 on labnet
 |
pfSense   WAN dhcp / LAN 192.168.50.1   <-- only route out of the lab
 |
   +-- DC01  192.168.50.10   Windows Server 2025 Core, AD DS + DNS (homelab.lan)
   +-- Honeytokens / honeypot (planned)

Telemetry:  DC01 (Wazuh agent 1514) ---+
            pfSense (syslog 514) ------+--> Wazuh Manager --> Indexer --> Dashboard
            Suricata (host) -----------+                              --> n8n
```
</details>

The lab segment has **no NAT of its own by design** — the only route out is through
the firewall. That is what makes it safe to run hostile workloads later.

---

## Build phases

Building first. Practice and adversary emulation come after the platform is complete.

| # | Phase | Delivers | Status |
|---|---|---|---|
| 0 | **Previous work** | earlier labs — honeypot, n8n, first AD build | ARCHIVED |
| 1 | **Foundation** | host · libvirt · pfSense · AD-DC, verified | BUILDING |
| 2 | **SIEM platform** | Wazuh manager + indexer + dashboard | PLANNED |
| 3 | **Telemetry** | Wazuh agent · Sysmon · audit policy · pfSense syslog | PLANNED |
| 4 | **Network IDS** | Suricata on host, tuned | PLANNED |
| 5 | **Detection** | custom rules · MITRE ATT&CK coverage | PLANNED |
| 6 | **Deception** | AD honeytokens | PLANNED |
| 7 | **Automation** | n8n SOAR — enrich, notify, contain | PLANNED |
| — | *Practice (attack → hunt → harden)* | *after the build is complete* | DEFERRED |

Full detail and exit criteria: **[ROADMAP.md](ROADMAP.md)**
Step-by-step build instructions: **[docs/SETUP-GUIDE.md](docs/SETUP-GUIDE.md)**

---

## Repository map

| Folder | Security function |
|---|---|
| [`docs/`](docs/) | architecture · network design · setup guide · decision log |
| [`infrastructure/`](infrastructure/) | host, libvirt, VM lifecycle, snapshots |
| [`firewall/`](firewall/) | pfSense + Suricata |
| [`identity/`](identity/) | Active Directory, GPO, Sysmon, audit policy |
| [`siem/`](siem/) | Wazuh — manager, indexer, dashboard |
| [`detection/`](detection/) | rules, Sigma, MITRE coverage, validation |
| [`deception/`](deception/) | honeytokens and honeypots |
| [`automation/`](automation/) | n8n SOAR playbooks |
| [`operations/`](operations/) | runbooks, daily checks, investigations |
| [`evidence/`](evidence/) | screenshots proving each verified claim |
| [`archive/`](archive/) | NOTE: previous labs — **not the current environment** |
| [`scripts/`](scripts/) | lab start/stop + verification scripts |
| [`lab-journal/`](lab-journal/) | dated build log: what I did, what broke |

---

## Upstream projects used

| Project | Role |
|---|---|
| [pfSense CE](https://www.pfsense.org) | firewall, router, DNS, DHCP |
| [Wazuh](https://wazuh.com) | SIEM/XDR — manager, indexer, dashboard, agents, ATT&CK mapping |
| [Suricata](https://suricata.io) | network intrusion detection |
| [Sysmon](https://learn.microsoft.com/sysinternals) | Windows endpoint telemetry |
| [SwiftOnSecurity sysmon-config](https://github.com/SwiftOnSecurity/sysmon-config) | Sysmon baseline |
| Windows Server 2025 (eval) | Active Directory domain controller |
| [n8n](https://n8n.io) | SOAR / workflow automation |
| [MITRE ATT&CK](https://attack.mitre.org) | detection coverage framework |

*Versions are recorded in each folder's README as they are deployed.*

---

## My work in this lab

*(Filled in as each phase is verified — deliberately empty until there is something
real to describe.)*

- Network segmentation and firewall policy design
- Custom Wazuh detection rules
- Suricata rule tuning for this environment
- n8n SOAR playbooks
- Incident investigation writeups → [`operations/investigations/`](operations/investigations/)

---

## Previous work

Earlier labs live in [`archive/`](archive/) — a honeypot lab, n8n automation work,
and the first pfSense + AD + Wazuh build. Kept for reference and component
migration. **None of them are running.** This repository documents one lab: the one
above.

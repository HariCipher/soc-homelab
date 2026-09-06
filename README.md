# soc-homelab

A self-built **Home SOC / security lab** for detection engineering, log analysis and
incident investigation — a segmented virtual network (pfSense firewall + Active
Directory domain) monitored end-to-end by **Wazuh**.

> **Status:** BUILDING — Phases 1-3 verified, Phase 4 (network IDS) next.
> Nothing here is claimed as working until its exit test passes and the output is
> screenshotted. What broke on the way there is written up in
> **[docs/issues.md](docs/issues.md)**.

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
        N8N["n8n<br>SOAR playbooks"]
    end

    subgraph LAB["labnet 192.168.50.0/24 - ISOLATED, no NAT"]
        PF["pfSense<br>WAN dhcp<br>LAN 192.168.50.1"]
        DC["DC01 Windows Server 2025 Core<br>192.168.50.10<br>AD DS + DNS homelab.lan"]
    end

    NET --> HOST
    HOST --> PF
    PF --- DC
    DC --> WZM
    PF --> WZM
    SUR --> WZM
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

 | virbr0 192.168.122.0/24 (NAT) host is also 192.168.50.2 on labnet
 |
pfSense   WAN dhcp / LAN 192.168.50.1   <-- only route out of the lab
 |
   +-- DC01  192.168.50.10   Windows Server 2025 Core, AD DS + DNS (homelab.lan)

Telemetry:  DC01 (Wazuh agent 1514) ---+
            pfSense (syslog 514) ------+--> Wazuh Manager --> Indexer --> Dashboard
            Suricata (host) -----------+
                                            |
                                            +--> n8n SOAR --> back to pfSense / AD
```
</details>

The lab segment has **no NAT of its own by design** — the only route out is through
the firewall. That is what makes it safe to run hostile workloads later.

---

## Build phases

Building first. Practice and adversary emulation come after the platform is complete.

| # | Phase | Delivers | Status |
|---|---|---|---|
| 0 | **Previous work** | earlier pfSense + AD + Wazuh build | ARCHIVED |
| 1 | **Foundation** | host · libvirt · pfSense · AD-DC, verified | DONE |
| 2 | **SIEM platform** | Wazuh manager + indexer + dashboard | DONE |
| 3 | **Telemetry** | Wazuh agent · Sysmon · audit policy · pfSense syslog | DONE |
| 4 | **Network IDS** | Suricata on host, tuned | NEXT |
| 5 | **Detection** | custom rules · MITRE ATT&CK coverage | PLANNED |
| 6 | **SOAR** | n8n playbooks — enrich · notify · contain | PLANNED |

Full detail and exit criteria: **[ROADMAP.md](ROADMAP.md)**
Step-by-step build instructions: **[docs/SETUP-GUIDE.md](docs/SETUP-GUIDE.md)**
What broke, and why: **[docs/issues.md](docs/issues.md)**
Why it is built this way: **[docs/decisions.md](docs/decisions.md)**

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
| [`automation/`](automation/) | n8n SOAR playbooks — enrich, notify, contain |
| [`evidence/`](evidence/) | screenshots proving each verified claim |
| [`archive/`](archive/) | NOTE: previous labs — **not the current environment** |

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
| [n8n](https://n8n.io) | SOAR / response automation |
| [MITRE ATT&CK](https://attack.mitre.org) | detection coverage framework |

*Versions are recorded in each folder's README as they are deployed.*

---

## How this lab is built

Four practices, and each one has already caught something. The cases are in
[docs/issues.md](docs/issues.md).

**One change → one verification → one screenshot.** Not one verification per phase.
A batch of changes that fails tells you the batch is wrong, not which change is.

**Snapshot before every experiment.** `virsh snapshot-create-as` before anything
touches a VM's config, and the snapshot is named for what it precedes
(`pre-phase3`), not for how it felt at the time — a snapshot called `healthy` is
worthless six weeks later when you cannot remember what it was healthy *before*.

**Verify from the far end of the pipeline.** An agent reporting Active proves it
connected, not that events are stored. So the Phase 3 exit test queries the
*indexer* for event 4625 after deliberately failing a logon. Two checks in this lab
passed while the thing they claimed to test was broken; both were checks that
believed a component's own report.

**Read the config before restarting the service.** `wazuh-remoted -t`, `nginx -t`,
`visudo -c`. The manager is the thing you would use to debug the manager, so
validating first is not caution, it is not locking yourself out.

The engineering content is in the design, the failures and the detections — the
shell scripts that drive the lab day to day are kept out of this repository on
purpose.

---

## What this demonstrates

- Network segmentation and firewall policy design
- End-to-end telemetry: Windows audit policy, Sysmon, PowerShell script-block
  logging, firewall syslog
- Custom Wazuh detection rules mapped to MITRE ATT&CK
- Suricata rule tuning for this environment
- SOAR playbooks that enrich and contain, with a tested reverse for every action

---

## Previous work

The first pfSense + AD + Wazuh build lives in [`archive/`](archive/), kept for
reference and component migration. **It is not running.** This repository
documents one lab: the one above.

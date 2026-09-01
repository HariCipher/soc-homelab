> 📦 **ARCHIVED — previous work, not the current environment.**
> Kept for reference and component migration. Any status claims below
> reflect 2026-08-08 and are **not** current. Live status: [STATUS.md](../../STATUS.md)

---

# Homelab Build Assistant

## What this is
Claude helping build/operate a virtualized homelab on an Arch host: pfSense firewall +
Windows Server 2025 AD-DC, with Wazuh + Splunk on the host for monitoring.

## >>> SESSION PAUSED 2026-08-08 — read RESUME-HERE.md first <<<
Both VMs are currently **shut off** (autostart disabled). pfSense General Setup was
filled in and saved. Log forwarding is half-wired: Wazuh syslog 514 up, Splunk confs
written, Splunk UDP 5514 not yet binding. Next 3 steps are in RESUME-HERE.md.

## Current state (2026-08-08) — CORE LAB IS UP
- Arch host `larper`: Wazuh manager running, Splunk running
- libvirt networks: `default` (192.168.122.0/24, NAT->internet), `labnet` (192.168.50.0/24, isolated)
- pfSense VM: installed, WAN=vtnet0 (default net, DHCP), LAN=vtnet1 192.168.50.1/24
  - Web GUI: https://192.168.50.1/ (admin / Homelab2026!) — reachable from host
- AD-DC VM: Windows Server 2025 Core (no Desktop Experience), 192.168.50.10/24
  - Domain: homelab.lan / NetBIOS HOMELAB, DC01, admin pw Homelab2026!
  - AD DS + DNS installed and promoted; SRV records registered
  - DNS forwarder -> 192.168.50.1 (pfSense) -> internet. Verified resolving both
    internal (dc01.homelab.lan) and external (archlinux.org, google.com).

## Working style
- Diagnose root cause first (DNS, network, VM state)
- Show me actual command output, not guesses
- Fix one issue at a time before moving next
- Update this file as we progress

## Non-negotiable
Run commands, show output. Don't assume—verify.

## Next up
See HOMELAB.md for topology, verification runbook, and roadmap (honeypot migration,
Wazuh agent on DC01, Splunk ingest, backups).

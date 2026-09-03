# Identity — Active Directory & Windows security

**Status:** DEGRADED — see [STATUS.md](../STATUS.md) · **Phases 1 & 2**

## Purpose
DC01 is both the identity provider for the lab and the richest telemetry source in
it. Most detection work in this lab targets Windows and AD.

## Design
- Windows Server 2025 **Core** (no GUI — administered entirely via PowerShell)
- 192.168.50.10 static · domain `homelab.lan` · NetBIOS `HOMELAB`
- AD DS + DNS; authoritative for `homelab.lan`, forwards everything else to pfSense
- Time synced to pfSense — Kerberos fails on >5 min skew

## Telemetry to enable (Phase 2)
| Source | Events |
|---|---|
| Advanced audit policy | 4624/4625 logon, **4688** process creation |
| PowerShell logging | **4104** script block logging |
| Sysmon | process, network, image load, registry |

## Verify
```powershell
Get-ADDomain | fl Name,DNSRoot,NetBIOSName,DomainMode
Get-Service NTDS,DNS,Netlogon,kdc | ft Name,Status
dcdiag /q          # empty output = healthy
```

## Upstream
Windows Server 2025 (eval) · Sysmon · SwiftOnSecurity sysmon-config

## My changes
*(to be filled in — audit policy, GPO, hardening baseline)*

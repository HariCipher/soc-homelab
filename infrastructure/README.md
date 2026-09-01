# Infrastructure

**Status:** ⚠️ DEGRADED — see [STATUS.md](../STATUS.md) · **Phase 1**

## Purpose
The hypervisor layer: the Arch host, the two libvirt networks, the VM definitions,
and the snapshot/backup discipline that makes experiments reversible.

## Design
See [`docs/network.md`](../docs/network.md). Two networks — `default` (NAT, pfSense
WAN) and `labnet` (isolated). Two VMs — `pfsense` and `ad-dc`.

## Current state
All claims live in [STATUS.md](../STATUS.md). Both VMs are currently **shut off**
with autostart disabled.

## Verify
```bash
scripts/verify/00-host.sh
```

## Open items
- Host has **no address on `virbr-lab`** and nothing sets it — blocks all log forwarding
- Splunk has **no systemd unit** — does not survive reboot
- **No snapshots exist** on either VM

## Upstream
libvirt / QEMU-KVM · Arch Linux

## My changes
*(to be filled in)*

# Infrastructure

**Status:** DEGRADED — see the phase table in the [root README](../README.md) · **Phase 1**

## Purpose
The hypervisor layer: the Arch host, the two libvirt networks, the VM definitions,
and the snapshot/backup discipline that makes experiments reversible.

## Design
See [`docs/network.md`](../docs/network.md). Two networks — `default` (NAT, pfSense
WAN) and `labnet` (isolated). Two VMs — `pfsense` and `ad-dc`.

## Current state
Component state is tracked locally during the build; the published claims are in the [root README](../README.md) phase table. Both VMs are currently **shut off**
with autostart disabled.

## Verify
```bash
# host layer: hypervisor, both libvirt networks, the labnet address, Wazuh services
virsh -c qemu:///system net-list --all
ip addr show virbr-lab | grep 192.168.50.2
```

## Open items
- Host has **no address on `virbr-lab`** and nothing sets it — blocks all log forwarding
- **No snapshots exist** on either VM

## Upstream
libvirt / QEMU-KVM · Arch Linux

## My changes
*(to be filled in)*

> ARCHIVED **ARCHIVED — previous work, not the current environment.**
> Kept for reference and component migration. Any status claims below
> reflect 2026-08-08 and are **not** current. Live status: [STATUS.md](../../STATUS.md)

---

# Lab State — 2026-08-08

## Host
- Arch Linux, KVM/QEMU via libvirt
- Wazuh manager: running yes
- Splunk: running yes
- DNS: broken (can't resolve external hosts)

## Network
- labnet (virbr-lab, 192.168.50.0/24): active yes
- Host ingestion NIC: 192.168.50.2/24 yes
- nftables rules: in place yes

## VMs
- pfSense: VM doesn't exist yet (ISO download failed due to DNS)
- AD-DC: running, Windows Server 2025 eval, booting now

## Blockers
1. DNS resolution for external hosts broken
2. pfSense ISO not downloaded (needs DNS fix first)
3. AD-DC: unknown if installer is running (need console output)

## Next steps
1. Fix DNS
2. Download pfSense 2.6.0 ISO
3. Create pfSense VM
4. Complete AD-DC Windows install
5. Configure pfSense + AD-DC networking

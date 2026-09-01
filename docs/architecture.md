# Architecture

The rendered topology diagram lives in the [root README](../README.md).

## Layers

| Layer | Component | Function |
|---|---|---|
| Hypervisor | Arch host `larper`, KVM/libvirt | runs everything; also hosts the SIEM and sensors |
| Perimeter | pfSense | firewall, router, DNS forwarder, DHCP — the only way out of labnet |
| Identity | DC01 (Windows Server 2025 Core) | Active Directory, DNS authority for `homelab.lan` |
| Telemetry | Wazuh agent, Sysmon, syslog | moves events off endpoints to the manager |
| Detection | Wazuh rules, Suricata | turns events into alerts |
| Analysis | Wazuh web UI, Splunk | search, pivot, dashboards |
| Response | n8n | enrich, notify, contain |

## Design principles

1. **The lab segment has no NAT.** If pfSense is down, the lab is dark. That is what
   makes it safe for hostile workloads.
2. **Logs live on the host, not in the VM.** VMs get rebuilt; evidence must not vanish.
3. **Snapshot before every experiment.**
4. **One change, one verification.** Never stack three changes and then test.
5. **Time sync everywhere.** Kerberos dies silently on clock skew.
6. **Lab credentials never touch anything real.**
7. **Work bottom-up.** L2 → L3 → DNS → service. Every past failure was a layer problem.

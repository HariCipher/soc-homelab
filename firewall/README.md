# Firewall & network security

**Status:** DEGRADED — see the phase table in the [root README](../README.md) · **Phases 1 & 3**

## Purpose
pfSense is the only route out of the lab segment, so every packet is inspectable and
blockable. Suricata provides network intrusion detection on the same segment.

## Design
- **WAN** `vtnet0` — DHCP on the NAT network (its only path to the internet)
- **LAN** `vtnet1` — 192.168.50.1/24, serving labnet
- Also runs DNS forwarding and DHCP for the segment
- **Suricata runs on the host**, sniffing `virbr-lab` — see [decision 002](../docs/decisions.md)

Firewall policy, DHCP scope and syslog settings are documented in `pfsense/`.

## Verify
```bash
ping -c3 192.168.50.1
curl -sk -o /dev/null -w '%{http_code}\n' https://192.168.50.1/   # expect 200
```

## Upstream
pfSense CE 2.7.2 · Suricata

## My changes
*(to be filled in — firewall rule design, Suricata tuning)*

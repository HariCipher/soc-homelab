# Network design

## Segments

| Segment | Bridge | Range | Purpose |
|---|---|---|---|
| `default` | `virbr0` | 192.168.122.0/24 | NAT to internet — **pfSense WAN only** |
| `labnet` | `virbr-lab` | 192.168.50.0/24 | Isolated lab segment — **no NAT, no DHCP from libvirt** |

`labnet` is defined with no `<forward>` and no `<ip>` block. There is deliberately
no path out of it except through pfSense.

## Addresses

| Host | Address | Notes |
|---|---|---|
| pfSense WAN | DHCP on 192.168.122.0/24 | its only route out |
| pfSense LAN | 192.168.50.1 | gateway, DNS forwarder, DHCP server |
| Arch host on labnet | 192.168.50.2 | log ingestion + management. **Must be set manually — see below** |
| DC01 | 192.168.50.10 | static |

## NOTE: Known gap — host labnet address is not persistent

`labnet` has no libvirt-managed IP, so `virbr-lab` comes up with no address. Nothing
currently assigns `192.168.50.2`. Until this is fixed, the host is unreachable from
the lab segment and **all log forwarding silently fails**.

Manual fix (Phase 1.3), pending a persistent solution:

```bash
sudo ip addr add 192.168.50.2/24 dev virbr-lab
```

## DNS design

```
domain member ──► DC01 (192.168.50.10) ──► pfSense (192.168.50.1) ──► host NAT ──► internet
                  authoritative for          forwarder
                  homelab.lan
```

Domain members must point **only** at DC01. Handing out a public resolver via DHCP
breaks domain join and Kerberos — this is the single most common AD lab mistake.

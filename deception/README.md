# Deception

**Status:** 📋 PLANNED · **Phase 4**

## Purpose
Alerts with near-zero false positives. Nobody has a legitimate reason to touch a
decoy — so any hit is real signal.

## Approach: honeytokens first
| Step | Cost |
|---|---|
| Decoy AD account (never used, SPN set, alert on any auth attempt) | 0 RAM |
| Decoy file share with object auditing enabled | 0 RAM |
| Decoy credentials left where an attacker would look | 0 RAM |

Then, optionally, a **containerised** honeypot on labnet.

## ⚠️ Containment rule — write it before deploying anything
A honeypot that can reach the domain controller is just a compromised host.

```
pfSense: alias HONEYPOT → rule  HONEYPOT → LAN net = BLOCK
```

The rule goes in first, is verified, and only then does the honeypot come up.

## My changes
*(to be filled in)*

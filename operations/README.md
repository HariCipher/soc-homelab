# Operations

**Status:** 📋 PLANNED

## Purpose
Running the lab: routine checks, recovery procedures, and the investigation
writeups that come out of practice sessions.

| Folder | What |
|---|---|
| `runbooks/` | start/stop lab, health check, snapshot, restore |
| `investigations/` | dated incident writeups — the most valuable output of this lab |

## Investigation template
```
What fired · What I saw · What I checked · What actually happened
· Was the detection correct · What I changed as a result
```

## Standing rules
1. Snapshot before every experiment
2. One change, one verification
3. Time sync everywhere
4. Lab credentials never touch anything real
5. Logs live on the host, not in the VM
6. Keep labnet isolated — the only way out is through the firewall

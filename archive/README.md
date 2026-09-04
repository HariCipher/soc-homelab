# NOTE: Archive — previous work

**Nothing in this folder is running.** These are earlier labs, kept as a record of
prior work and as a source of components to migrate into the current build.

The current environment is described in the [root README](../README.md) and its live
state in [STATUS.md](../STATUS.md).

| Lab | Period | What it was | What gets migrated |
|---|---|---|---|
| `2026-08-arch-homelab/` | Aug 2026 | pfSense + Windows Server 2025 AD-DC + Wazuh + Splunk on Arch/KVM. Core infrastructure verified 2026-08-08; telemetry half-wired. | Network design, pfSense settings, log-forwarding script, the failure writeups |
| *(n8n automation)* | earlier | Workflow automation work | SOAR patterns → `automation/` |

> Add the earlier automation work as a subfolder when you locate it — same banner, same
> table row.

## Why keep them
The current lab is an evolution of this work, not a fresh start. The archive shows
the progression, and several design decisions here were learned the hard way there —
particularly the AD DNS forwarding pattern and the layer-by-layer troubleshooting
approach now written into [`docs/architecture.md`](../docs/architecture.md).

## Reading rule
Every status claim in these files was true on the date written and is **not**
current. Treat them as history.

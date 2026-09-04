# automation — SOAR

**Status:** PLANNED — see [STATUS.md](../STATUS.md) · **Phase 6**

## Purpose

Turn Wazuh alerts into actions without a human in the loop for the repetitive
parts: enrich, notify, and where justified, contain.

## Design

n8n runs on the host and is driven by Wazuh. Two integration paths:

| Path | Mechanism | Use for |
|---|---|---|
| Pull | n8n polls the Wazuh API (`:55000`) | scheduled sweeps, digests |
| Push | Wazuh active response calls a webhook | per-alert, low latency |

Push is the real SOAR path. Pull is easier to build first and useful for
practising the API before wiring anything that acts.

## Playbook tiers

Build in this order. Each tier is only safe once the one before it is proven.

| Tier | Playbook | Acts on the lab? |
|---|---|---|
| 1 | **Enrich** — pull agent, rule, ATT&CK technique, recent alerts for the host | no |
| 2 | **Notify** — format and deliver a readable alert summary | no |
| 3 | **Contain** — block a source IP on pfSense, disable an AD account | yes |

## Safety

A containment playbook is the only thing in this lab that changes state
automatically. Rules:

- Tier 3 runs only against explicitly listed targets. Never a wildcard.
- Every action is reversible and the reverse is written before the action.
- Every run logs what it did, to a file on the host.
- Test containment against a throwaway account, never DC01's Administrator.

An automation that can lock you out of your own domain controller is not a
detection improvement.

## Status

Nothing is built. See [STATUS.md](../STATUS.md).

## Verify

Not yet defined — added when the first playbook exists.

## Upstream

| Project | Role |
|---|---|
| [n8n](https://n8n.io) | workflow automation engine |
| Wazuh API | alert source and agent control |

## My changes

To be filled in as playbooks are built.

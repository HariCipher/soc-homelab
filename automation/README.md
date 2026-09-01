# Automation — SOAR with n8n

**Status:** 📋 PLANNED · **Phase 5**

## Purpose
Close the loop: an alert should be able to enrich, notify and contain itself
without a human copying values between windows.

## Playbooks
| # | Playbook | Flow |
|---|---|---|
| 1 | **Enrich** | Wazuh alert → IP/hash reputation lookup → annotated result |
| 2 | **Notify** | formatted alert → chat/mail sink |
| 3 | **Contain** | malicious source IP → block via pfSense API |

## Design notes
- Triggered from the **Wazuh API** / active-response, not by polling log files
- Containment actions are logged back so every automated action is auditable
- Start with notify-only; add containment once false positives are understood

## Exit criteria
One alert travels Wazuh → n8n → action with zero manual steps.

## Upstream
n8n · pfSense API

## My changes
*(to be filled in — playbooks in `n8n/`)*

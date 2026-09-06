# Setup guide — building the lab

Follow in order. **Never skip ahead**: each phase assumes the one before it verified.
Each phase ends with an explicit exit test — run it, screenshot the result, commit.
A phase is not finished because the commands ran; it is finished when its exit test
passes.

Conventions: `$` = Arch host shell · `PS>` = DC01 PowerShell · `GUI` = pfSense web UI.

---

## Phase 1 — Foundation

### 1.1 Start the lab
Nothing autostarts — libvirt VM autostart is deliberately off, so the host boots
without spending 4 GB on VMs you may not need. Start the firewall first and let it
settle before the domain controller, or DC01 comes up with no DNS and no gateway.

```bash
$ virsh -c qemu:///system start pfsense
$ until ping -c1 -W1 192.168.50.1 &>/dev/null; do sleep 2; done
$ virsh -c qemu:///system start ad-dc
```

### 1.2 Make the host's labnet address persistent
The `labnet` network has no libvirt-managed IP, so `virbr-lab` comes up bare and
**all log forwarding silently fails after a reboot**. Pin it with a systemd unit:

```bash
$ sudo tee /etc/systemd/system/labnet-hostip.service >/dev/null <<'UNIT'
[Unit]
Description=Host IP on labnet bridge
After=libvirtd.service network-online.target
Wants=libvirtd.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/ip addr replace 192.168.50.2/24 dev virbr-lab
ExecStop=/usr/bin/ip addr del 192.168.50.2/24 dev virbr-lab

[Install]
WantedBy=multi-user.target
UNIT

$ sudo systemctl daemon-reload
$ sudo systemctl enable --now labnet-hostip.service
$ ip -4 addr show virbr-lab      # expect 192.168.50.2/24
```

> If the bridge does not exist yet at boot, the unit fails harmlessly and can be
> restarted after libvirt brings the network up. Verify after a real reboot.

### 1.3 Reduce DC01 memory to 3 GB — config set, NOT YET APPLIED

Frees 1 GB for the Wazuh indexer. Server Core runs comfortably at 3 GB.
The libvirt config was set on 2026-09-02 and takes effect only at the next boot.

```bash
$ virsh -c qemu:///system dumpxml ad-dc --inactive | grep '<memory'   # 3145728  (config)
$ virsh -c qemu:///system dommemstat ad-dc | head -1                  # actual   (live)
```

If those two disagree, the VM has not been restarted since the change.

NOTE: a Windows Server shutdown takes longer than 45 seconds. Chaining
`shutdown && sleep 45 && start` fails with "Domain is already active" and the VM
never restarts. Wait for the state to actually read `shut off`:

```bash
$ virsh -c qemu:///system shutdown ad-dc
$ until virsh -c qemu:///system domstate ad-dc | grep -q 'shut off'; do sleep 5; done
$ virsh -c qemu:///system start ad-dc
$ virsh -c qemu:///system dommemstat ad-dc | head -1     # expect actual 3145728
```

To undo, re-run `setmaxmem` and `setmem` with `4194304`.

### 1.4 pfSense DHCP scope
`GUI → Services → DHCP Server → LAN`

| Field | Value |
|---|---|
| Enable | yes |
| Range | 192.168.50.100 – 192.168.50.200 |
| DNS servers | **192.168.50.10** (DC01 only) |
| Domain name | `homelab.lan` |
| Gateway | 192.168.50.1 |

NOTE: Do **not** add a public resolver here. Handing 1.1.1.1 to domain members breaks
domain join and Kerberos. This is the most common AD lab mistake.

### 1.5 DC01 time sync
Kerberos fails silently on >5 minutes of clock skew.

```powershell
PS> w32tm /config /manualpeerlist:"192.168.50.1" /syncfromflags:manual /reliable:yes /update
PS> Restart-Service w32time
PS> w32tm /query /status
```

### 1.6 Confirm AD is healthy
```powershell
PS> Get-ADDomain | fl Name,DNSRoot,NetBIOSName,DomainMode
PS> Get-Service NTDS,DNS,Netlogon,kdc | ft Name,Status
PS> dcdiag /q                # empty output = healthy
```

### 1.7 Snapshot both VMs

Snapshot `healthy` exists on both VMs from 2026-09-02.

A snapshot named `healthy-3gb` was also taken, but DC01 was still running at
4 GB at the time, so the name does not describe its contents. Delete it and
re-take after the reboot in 1.3 actually applies:

```bash
$ virsh -c qemu:///system snapshot-delete ad-dc healthy-3gb
$ virsh -c qemu:///system snapshot-create-as ad-dc healthy-3gb "DC01 at 3 GB, AD verified"
$ virsh -c qemu:///system snapshot-list ad-dc
```

A snapshot whose name misstates its contents is worse than no snapshot: it gets
trusted as a rollback point that does not contain what you think.

### DONE Phase 1 exit
Eleven checks, all of which must pass:

```bash
$ virsh -c qemu:///system net-list --all        # default + labnet, both active
$ ip addr show virbr-lab | grep 192.168.50.2    # host address present
$ systemctl is-enabled labnet-hostip.service    # and persistent across reboot
$ curl -sko /dev/null -w '%{http_code}\n' https://192.168.50.1/   # pfSense GUI: 200
$ ping -c1 192.168.50.10                        # DC01 reachable
$ virsh -c qemu:///system snapshot-list ad-dc   # a named rollback point exists
```
On DC01, AD itself must answer — the domain, and its own SRV records:
```powershell
PS> Get-ADDomain
PS> Resolve-DnsName dc01.homelab.lan
PS> Resolve-DnsName -Type SRV _ldap._tcp.homelab.lan
PS> Resolve-DnsName -Type SRV _kerberos._tcp.homelab.lan
PS> Resolve-DnsName archlinux.org             # forwarding out through pfSense works
```
screenshot `evidence/foundation/` — pfSense dashboard, `Get-ADDomain`, verify output.

---

## Phase 2 — Wazuh SIEM platform

### 2.1 Remove Splunk — DONE 2026-09-03

Stopped, uninstalled, and `/opt/splunk` removed. Reclaimed **6.2 GB of disk**.

NOTE: this freed almost no RAM. Splunk was not running and had no systemd unit,
so it had no memory footprint to reclaim. The earlier RAM budget was optimistic on
this point — disk pressure and memory pressure are different problems, and freeing
one does not help the other. The indexer's 1.5 GB has to come from somewhere else,
which is why DC01 dropped to 3 GB and the JVM heap is pinned in 2.4.

### 2.2 Check the manager version first
The indexer, dashboard and every agent **must all match** the manager version.
```bash
$ /var/ossec/bin/wazuh-control info
```
Record that version. Use it in every command below in place of `<VER>`.

### 2.3 Install the Wazuh indexer
Follow the official step-by-step installation for your Wazuh version (the package
repo and certificate-generation steps change between releases, so use the vendor
docs for `<VER>` rather than copying commands from elsewhere):
<https://documentation.wazuh.com/current/installation-guide/index.html>

Single-node configuration. Do not start it yet — first do 2.4.

### 2.4 Cap the JVM heap BEFORE first start (critical)
The default heap sizing will consume most of this host and OOM the lab.

```bash
$ sudo tee /etc/wazuh-indexer/jvm.options.d/heap.options >/dev/null <<'OPT'
-Xms1g
-Xmx1g
OPT
$ sudo systemctl daemon-reload
$ sudo systemctl enable --now wazuh-indexer
$ curl -sk -u admin:<password> https://127.0.0.1:9200/_cluster/health?pretty
```
Expect `"status": "green"` or `"yellow"` (yellow is normal on a single node).

### 2.5 Install the Wazuh dashboard
Per the same official guide. Then confirm memory headroom **with both VMs running**:
```bash
$ free -h                     # need ≥1 GB available
```
If it is tight, drop to a console session while working (`Ctrl+Alt+F2`) — that
reclaims 2–3 GB from the desktop.

### 2.6 Connect the manager to the indexer
Filebeat ships manager alerts into the indexer.
```bash
$ sudo filebeat test output   # must succeed before continuing
$ sudo systemctl enable --now filebeat
```

### 2.7 Short retention (this host cannot hold months of logs)
In the dashboard: **Index Management → State management policies**. Set a policy
that deletes indices after a small number of days, and apply it to `wazuh-alerts-*`.

### DONE Phase 2 exit
- Dashboard reachable over HTTPS and shows the manager
- Cluster health green/yellow
- `free -h` shows ≥1 GB available with both VMs up

screenshot `evidence/siem/` — dashboard overview, cluster health, `free -h`.

---

## Phase 3 — Telemetry

Take the rollback point first — this phase installs an agent and rewrites audit
policy on the domain controller:

```bash
$ virsh -c qemu:///system snapshot-create-as ad-dc pre-phase3 "before telemetry"
```

**Start the indexer before anything ships to it.** If it is not running, events
still reach the manager but nothing lands in the index, and the phase looks broken
for a reason that has nothing to do with the endpoint.

```bash
$ sudo systemctl start wazuh-indexer
```

**Declare the event channels once, on the manager.** `/var/ossec/etc/shared/default/agent.conf`
is pulled by every agent in the group, so the channels live in one place and DC01's
own `ossec.conf` is never hand-edited:

```xml
<!-- /var/ossec/etc/shared/default/agent.conf -->
<agent_config os="Windows">
  <localfile><location>Security</location><log_format>eventchannel</log_format></localfile>
  <localfile><location>Microsoft-Windows-Sysmon/Operational</location><log_format>eventchannel</log_format></localfile>
  <localfile><location>Microsoft-Windows-PowerShell/Operational</location><log_format>eventchannel</log_format></localfile>
  <localfile><location>System</location><log_format>eventchannel</log_format></localfile>
</agent_config>
```

Then add the syslog listener pfSense will send to (3.5), inside `ossec.conf`:

```xml
<remote>
  <connection>syslog</connection>
  <port>514</port>
  <protocol>udp</protocol>
  <allowed-ips>192.168.50.0/24</allowed-ips>
  <local_ip>192.168.50.2</local_ip>
</remote>
```

Validate before restarting — a bad `ossec.conf` takes the manager down, and the
manager is the thing you would use to debug it:

```bash
$ sudo /var/ossec/bin/wazuh-remoted -t && sudo systemctl restart wazuh-manager
$ ss -lntu | grep -E ':(1514|1515|514) '     # all three must be listening
```

### 3.1 Wazuh agent on DC01
**Version must equal the manager version from 2.2.**
```powershell
PS> Invoke-WebRequest -Uri "https://packages.wazuh.com/4.x/windows/wazuh-agent-<VER>-1.msi" -OutFile C:\wazuh-agent.msi
PS> msiexec /i C:\wazuh-agent.msi /q WAZUH_MANAGER="192.168.50.2" WAZUH_REGISTRATION_SERVER="192.168.50.2" WAZUH_AGENT_NAME="DC01"
PS> NET START Wazuh
```
Confirm from the host:
```bash
$ sudo /var/ossec/bin/agent_control -l      # DC01 should be Active
```

### 3.2 Windows audit policy
```powershell
PS> auditpol /set /subcategory:"Logon"             /success:enable /failure:enable
PS> auditpol /set /subcategory:"Logoff"            /success:enable
PS> auditpol /set /subcategory:"Process Creation"  /success:enable
PS> auditpol /set /subcategory:"Credential Validation" /success:enable /failure:enable
PS> auditpol /set /subcategory:"Directory Service Access" /success:enable /failure:enable
```
Those subcategory names are **localised**. On a non-English Windows they do not
match and `auditpol` fails with a message that reads like a permissions problem.
Use the GUID instead, which is stable everywhere — Process Creation is
`{0CCE922B-69AE-11D9-BED3-505054503030}`:
```powershell
PS> auditpol /set /subcategory:"{0CCE922B-69AE-11D9-BED3-505054503030}" /success:enable
```

**If a setting reverts:** DC01 is a domain controller, so Default Domain Controllers
Policy overwrites anything `auditpol` set locally at the next GPO refresh. Re-applying
it looks like it worked, then it disappears again. Set it in the GPO instead —
Computer Configuration → Policies → Windows Settings → Security Settings → Advanced
Audit Policy Configuration.

Include the command line in 4688 events — without this, 4688 is nearly useless:
```powershell
PS> reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f
```

### 3.3 PowerShell script-block logging (4104)
```powershell
PS> New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force
PS> Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockLogging -Value 1
```

### 3.4 Sysmon
```powershell
PS> Invoke-WebRequest -Uri "https://download.sysinternals.com/files/Sysmon.zip" -OutFile C:\Sysmon.zip
PS> Expand-Archive C:\Sysmon.zip -DestinationPath C:\Sysmon
PS> Invoke-WebRequest -Uri "https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml" -OutFile C:\Sysmon\config.xml
PS> C:\Sysmon\Sysmon64.exe -accepteula -i C:\Sysmon\config.xml
```
Nothing to configure on the agent for this — the Sysmon channel is already in the
shared `agent.conf` above, and DC01 picks it up on the next pull. Force it now:
```powershell
PS> Restart-Service WazuhSvc
```

### 3.5 pfSense remote syslog
`GUI → Status → System Logs → Settings → Remote Logging`

| Field | Value |
|---|---|
| Enable Remote Logging | yes |
| Source Address | LAN |
| Remote server 1 | `192.168.50.2:514` |
| Events | Firewall, DHCP, System, VPN, Portal Auth |

### DONE Phase 3 exit — the end-to-end test
`phase3-dc01.ps1` fires this on its last step, so it should already be in the
index. To repeat it by hand on DC01:
```powershell
PS> runas /user:homelab\nosuchuser cmd      # enter a wrong password
```
Then find event **4625** in the Wazuh dashboard. That single test proves agent →
manager → indexer → dashboard all work.

Confirm it from the **indexer**, not from the agent's own claim — the agent
reporting Active only means it is connected, not that events are being stored:

```bash
$ sudo /var/ossec/bin/agent_control -l                  # DC01 must be Active
$ curl -sk -u admin:admin 'https://127.0.0.1:9200/wazuh-alerts-*/_count' \
    -H 'Content-Type: application/json' \
    -d '{"query":{"match":{"data.win.system.eventID":"4625"}}}'
```

Repeat that count for `4688` (process creation), `4104` (script block) and a
`match_phrase` on `data.win.system.providerName: Microsoft-Windows-Sysmon`. A
non-zero count for each means the whole layer works.

**Do not check this by grepping `alerts.json` for `"id":"4688"`** — `id` is the
*rule* id there, not the event number, so it silently never matches. That mistake
and a worse one next to it are written up in [issues.md](issues.md#5--two-verification-checks-passed-for-the-wrong-reasons).

screenshot `evidence/identity/` + `evidence/siem/` — agent Active, the 4625 alert, a Sysmon event.

---

## Phase 4 — Suricata (on the host)

```bash
$ sudo pacman -S suricata
$ sudo suricata-update
```
Configure `af-packet` against the lab bridge in `/etc/suricata/suricata.yaml`:
```yaml
af-packet:
  - interface: virbr-lab
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
```
Set `HOME_NET: "[192.168.50.0/24]"` in the same file, then:
```bash
$ sudo suricata -T -c /etc/suricata/suricata.yaml -v    # config test
$ sudo systemctl enable --now suricata
$ sudo tail -f /var/log/suricata/eve.json
```
Ship `eve.json` into Wazuh — add to `/var/ossec/etc/ossec.conf`:
```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```
```bash
$ sudo systemctl restart wazuh-manager
```

**Then tune.** Run the lab normally for a day, list the noisiest signatures, and
disable or threshold them. An untuned IDS is noise, not detection.

### DONE Phase 4 exit
A deliberate scan from the host to DC01 produces a Suricata alert visible in the
Wazuh dashboard, and the false-positive baseline is written down.

screenshot `evidence/detection/` — the Suricata alert.

---

## Phase 5 — Detection engineering

1. Find what the default ruleset misses.
2. Write custom rules in `/var/ossec/etc/rules/local_rules.xml`; keep the source of
   truth in `detection/wazuh-rules/` in this repo.
3. Map each rule to a MITRE ATT&CK technique ID.
4. Write a test per rule that reproduces the alert.

```bash
$ sudo /var/ossec/bin/wazuh-logtest      # test a rule against a sample log line
```

### DONE Phase 5 exit
≥5 custom detections, each mapped and each with a reproducible test.

---

## Phase 6 — SOAR automation

You are wiring the last link: alert to action. Everything before this produced
information; this phase makes the lab do something with it.

**Why n8n and not a shell script.** Wazuh active response can already run a script.
The problem is that a script leaves no trace of what it did or why. n8n gives you an
execution log per run, retries, and a diagram you can show someone. See decision 004.

**The order matters, and it is not negotiable.** Build enrich, then notify, then
contain. Containment is the only thing in this lab that changes state on its own. A
containment playbook wired to a noisy rule will block your own traffic or disable a
real account, and you will be debugging the automation instead of the detection.

### 6.1 Install n8n on the host

```bash
$ sudo pacman -S --needed nodejs npm
$ sudo npm install -g n8n
$ n8n start          # first run, then daemonise with a systemd unit
```

Reachable at http://localhost:5678.

### 6.2 Give n8n a read-only Wazuh API user

Do not let it use the `wazuh` admin account. Create a dedicated user with read
permissions only, so a mistake in a playbook cannot change manager config.

```bash
$ curl -sk -u wazuh:<pw> -X POST https://192.168.50.2:55000/security/users \
    -H 'Content-Type: application/json' \
    -d '{"username":"n8n","password":"<pw>"}'
```

Record it in `secrets/credentials.md` (gitignored).

### 6.3 Tier 1 — enrich (no side effects)

Trigger: schedule, every 5 minutes.
Steps: query the Wazuh API for alerts above level 7, and for each one pull the agent
name, the rule description and the MITRE technique.

This is the safe place to learn the API shape. Nothing it does can hurt the lab.

### 6.4 Tier 2 — notify

Same trigger, plus a formatting step that produces one readable line per alert.
Deliver it wherever you actually read things.

### 6.5 Push instead of poll

Add a Webhook node in n8n, then point Wazuh active response at it in
`/var/ossec/etc/ossec.conf`. Now an alert reaches n8n in a second instead of five
minutes.

### 6.6 Tier 3 — contain

Two playbooks:

| Playbook | Action | Reverse |
|---|---|---|
| Block IP | add the address to a pfSense alias used by a block rule | remove from alias |
| Disable account | `Disable-ADAccount` on DC01 | `Enable-ADAccount` |

**Write and test the reverse first.** Then test the forward action against a
throwaway AD account and a source IP you control. Never against Administrator.

### 6.7 Log every action

Every Tier 3 run appends to a file on the host: timestamp, alert ID, target, action,
result. If you cannot answer "what did the automation do last night" from a file, the
automation is not finished.

### Phase 6 exit

A Phase 5 detection fires, n8n enriches it automatically, a containment playbook
blocks a test IP, and the reverse playbook unblocks it. Both visible in the n8n
execution log.

screenshot `evidence/automation/` — n8n execution log, and the pfSense rule the
playbook created.

---

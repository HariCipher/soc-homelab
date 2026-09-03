# Host systemd units

## `labnet-hostip.service`

`labnet` is an isolated libvirt network: no `<forward>`, no `<ip>`, therefore
libvirt never assigns the host an address on `virbr-lab`. Without one, the host
cannot receive Wazuh agent traffic or pfSense syslog — and the failure is
**silent**: the VMs stay healthy, logs simply go nowhere.

This unit re-applies `192.168.50.2/24` on every boot.

```bash
sudo install -m644 infrastructure/systemd/labnet-hostip.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now labnet-hostip.service
```

Verify: `scripts/verify/00-host.sh` → `labnet IP is persistent` PASS.

## Summary

The code here configures the automatic document scanner service for the [paperworker](https://hackaday.io/project/28232-paperworker) project.

## Some useful commands to run as part of document scanner configuration

Discover connected scanners supported by scanadf. Userful for setting up
SCAN_DEVICE_* variables:

```
# scanadf -L
device `dsseries:usb:0x04F9:0x60E0' is a BROTHER DS-720D sheetfed scanner
```

## The setup using Ansible

The code was tested against Ubuntu 18.04.2 LTS.

The setup requires Ansible and an inventory file (`inventories/prod` in this case) which points to the machine we want to setup, example commands below can be replicated to provision on the "inbox" host reachable via SSH:

```
$ ls -l
total 8
-rw-r--r--@ 1 maciej.grela  staff  54 Apr 22 20:46 inbox.yml
drwxr-xr-x  3 maciej.grela  staff  96 Apr 22 18:36 inventories
drwxr-xr-x  3 maciej.grela  staff  96 Apr 22 18:23 roles
$ head inventories/prod
inboxes:
  hosts:
    inbox:
      scan_width_mm: 210
      scan_height_mm: 297
      scan_resolution: 300
      scan_source: Duplex ADF
      scan_device: dsseries
      scan_mode: Color
      quirks:
$ mkdir .venv
$ python3 -m venv .venv
$ source .venv/bin/activate
(.venv) $ pip -q install ansible
(.venv) $ ansible-playbook -K -i inventories/prod inbox.yml
SUDO password:

PLAY [inboxes] *************************************************************************************************************************************************************************************

TASK [Gathering Facts] *****************************************************************************************************************************************************************************
ok: [inbox]

TASK [inbox : Create inbox user inbox] *************************************************************************************************************************************************************
ok: [inbox]

TASK [inbox : Create inbox tmpfiles.d in /etc/tmpfiles.d] ******************************************************************************************************************************************
ok: [inbox]

TASK [inbox : Create inbox dirs in /var/lib/inbox] *************************************************************************************************************************************************
ok: [inbox]

TASK [inbox : Create inbox config file in /etc/default] ********************************************************************************************************************************************
ok: [inbox]

TASK [inbox : Create scripts in /usr/local/bin] ****************************************************************************************************************************************************
ok: [inbox] => (item=document-scanner.j2)
ok: [inbox] => (item=handle-scan.j2)
ok: [inbox] => (item=ingester.j2)

TASK [inbox : Create systemd service files in /etc/systemd/system] *********************************************************************************************************************************
ok: [inbox] => (item=document-scanner.service.j2)
ok: [inbox] => (item=ingest@.service.j2)

TASK [inbox : Enable and start document-scanner service] *******************************************************************************************************************************************
ok: [inbox]

PLAY RECAP *****************************************************************************************************************************************************************************************
inbox                      : ok=8    changed=0    unreachable=0    failed=0
(.venv) $ ssh inbox systemctl status document-scanner.service
● document-scanner.service - Automatic document scanner
   Loaded: loaded (/etc/systemd/system/document-scanner.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2019-04-22 21:06:24 CEST; 38min ago
 Main PID: 8573 (document-scanne)
    Tasks: 4 (limit: 976)
   CGroup: /system.slice/document-scanner.service
           ├─8573 /bin/sh /usr/local/bin/document-scanner
           ├─8610 /bin/sh /usr/local/bin/document-scanner
           ├─8611 grep -vF Scanned 0 pages
           └─8613 scanadf -d dsseries --source Duplex ADF --mode Color -x 210 --resolution 300 -S /usr/local/bin/handle-scan

Apr 22 21:07:54 inbox document-scanner[8573]: scanadf: open of device dsseries failed: Error during device I/O
Apr 22 21:08:10 inbox document-scanner[8573]: Scanned document image-0001
Apr 22 21:08:10 inbox document-scanner[8573]: Scanned document image-0002
Apr 22 21:08:10 inbox document-scanner[8573]: Scanned 2 pages
Apr 22 21:10:33 inbox document-scanner[8573]: Scanned document image-0001
Apr 22 21:10:33 inbox document-scanner[8573]: Scanned document image-0002
Apr 22 21:10:33 inbox document-scanner[8573]: Scanned 2 pages
Apr 22 21:12:47 inbox document-scanner[8573]: Scanned document image-0001
Apr 22 21:12:47 inbox document-scanner[8573]: Scanned document image-0002
Apr 22 21:12:47 inbox document-scanner[8573]: Scanned 2 pages
```

As we can see above from the systemctl command output our service is up and running successfuly.



## Summary

The code here configures the automatic document scanner service for the [paperworker](https://hackaday.io/project/28232-paperworker) project.

## Why another scanner frontend.

There are multiple scanner frontends available on Github, just to mention a few that I found noteworthy:

- https://github.com/rocketraman/sane-scan-pdf
- https://github.com/gsauthof/adf2pdf
- https://github.com/johndoe31415/bulkscan
- https://github.com/BluemediaGER/ScanOS
- https://github.com/Shigawire/documentary

The differences between them and inbox can be summarised as:

1. Inbox is designed to work together with a separate document management solution which handles OCR, this means that 
there is no OCR being performed on the pages except simple image cleanup.

2. Inbox works with scanning small pieces of paper (like receipts) on a sheetfed scanner where the scan bitmap
contains a large amount of free space and a small amount of "content". Using existing tools as 'unpaper' directly on such a bitmap
does not yield good results as unpaper begins to search for content from the center of the bitmap by default

3. I wanted to record a more extensive set of metadata for the documents than it's usually the case. Specifically, inbox stores:
- scanner vendor and model as well as the serial number
- digitization date
- versions of the software components used for the worflow pipeline

4. Inbox performs intelligent image orientation detection where pages that do not contain enough test for tesseract to properly
perform OSD (Orientation and Script Detection) can still be oriented properly by looking at the other side of the sheet to which they
belong.

5. Inbox performs blank page detection and removal using a feature extraction algorigthm with opencv instead of calculating image mean
which I found to be very reliable.

6. Inbox uses imagemagick's deskew operation instead of unpaper's deskew for better results on aforementioned pages containing small
receipts on large scan bitmaps.

Lastly, inbox generates PDF/A documents by default and optimized them with qpdf.

## Some useful commands to run as part of document scanner configuration

Discover connected scanners supported by sane. This is useful to setup the inbox.conf [scanner] section.

```
# scanadf -L
device `dsseries:usb:0x04F9:0x60E0' is a BROTHER DS-720D sheetfed scanner
```

As the code uses libinsane a 'sane:' prefix needs to be added when specifying a device. This means that `dsseries:usb:0x04F9:0x60E0' has to become
`sane:dsseries:usb:0x04F9:0x60E0'.

## The setup using NixOS

In order to use this code with NixOS you need to do four things:

0. Configure lcdproc (even if a dummy display). The scan-loop code uses it as the UI. The lcdproc might not be connected to an actual LCD (use the "dummy" driver) but it has to be started.
1. Include the packaging.nix https://github.com/enkiusz/tools/ into your configuration (for example as an overlay). This repository contains one of the scripts used by inbox. In the next configuration files it is assumed that the derivation creates the 'enkiusz-tools' package in your nixpkgs.
2. Include the packages.nix containing the inbox derivation into your configuration (for example as an overlay). The next files assume that the package is named 'inbox'.
3. (optional) If you are using NixOS include the systemd unit configuration in order to run the scan-loop and workflow-loop scripts as system services. An example NixOS configuration is provided in the service.nix file.

## The setup using Ansible

The previous version of this code has used Ansible for setup. As I am no longer using Ubuntu in my personal infrastructure the Ansible roles have been removed. In
cas they need to be accessed the old repository version has been markedwith the 'v0' tag.



{ config, pkgs, lib, ... }:
let
  cfg = config.services.inbox;

  inboxConf = pkgs.writeText "inbox.conf" ''

  [scanner]
  device_id=sane:dsseries:usb:0x04F9:0x60E0
  vendor=Brother
  model=DS-720D
  serial_no=SERIALNO

  [scanner.settings]
  mode=Color
  source=Duplex ADF
  resolution=300
  # Scan size in the x direction [mm]
  br-x=215.9
  # Scan size in the y direction [mm]
  br-y=355.6

  [display.lcdproc]
  hostname=localhost
  port=13666

  [libinsane]
  read_block_size=262144

  [workflow]
  default_pagecount=2
  page_filename_format=sheet-{n:03d}-{side}
  workflow_inbox=/var/lib/inbox/postprocess

  [workflow.deskew]
  deskew_percentage=40

  [workflow.unpaper]
  mask_scan_size=5,5

  [workflow.img2pdf]
  icc_profile=${pkgs.colord}/share/color/icc/colord/sRGB.icc

  [output]
  type=rsync
  spool_dir=/var/lib/inbox/cabinet

  [output.rsync]
  connect_prog=ssh -o UserKnownHostsFile=$CREDENTIALS_DIRECTORY/known_hosts -i $CREDENTIALS_DIRECTORY/id_ed25519 -l user paperless-ngx nc localhost rsync
  target=rsync://inbox@localhost/consume/${config.networking.hostName}.${config.networking.domain}/
  credentials_file=$CREDENTIALS_DIRECTORY/rsync.secret
  '';

in {


  config = {
    systemd.services.scan-loop = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.inbox}/bin/scan-loop";
        DynamicUser = "yes";
        User = "inbox";
        StateDirectory = "inbox";

        # udev rules setting GROUP="scanner" do not work because 50-Brother_DSScanner.rules
        # get overriden by 50-udev-default.rules
        # sg2: /nix/store/i5j4rdpbf2zzdcxprc7fhi1j43s0vpc0-udev-rules/50-Brother_DSScanner.rules:2 GROUP 59
        # sg2: /nix/store/i5j4rdpbf2zzdcxprc7fhi1j43s0vpc0-udev-rules/50-Brother_DSScanner.rules:2 MODE 0666
        # sg2: /nix/store/4vhrr4fm8p6cf1yrqs2azhhjygk09zd7-systemd-254.6/lib/udev/rules.d/50-udev-default.rules:92 GROUP 6
        # sg2: /nix/store/4vhrr4fm8p6cf1yrqs2azhhjygk09zd7-systemd-254.6/lib/udev/rules.d/71-seat.rules:74 Importing properties from results of builtin command 'path_id'
        # sg2: /nix/store/4vhrr4fm8p6cf1yrqs2azhhjygk09zd7-systemd-254.6/lib/udev/rules.d/73-seat-late.rules:16 RUN 'uaccess'
        # sg2: Preserve permissions of /dev/sg2, uid=0, gid=6, mode=0666
        # sg2: Successfully created symlink '/dev/char/21:2' to '/dev/sg2'
        # sg2: sd-device: Created db file '/run/udev/data/c21:2' for '/devices/pci0000:00/0000:00:1d.0/usb2/2-1/2-1.2/2-1.2:1.0/host6/target6:0:0/6:0:0:0/scsi_generic/sg2'
        SupplementaryGroups = "disk";
      };
      environment = {
        INBOX_CONF = "${inboxConf}";
        GI_TYPELIB_PATH = "${pkgs.libinsane}/lib/girepository-1.0/";
        SANE_CONFIG = "/etc/sane-config";
        LD_LIBRARY_PATH = "/etc/sane-libs";
      };
    };

    systemd.services.workflow-loop = {
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ enkiusz-tools inbox imagemagick unpaper gawk img2pdf exiftool qpdf rsync openssh tesseract ];
      serviceConfig = {
        ExecStart = "${pkgs.inbox}/bin/workflow-loop";
        DynamicUser = "yes";
        User = "inbox";
        StateDirectory = "inbox";
        LoadCredential = [
          "rsync.secret:/root/secrets/inbox/rsync.secret"
          "id_ed25519:/root/secrets/inbox/id_ed25519"
          "known_hosts:/root/secrets/inbox/known_hosts"
        ];
      };
      environment = {
        INBOX_CONF = "${inboxConf}";
      };
    };

    systemd.timers.cabinet-retry = {
      wantedBy = [ "multi-user.target" ];
      timerConfig = {
        OnCalendar = "daily";
      };
    };

    systemd.services.cabinet-retry = {
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [ enkiusz-tools inbox rsync openssh ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.inbox}/bin/cabinet-retry";
        DynamicUser = "yes";
        User = "inbox";
        StateDirectory = "inbox";
        LoadCredential = [
          "rsync.secret:/root/secrets/inbox/rsync.secret"
          "id_ed25519:/root/secrets/inbox/id_ed25519"
          "known_hosts:/root/secrets/inbox/known_hosts"
        ];
      };
      environment = {
        INBOX_CONF = "${inboxConf}";
      };
    };


  };

}

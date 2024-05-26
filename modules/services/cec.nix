{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.cec;
  cecAutostartUdevRule = pkgs.writeTextFile {
    name = "cec-autostart-udev-rule";
    text = ''
      SUBSYSTEM=="cec" KERNEL=="cec0" ACTION=="add" TAG+="systemd" ENV{SYSTEMD_WANTS}="cec0-configure.service"
    '';
    destination = "/etc/udev/rules.d/99-cec-autostart.rules";
  };
  pulse8CecAutoattachUdevRule = pkgs.writeTextFile {
    name = "pulse8-cec-autoattach-udev-rule";
    text = ''
      SUBSYSTEM=="tty" ACTION=="add" ATTRS{manufacturer}=="Pulse-Eight" ATTRS{product}=="CEC Adapter" TAG+="systemd" ENV{SYSTEMD_WANTS}="pulse8-cec-attach@$devnode.service"

      # Force device to be reconfigured when reset after suspend, otherwise the ttyACM link is lost but udev will not notice.
      # A usb_dev_uevent with DEVNUM=000 is a sign that the device is being reset before enumeration.
      # Re-configuring causes ttyACM to be removed and re-added instead.
      SUBSYSTEM=="usb" ACTION=="change" ATTR{manufacturer}=="Pulse-Eight" ATTR{product}=="CEC Adapter" ENV{DEVNUM}=="000" ATTR{bConfigurationValue}=="1" ATTR{bConfigurationValue}="1"
    '';
    destination = "/etc/udev/rules.d/99-pulse8-cec-autoattach.rules";
  };
in {
  options.a.services.cec = {
    enable = lib.mkEnableOption "Enable cec service";
    cecPhysAddr = lib.mkOption {
      type = lib.types.str;
      description = "CEC Physical Address";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPatches = [{
      name = "pulse8-cec-module";
      patch = null;
      extraConfig = ''
        MEDIA_CEC_SUPPORT y
        USB_PULSE8_CEC m
      '';
    }];
    services.udev.packages = [ cecAutostartUdevRule pulse8CecAutoattachUdevRule ];
    systemd.services = {
      cec0-configure = {
        description = "CEC0 Configure";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''${lib.getBin pkgs.v4l-utils}/bin/cec-ctl --device=0 "--osd-name=%H" --playback --phys-addr=${cfg.cecPhysAddr}'';
        };
      };
      "pulse8-cec-attach@" = {
        description = "Configure USB Pulse-Eight serial device at %I";
        unitConfig.ConditionPathExists = "%I";
        serviceConfig = {
          Type = "forking";
          ExecStart = ''${lib.getBin pkgs.linuxConsoleTools}/bin/inputattach --daemon --pulse8-cec %I'';
        };
      };
    };
  };
}

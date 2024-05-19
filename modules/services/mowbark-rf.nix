{ config, lib, pkgs, ... }:
let
  cfg = config.services.mowbark-rf;
  mowbarkRfUdevRule = pkgs.writeTextFile {
    name = "mowbark-rf-udev-rule";
    text = ''SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6014", MODE="0666"'';
    destination = "/etc/udev/rules.d/99-mowbark-rf.rules";
  };
in {
  options.services.mowbark-rf = {
    enable = lib.mkEnableOption "Enable mowbark-rf service";
  };

  config = lib.mkIf cfg.enable {
    services.udev.packages = [ mowbarkRfUdevRule ];
    boot.blacklistedKernelModules = [ "ftdi_sio" ];
    systemd.services.mowbark-rf = {
      description = "Mowbark RF";
      wantedBy = [ "podman-homeassistant.service" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getBin pkgs.mowbark-rf}/bin/mowbark-rf";
      };
    };
  };
}

{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.homeassistant;
  mowbarkRfUdevRule = pkgs.writeTextFile {
    name = "mowbark-rf-udev-rule";
    text = ''SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6014", MODE="0666"'';
    destination = "/etc/udev/rules.d/99-mowbark-rf.rules";
  };
in {
  options.a.services.homeassistant = {
    enable = lib.mkEnableOption "Enable homeassistant service";
    host = lib.mkOption {
      type = lib.types.str;
      description = "Host to bind on";
    };
  };

  config = lib.mkIf cfg.enable {
    a.services.mowbark-rf.enable = true;
    a.services.lirc.enable = true;
    virtualisation.oci-containers = {
      containers = {
        homeassistant = {
          volumes = [
            "/var/home-assistant:/config"
            "/etc/timezone:/etc/timezone:ro"
            "/etc/localtime:/etc/localtime:ro"
          ];
          image = "ghcr.io/home-assistant/home-assistant:2024.5.3";
          ports = [
            "${cfg.host}:80:8123"
          ];
          extraOptions = [
            #"--network=bridge"
            #"--device=/dev/ttyACM0:/dev/ttyACM0"  # Example, change this to match your own hardware
          ];
        };
      };
    };
  };
}

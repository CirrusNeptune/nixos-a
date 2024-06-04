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
    a.services.cec.enable = true;
    a.services.lirc.enable = true;
    virtualisation.oci-containers = {
      containers = {
        homeassistant = {
          volumes = [
            "/var/home-assistant:/config"
            "/etc/timezone:/etc/timezone:ro"
            "/etc/localtime:/etc/localtime:ro"
            "/run/lirc:/lircd"
            "/dev:/dev"
          ];
          image = "ghcr.io/cirrusneptune/homeassistant-mowbark:main";
          ports = [
            "${cfg.host}:80:8123"
          ];
          extraOptions = [
            "--hostuser=homeassistant"
            "--group-add=26"
            "--device-cgroup-rule=\"c *:* rw\""
          ];
          user = "homeassistant";
        };
      };
    };

    users = {
      users.homeassistant = {
        isNormalUser = true;
        group = "homeassistant";
        extraGroups = [ "video" ];
        uid = 1100;
      };
      groups.homeassistant = {
        gid = 1100;
      };
    };
  };
}

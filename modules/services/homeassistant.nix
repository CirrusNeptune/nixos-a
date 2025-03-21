{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.homeassistant;

  mowbarkRfUdevRule = pkgs.writeTextFile {
    name = "mowbark-rf-udev-rule";
    text = ''SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6014", MODE="0666"'';
    destination = "/etc/udev/rules.d/99-mowbark-rf.rules";
  };

  haImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/cirrusneptune/homeassistant-mowbark";
    imageDigest = "sha256:21dc97bc6cb5bdfecbc9ca613eb939bdfa0e0ed385b0d850c00af0fed979cd1b";
    sha256 = "sha256-cJ5yIM3SfDS0N4NiUlHDU/a0UIQgLQeeYe4m0JthQDA=";
    finalImageTag = "a";
    finalImageName = "localhost/homeassistant-a";
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
          imageFile = haImage;
          image = "localhost/homeassistant-a:a";
          #image = "ghcr.io/cirrusneptune/homeassistant-mowbark:sha256-f8c8f7b4ff489822490aa40a5343e9772431b640069176da086e132a839d0c25";
          #image = "localhost/hatest";
          ports = [
            "${cfg.host}:80:8123"
          ];
          extraOptions = [
            "--hostuser=homeassistant"
            "--group-add=3"
            "--group-add=26"
            "--group-add=27"
            "--device-cgroup-rule=\"c *:* rw\""
            "--cap-add=SYS_TTY_CONFIG"
            "--cap-add=SETPCAP"
          ];
          user = "homeassistant";
        };
      };
    };

    # Allow VT_ACTIVATE for switching tty
    #systemd.services.podman-homeassistant.serviceConfig.AmbientCapabilities = [ "CAP_SYS_TTY_CONFIG" ];

    users = {
      users.homeassistant = {
        isNormalUser = true;
        group = "homeassistant";
        extraGroups = [ "video" "tty" "dialout" ];
        uid = 1100;
      };
      groups.homeassistant = {
        gid = 1100;
      };
    };
  };
}

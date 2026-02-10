{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.homeassistant;

  tty0UdevRule = pkgs.writeTextFile {
    name = "tty0-udev-rule";
    text = ''KERNEL=="tty0", SUBSYSTEM=="tty", MODE="0660"'';
    destination = "/etc/udev/rules.d/0-tty0.rules";
  };

  zwaUdevRule = pkgs.writeTextFile {
    name = "zwa-udev-rule";
    text = ''KERNEL=="ttyACM[0-9]*", SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="4001", SYMLINK="ttyZWA"'';
    destination = "/etc/udev/rules.d/99-zwa.rules";
  };

  haImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/cirrusneptune/homeassistant-mowbark";
    imageDigest = "sha256:9755b496bf84bcf53fc8022777434502a0765ccacc97b92467b10bb8f55ffe32";
    sha256 = "sha256-K9U2rSt582woAktu2RQRs1q33zQ6vADCmG/QsVBde6g=";
    finalImageTag = "a";
    finalImageName = "localhost/homeassistant-a";
  };

  esphomeImage = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/esphome/esphome";
    imageDigest = "sha256:c9583f3073d3708c0eb4f602aa0fbaa5a8caf32d313d0558728eb3b75f840304";
    sha256 = "sha256-vFe0p0LOVeUmGRj7CySPZgSDY1/8QnmCao/D4OBOUkQ=";
    finalImageTag = "a";
    finalImageName = "localhost/esphome-a";
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
    a.services.mowbark-rf.enable = false;
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
            "--dns=10.0.0.1"
          ];
          user = "homeassistant";
        };
        esphome = {
          volumes = [
            "/var/esphome:/config"
            "/etc/timezone:/etc/timezone:ro"
            "/etc/localtime:/etc/localtime:ro"
          ];
          imageFile = esphomeImage;
          image = "localhost/esphome-a:a";
          ports = [
            "${cfg.host}:6052:6052"
          ];
          extraOptions = [
            "--hostuser=homeassistant"
          ];
          user = "homeassistant";
          environment = {
            USERNAME = "puppy";
            PASSWORD = "bark";
          };
        };
      };
    };

    # Voice assistant services
    services.wyoming = {
      faster-whisper.servers = {
        hass-whisper = {
          enable = true;
          uri = "tcp://0.0.0.0:10300";
          language = "en";
          model = "distil-small.en";
        };
      };
      piper.servers = {
        hass-piper = {
          enable = true;
          voice = "en-us-ryan-medium";
          uri = "tcp://0.0.0.0:10200";
        };
      };
      openwakeword = {
        enable = false;
        uri = "tcp://0.0.0.0:10400";
      };
    };
    services.zwave-js = {
      enable = false;
      serialPort = "/dev/ttyZWA";
      secretsConfigFile = "/secrets/zwave-js-keys.json";
    };
    services.zwave-js-ui = {
      enable = true;
      serialPort = "/dev/ttyZWA";
      settings = {
        HOST = "0.0.0.0";
        PORT = "8091";
      };
    };

    services.esphome = {
      enable = false;
      address = "10.0.0.3";
    };

    # Allow VT_ACTIVATE for switching tty
    #systemd.services.podman-homeassistant.serviceConfig.AmbientCapabilities = [ "CAP_SYS_TTY_CONFIG" ];

    # udev rules for hardware
    services.udev.packages = [ tty0UdevRule zwaUdevRule ];

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

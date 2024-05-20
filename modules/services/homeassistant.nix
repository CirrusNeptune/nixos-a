{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.homeassistant;

  mowbarkRfUdevRule = pkgs.writeTextFile {
    name = "mowbark-rf-udev-rule";
    text = ''SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6014", MODE="0666"'';
    destination = "/etc/udev/rules.d/99-mowbark-rf.rules";
  };

  dockerBase = pkgs.dockerTools.pullImage {
    imageName = "ghcr.io/home-assistant/home-assistant";
    finalImageTag = "2024.5.4";
    imageDigest = "sha256:6f5eeb8360d9d58ff096c7259366993b4b01ebe11251c2b83c9329daad441b00";
    sha256 = "sha256-yWyOEBCrKuFp7SEfDbdiFPPYwSSg0t9fSqPEs2ow7Is=";
  };

  dockerImage = pkgs.dockerTools.buildImage {
    name = "homeassistant-mowbark";
    tag = "latest";

    fromImage = dockerBase;
    runAsRoot = ''
      pip3 install lirc
    '';

    diskSize = 8192;
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
          image = "homeassistant-mowbark:latest";
          imageFile = dockerImage;
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

{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.kodi;
  kodi-package = (pkgs.kodi-wayland.withPackages
    (kodiPkgs: with kodiPkgs; [
      joystick
    ]));
in {
  options.a.services.kodi = {
    enable = lib.mkEnableOption "Enable kodi service";
    user = lib.mkOption {
      type = lib.types.str;
      description = "User to run kodi as";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
  (lib.a.makeGamescopeService {
    inherit config lib pkgs;
    service = "kodi";
    tty = "tty1";
    user = cfg.user;
    program = "${lib.getBin kodi-package}/bin/kodi-standalone";
  })
  {
    networking.nat = {
      externalInterface = "eno2";
      enable = true;
      forwardPorts = [{
          destination = "10.0.0.2:9191";
          proto = "tcp";
          sourcePort = "10.0.0.4:80";
      }];
    };
  }
  ]);
}

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

  config = lib.mkIf cfg.enable (lib.a.makeGamescopeService {
    inherit config lib pkgs;
    service = "kodi";
    tty = 1;
    user = cfg.user;
    program = "${lib.getBin kodi-package}/bin/kodi-standalone";
    #environment = {
    #  KODI_AE_SINK = "ALSA";
    #};
  });
}

{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.kodi;
  kodi-package = (pkgs.kodi-wayland.withPackages
    (kodiPkgs: with kodiPkgs; [
      joystick
      visualization-fishbmc
      visualization-goom
      visualization-matrix
      visualization-pictureit
      visualization-projectm
      visualization-shadertoy
      visualization-spectrum
      visualization-starburst
      visualization-waveform
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
    tty = "tty1";
    user = cfg.user;
    program = "${lib.getBin kodi-package}/bin/kodi-standalone";
    #environment = {
    #  KODI_AE_SINK = "ALSA";
    #};
  });
}

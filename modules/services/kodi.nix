{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.kodi;
in {
  options.a.services.kodi = {
    enable = lib.mkEnableOption "Enable kodi service";
    user = lib.mkOption {
      type = lib.types.str;
      description = "User to run kodi as";
    };
  };

  config = lib.mkIf cfg.enable {
    services.cage = {
      enable = true;
      user = cfg.user;
      extraArguments = [ "-s" ];
      program = "${lib.getBin pkgs.kodi-wayland}/bin/kodi-standalone";
      environment = {
        KODI_AE_SINK = "ALSA";
      };
    };
    systemd.services."cage-tty1" = {
      unitConfig = {
        StartLimitBurst = 6;
        StartLimitIntervalSec = 45;
      };
      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}

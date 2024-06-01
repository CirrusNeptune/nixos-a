{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.steam;
in {
  options.a.services.steam = {
    enable = lib.mkEnableOption "Enable steam service";
    user = lib.mkOption {
      type = lib.types.str;
      description = "User to run steam as";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.a.makeGamescopeService {
      inherit config lib pkgs;
      service = "steam";
      tty = "tty3";
      user = cfg.user;
      program = "${lib.getBin pkgs.bash}/bin/bash -c \"${lib.getBin pkgs.coreutils}/bin/id -u > /home/a/mowsteam.txt && ${lib.getBin pkgs.coreutils}/bin/id -u -r >> /home/a/mowsteam.txt 2>&1\"";
      args = [];
      gamescopeArguments = [ "--steam" ];
    })
    {
      programs.steam = {
        enable = true;
        gamescopeSession = {
          enable = true;
        };
      };
      programs.gamescope.capSysNice = true;
    }
  ]);
}

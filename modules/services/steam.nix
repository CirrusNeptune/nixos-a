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
      program = "${lib.getBin pkgs.steam}/bin/steam";
      args = [ "-tenfoot" "-pipewire-dmabuf" ];
      gamescopeArguments = [ "--steam" ];
    })
    {
      security.wrappers = {
        # needed or steam fails
        bwrap = {
          owner = "root";
          group = "root";
          source = "${pkgs.bubblewrap}/bin/bwrap";
          setuid = true;
        };
      };
    }
  ]);
}

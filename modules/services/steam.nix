{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.steam;
  steam-package = pkgs.steam.override (prev: {
    buildFHSEnv = pkgs.buildFHSEnv.override {
      # use the setuid wrapped bubblewrap
      bubblewrap = "${config.security.wrapperDir}/..";
    };
  });
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
      program = "${lib.getBin steam-package}/bin/steam";
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

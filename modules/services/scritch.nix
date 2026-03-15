{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.scritch;
  scritchPkg = pkgs.callPackage ../../pkgs/scritch { inherit (cfg) src; };
  debugWrapper = pkgs.writeShellScript "scritch-debug" ''
    echo "=== SCRITCH DEBUG ==="
    echo "DISPLAY=$DISPLAY"
    echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    echo "SDL_VIDEODRIVER=$SDL_VIDEODRIVER"
    echo "SDL_AUDIODRIVER=$SDL_AUDIODRIVER"
    echo "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
    echo "Noop 13"
    env | sort
    echo "=== END DEBUG ==="
    exec ${scritchPkg}/bin/scritch "$@"
  '';
in {
  options.a.services.scritch = {
    enable = lib.mkEnableOption "Enable scritch service";
    user = lib.mkOption {
      type = lib.types.str;
      description = "User to run scritch as";
    };
    src = lib.mkOption {
      type = lib.types.path;
      description = "Path to scritch source directory";
    };
  };

  config = lib.mkIf cfg.enable (lib.a.makeGamescopeService {
    inherit config lib pkgs;
    service = "scritch";
    tty = 4;
    user = cfg.user;
    program = "${debugWrapper}";
    #gamescopeArguments = [];  # kodi works with no args
    # Gamescope needs XDG_RUNTIME_DIR to create its Wayland socket.
    # pam_systemd should provide this, and does for kodi/steam, but
    # scritch fails without it when started manually via
    # `systemctl start scritch`. Root cause is unclear ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â may be
    # related to the compiled C wrapper from wrapGAppsHook3.
    # TODO: investigate why kodi/steam don't need this.
    # Note: SDL_AUDIODRIVER is set in the package wrapper (not here)
    # because Gamescope constructs its own env for children, so service
    # env vars don't reach the app process.
    environment = {
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
  });
}

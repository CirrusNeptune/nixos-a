{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.chromium-debug;
in {
  options.a.services.chromium-debug = {
    enable = lib.mkEnableOption "Enable chromium remote debugging service";
    user = lib.mkOption {
      type = lib.types.str;
      description = "User to run chromium as";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 9222;
      description = "Remote debugging port";
    };
  };

  config = lib.mkIf cfg.enable (lib.a.makeGamescopeService {
    inherit config lib pkgs;
    service = "chromium-debug";
    tty = 5;
    user = cfg.user;
    program = "${lib.getBin pkgs.chromium}/bin/chromium";
    args = [
      "--remote-debugging-address=0.0.0.0"
      "--remote-debugging-port=${toString cfg.port}"
    ];
    environment = {
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
  });
}

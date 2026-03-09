{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.syncthing;
in {
  options.a.services.syncthing = {
    enable = lib.mkEnableOption "Enable syncthing service";
    user = lib.mkOption {
      type = lib.types.str;
      default = "a";
      description = "User to run syncthing as";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/${cfg.user}";
      description = "Default data directory";
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = cfg.user;
      dataDir = cfg.dataDir;
      openDefaultPorts = true;
    };
  };
}

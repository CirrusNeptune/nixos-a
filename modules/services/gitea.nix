{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.gitea;
in {
  options.a.services.gitea = {
    enable = lib.mkEnableOption "Enable gitea service";
    host = lib.mkOption {
      type = lib.types.str;
      description = "Host to bind on";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      containers = {
        gitea = {
          volumes = [
            "/var/gitea:/data"
            "/etc/timezone:/etc/timezone:ro"
            "/etc/localtime:/etc/localtime:ro"
          ];
          image = "gitea/gitea:1.21.11";
          ports = [
            "${cfg.host}:80:3000"
          ];
          extraOptions = [
            #"--network=bridge"
          ];
          environment = {
            USER_UID = "1000";
            USER_GID = "1000";
          };
        };
      };
    };
  };
}

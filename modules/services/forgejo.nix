{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.forgejo;
in {
  options.a.services.forgejo = {
    enable = lib.mkEnableOption "Enable forgejo service";
    host = lib.mkOption {
      type = lib.types.str;
      description = "Host to bind on";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers = {
      containers = {
        forgejo = {
          volumes = [
            "/var/forgejo:/data"
            "/etc/timezone:/etc/timezone:ro"
            "/etc/localtime:/etc/localtime:ro"
          ];
          image = "codeberg.org/forgejo/forgejo:7.0.3";
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

    services.gitea-actions-runner = {
      package = pkgs.forgejo-runner;
      instances.mowbark = {
        enable = true;
        name = "ci";
        url = "http://git.mow";
        labels = [ ":docker:" ];
        token = "7efimPRH2Cxq4i5TkjA19nUTuGWujOBJXxoJEawf";
      };
    };
  };
}

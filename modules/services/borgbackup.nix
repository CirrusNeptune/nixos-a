{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.borgbackup;
in {
  options.a.services.borgbackup = {
    enable = lib.mkEnableOption "Enable borgbackup service";
  };

  config = lib.mkIf cfg.enable {
    services.borgbackup.jobs = {
      rootBackup = {
        paths = [ "/home/a" "/boot" "/var" ];
        repo = "/b/borg/backups/a";
        doInit = true;
        encryption = {
          mode = "none";
        };
        compression = "zstd";
        startAt = "weekly";
      };
    };
  };
}

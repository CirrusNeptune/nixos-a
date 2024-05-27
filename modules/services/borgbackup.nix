{ config, lib, pkgs, ... }:
let
in {
    opt.services.borgbackup.jobs = {
        rootBackup = {
          paths = "/";
          exclude = [ "/b"];
          repo = "/b/borg/backups/a";
          doInit = true;
          encryption = {
            mode = "none";
          };
          compression = "zstd";
          startAt = "weekly";
        };
    };
}
{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.event-scraper;

  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    requests
    beautifulsoup4
    python-dotenv
  ]);

  srcFiles = lib.fileset.toSource {
    root = ../../event_scraper;
    fileset = lib.fileset.fileFilter (f: f.hasExt "py") ../../event_scraper;
  };

  eventScraperImage = pkgs.dockerTools.buildImage {
    name = "localhost/event-scraper";
    tag = "latest";
    copyToRoot = pkgs.buildEnv {
      name = "event-scraper-env";
      paths = [
        pythonEnv
        srcFiles
      ];
    };
    config = {
      WorkingDir = "/";
      Cmd = [ "${pythonEnv}/bin/python3" "event_manager.py" ];
    };
  };
in {
  options.a.services.event-scraper = {
    enable = lib.mkEnableOption "Enable event-scraper service";
    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to .env file containing HA_TOKEN, HA_URL, HA_CALENDAR_ENTITY";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.event-scraper = let
      podman = "${config.virtualisation.podman.package}/bin/podman";
      image = "localhost/event-scraper:latest";
    in {
      description = "Scrape community events and publish to Home Assistant calendar";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ config.virtualisation.podman.package ];
      serviceConfig = {
        Type = "oneshot";
        ExecStartPre = "${podman} load -i ${eventScraperImage}";
        ExecStart = "${podman} run --rm --env-file ${cfg.environmentFile} -e DB_PATH=/data/events.db -v event-scraper-data:/data ${image}";
      };
    };

    systemd.timers.event-scraper = {
      description = "Run event-scraper weekly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Fri *-*-* 09:00:00";
        Persistent = true;
      };
    };
  };
}

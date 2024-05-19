{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.kwin-session;
in {
  options.a.services.kwin-session = {
    enable = lib.mkEnableOption "Enable kwin-session service";
    user = lib.mkOption {
      type = lib.types.str;
      description = "User to run kwin-session as";
    };
  };

  config = lib.mkIf cfg.enable {
    services.desktopManager.plasma6.enable = true;
    systemd.services.kwin-session = {
      description = "KWin Session";
      after = [
        "systemd-user-sessions.service"
        "plymouth-start.service"
        "plymouth-quit.service"
        "systemd-logind.service"
        "getty@tty2.service"
      ];
      before = [ "graphical.target" ];
      wants = [ "dbus.socket" "systemd-logind.service" "plymouth-quit.service"];
      wantedBy = [ "graphical.target" ];
      conflicts = [ "getty@tty2.service" ];
      unitConfig.ConditionPathExists = "/dev/tty2";
      serviceConfig = {
        Type = "simple";
        ExecStart = "${lib.getBin pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland";
        User = cfg.user;
        Group = "users";
        PAMName = "login";
        TTYPath = /dev/tty2;
        TTYReset = "yes";
        TTYVHangup = "yes";
        TTYVTDisallocate = "yes";
        StandardInput = "tty-fail";
        StandardOutput = "journal";
        StandardError = "journal";
        UtmpIdentifier = "tty2";
        UtmpMode = "user";
      };
      environment = {
        XDG_SESSION_TYPE = "wayland";
      };
    };
  };
}

{ ... }:
{ config,
  lib,
  pkgs,
  service,
  tty,
  user,
  program,
  args ? [],
  gamescopeArguments ? [],
  environment ? {},
  ...
}: {
  systemd.services."${service}" = {
    enable = true;
    after = [
      "systemd-user-sessions.service"
      "plymouth-start.service"
      "plymouth-quit.service"
      "systemd-logind.service"
      "getty@${tty}.service"
    ];
    before = [ "graphical.target" ];
    wants = [ "dbus.socket" "systemd-logind.service" "plymouth-quit.service"];
    wantedBy = [ "graphical.target" ];
    conflicts = [ "getty@${tty}.service" ];

    restartIfChanged = false;
    unitConfig = {
      ConditionPathExists = "/dev/${tty}";
      StartLimitBurst = 6;
      StartLimitIntervalSec = 45;
    };
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
      ExecStart = ''
        ${pkgs.gamescope}/bin/gamescope \
          ${lib.escapeShellArgs gamescopeArguments} \
          -- ${program} ${lib.escapeShellArgs args}
      '';
      User = user;
      Group = "users";

      IgnoreSIGPIPE = "no";

      # Log this user with utmp, letting it show up with commands 'w' and
      # 'who'. This is needed since we replace (a)getty.
      UtmpIdentifier = "%n";
      UtmpMode = "user";
      # A virtual terminal is needed.
      TTYPath = "/dev/${tty}";
      TTYReset = "yes";
      TTYVHangup = "yes";
      TTYVTDisallocate = "yes";
      # Fail to start if not controlling the virtual terminal.
      StandardInput = "tty-fail";
      StandardOutput = "journal";
      StandardError = "journal";
      # Set up a full (custom) user session for the user, required by Gamescope.
      PAMName = "${service}";
    };

    inherit environment;
  };

  security.polkit.enable = true;

  security.pam.services."${service}".text = ''
    auth    required pam_unix.so nullok
    account required pam_unix.so
    session required pam_unix.so
    session required pam_env.so conffile=/etc/pam/environment readenv=0
    session required ${config.systemd.package}/lib/security/pam_systemd.so default-capability-ambient-set=~0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63
  '';

  systemd.targets.graphical.wants = [ "${service}.service" ];
}

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
  path ? [],
  ...
}: let
  mkIntegerSeq = start: end: lib.strings.concatMapStringsSep "," toString (lib.lists.range start end);
in {
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
      #ExecStart = ''
      #  ${pkgs.gamescope}/bin/gamescope \
      #    ${lib.escapeShellArgs gamescopeArguments} \
      #    -- ${program} ${lib.escapeShellArgs args}
      #'';
      ExecStart = ''
        ${config.security.wrapperDir}/gamescope \
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

      #Capabilities = [ "CAP_SYS_NICE" ];
      #AmbientCapabilities = [ "CAP_SYS_NICE" ];
    };

    inherit environment;
    inherit path;
  };

  security.polkit.enable = true;

  # pam_systemd adds cap_wake_alarm by default, but this interferes with bwrap.
  # The only way to remove this cap is by exhausively excluding all 64 cap bits.
  security.pam.services."${service}".text = ''
    auth    required pam_unix.so nullok
    account required pam_unix.so
    session required pam_unix.so
    #session required pam_env.so conffile=/etc/pam/environment readenv=0
    session required ${config.systemd.package}/lib/security/pam_systemd.so
    #session required ${config.systemd.package}/lib/security/pam_systemd.so default-capability-ambient-set=~${mkIntegerSeq 0 63}
  '';

  systemd.targets.graphical.wants = [ "${service}.service" ];
}

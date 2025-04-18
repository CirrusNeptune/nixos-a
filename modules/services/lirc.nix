{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.lirc;

  nakawUdevRule = pkgs.writeTextFile {
    name = "nakaw-udev-rule";
    text = ''KERNEL=="lirc[0-9]*", MODE="0666"'';
    destination = "/etc/udev/rules.d/99-nakaw.rules";
  };

  makeLircService = (service: extraArgs: remoteConf: {
    systemd.sockets."${service}" = {
      description = "LIRC ${service} socket";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        # /run/lirc exposed in HA container as /lircd
        ListenStream = "/run/lirc/${service}";
        SocketUser = "lirc";
        SocketMode = "0666";
      };
    };

    systemd.services."${service}" = let
      configFile = pkgs.writeText "${service}.conf" remoteConf;
    in {
      description = "LIRC ${service} daemon";
      after = [ "network.target" ];

      unitConfig.Documentation = [ "man:lircd(8)" ];

      serviceConfig = {
        RuntimeDirectory = ["lirc" "lirc/lock"];

        # Service runtime directory and socket share same folder.
        # Following hacks are necessary to get everything right:

        # 1. prevent socket deletion during stop and restart
        RuntimeDirectoryPreserve = true;

        # 2. fix runtime folder owner-ship, happens when socket activation
        #    creates the folder
        PermissionsStartOnly = true;
        ExecStartPre = [
          "${pkgs.coreutils}/bin/chown lirc /run/lirc/"
        ];

        ExecStart = ''
          ${pkgs.lirc}/bin/lircd --nodaemon \
            --output=/run/lirc/${service} \
            ${lib.escapeShellArgs extraArgs} \
            ${configFile}
        '';
        User = "lirc";
      };
    };
  });

  codes = ''
    begin codes
      Power      0xFF11807F
      Mute      0xFF11A05F
      TV      0xFF1140BF
      HDMI2      0xFF114CB3
      HDMI3      0xFF11CC33
      HDMI4      0xFF112CD3
      Opt      0xFF11AC53
      Coax      0xFF116C93
      Bt      0xFF11EC13
      Aux      0xFF111CE3
      USB      0xFF11A25D
      Music      0xFF11C43B
      Movie      0xFF1104FB
      Game      0xFF11847B
      Night      0xFF11A45B
      NoDSP      0xFF1106F9
      AllChStereo      0xFF111AE5
      Surround      0xFF119A65
      Setup      0xFF1126D9
      InfoStop      0xFF118679
      Return      0xFF1146B9
      SsePlus      0xFF1112ED
      SseMinus      0xFF11926D
      Left      0xFF110AF5
      Right      0xFF118A75
      Enter      0xFF11E21D
      BassPlus      0xFF1108F7
      BassMinus      0xFF119C63
      VolPlus      0xFF1120DF
      VolMinus      0xFF11C03F
      CenterPlus      0xFF1128D7
      CenterMinus      0xFF1102FD
      TreblePlus      0xFF11A857
      TrebleMinus      0xFF1122DD
      SurroundSidePlus      0xFF118877
      SurroundSideMinus      0xFF11827D
      SurroundBackPlus      0xFF1142BD
      SurroundBackMinus      0xFF11C23D
      SystemMemory1      0xFF11AA55
      SystemMemory2      0xFF116A95
      SystemMemory3      0xFF110EF1
      BtPlayPause      0xFF11629D
      BtStop      0xFF11A659
      BtPrevTrack      0xFF11649B
      BtNextTrack      0xFF11E41B
    end codes
  '';
in {
  options.a.services.lirc = {
    enable = lib.mkEnableOption "Enable lirc service";
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [{
    services.udev.packages = [ nakawUdevRule ];

    # Note: LIRC executables raises a warning, if lirc_options.conf do not exists
    environment.etc."lirc/lirc_options.conf".text = ''
      [lircd]
      nodaemon = False
    '';

    users.users.lirc = {
      uid = config.ids.uids.lirc;
      group = "lirc";
      description = "LIRC user for lircd";
    };

    users.groups.lirc.gid = config.ids.gids.lirc;
  } (makeLircService "lircd-nakaw"
    [ "--device=/dev/lirc0" ]
    ''
      begin remote
        name  nakaw
        bits           32
        flags SPACE_ENC|CONST_LENGTH
        eps            30
        aeps          100

        header        9000 4500
        one           563  1687
        zero          563   562
        ptrail        563
        gap          108000

        frequency    38000
        duty_cycle   33

        ${codes}
      end remote
    '')]);
}

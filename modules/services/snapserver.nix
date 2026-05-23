{
  config,
  lib,
  pkgs,
  ...
}:
let

  name = "snapserver";

  inherit (lib)
    literalExpression
    mkEnableOption
    mkOption
    mkPackageOption
    mkRemovedOptionModule
    mkRenamedOptionModule
    types
    ;

  cfg = config.a.services.snapserver;

  format = pkgs.formats.ini {
    listsAsDuplicateKeys = true;
  };

  configFile = format.generate "snapserver.conf" cfg.settings;

in
{
  imports = [
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "controlPort" ]
      [ "a" "services" "snapserver" "tcp" "port" ]
    )

    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "listenAddress" ]
      [ "a" "services" "snapserver" "settings" "stream" "bind_to_address" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "port" ]
      [ "a" "services" "snapserver" "settings" "stream" "port" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "sampleFormat" ]
      [ "a" "services" "snapserver" "settings" "stream" "sampleformat" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "codec" ]
      [ "a" "services" "snapserver" "settings" "stream" "codec" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "streamBuffer" ]
      [ "a" "services" "snapserver" "settings" "stream" "chunk_ms" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "buffer" ]
      [ "a" "services" "snapserver" "settings" "stream" "buffer" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "send" ]
      [ "a" "services" "snapserver" "settings" "stream" "chunk_ms" ]
    )

    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "tcp" "enable" ]
      [ "a" "services" "snapserver" "settings" "tcp" "enabled" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "tcp" "listenAddress" ]
      [ "a" "services" "snapserver" "settings" "tcp" "bind_to_address" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "tcp" "port" ]
      [ "a" "services" "snapserver" "settings" "tcp" "port" ]
    )

    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "http" "enable" ]
      [ "a" "services" "snapserver" "settings" "http" "enabled" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "http" "listenAddress" ]
      [ "a" "services" "snapserver" "settings" "http" "bind_to_address" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "http" "port" ]
      [ "a" "services" "snapserver" "settings" "http" "port" ]
    )
    (mkRenamedOptionModule
      [ "a" "services" "snapserver" "http" "docRoot" ]
      [ "a" "services" "snapserver" "settings" "http" "doc_root" ]
    )

    (mkRemovedOptionModule [
      "a"
      "services"
      "snapserver"
      "streams"
    ] "Configure `a.services.snapserver.settings.stream.source` instead")
  ];

  ###### interface

  options = {

    a.services.snapserver = {

      enable = mkEnableOption "snapserver";

      package = mkPackageOption pkgs "snapcast" { };

      settings = mkOption {
        default = { };
        description = ''
          Snapserver configuration.

          Refer to the [example configuration](https://github.com/badaix/snapcast/blob/develop/server/etc/snapserver.conf) for possible options.
        '';
        type = types.submodule {
          freeformType = format.type;
          options = {
            stream = {
              bind_to_address = mkOption {
                default = "::";
                description = ''
                  Address to listen on for snapclient connections.
                '';
              };

              port = mkOption {
                type = types.port;
                default = 1704;
                description = ''
                  Port to listen on for snapclient connections.
                '';
              };

              source = mkOption {
                type = with types; either str (listOf str);
                example = "pipe:///tmp/snapfifo?name=default";
                description = ''
                  One or multiple URIs to PCM inpuit streams.
                '';
              };
            };

            tcp = {
              enabled = mkEnableOption "the TCP JSON-RPC";

              bind_to_address = mkOption {
                default = "::";
                description = ''
                  Address to listen on for snapclient connections.
                '';
              };

              port = mkOption {
                type = types.port;
                default = 1705;
                description = ''
                  Port to listen on for snapclient connections.
                '';
              };
            };

            http = {
              enabled = mkEnableOption "the HTTP JSON-RPC";

              bind_to_address = mkOption {
                default = "::";
                description = ''
                  Address to listen on for snapclient connections.
                '';
              };

              port = mkOption {
                type = types.port;
                default = 1780;
                description = ''
                  Port to listen on for snapclient connections.
                '';
              };

              doc_root = lib.mkOption {
                type = with lib.types; nullOr path;
                default = pkgs.snapweb;
                defaultText = literalExpression "pkgs.snapweb";
                description = ''
                  Path to serve from the HTTP servers root.
                '';
              };
            };
          };
        };
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to automatically open the specified ports in the firewall.
        '';
      };
    };
  };

  ###### implementation

  config = lib.mkIf cfg.enable {
    environment.etc."snapserver.conf".source = configFile;

    systemd.user.services.snapserver = {
      after = [
        "network.target"
        "nss-lookup.target"
        "wireplumber.service"
      ];
      wantedBy = [ "wireplumber.service" ];
      description = "Snapserver";
      restartTriggers = [ configFile ];
      serviceConfig = {
        ExecStart = toString [
          (lib.getExe' cfg.package "snapserver")
          "--daemon"
        ];
        Type = "forking";
        LimitRTPRIO = 50;
        LimitRTTIME = "infinity";
        NoNewPrivileges = true;
        PIDFile = "/run/${name}/pid";
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        Restart = "on-failure";
        RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX AF_NETLINK";
        RestrictNamespaces = true;
        RuntimeDirectory = name;
        StateDirectory = name;
      };
    };

    networking.firewall.allowedTCPPorts =
      lib.optionals cfg.openFirewall [ cfg.settings.stream.port ]
      ++ lib.optional (cfg.openFirewall && cfg.settings.tcp.enabled) cfg.settings.tcp.port
      ++ lib.optional (cfg.openFirewall && cfg.settings.http.enabled) cfg.settings.http.port;
  };

  meta = {
    maintainers = with lib.maintainers; [ tobim ];
  };

}

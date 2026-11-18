{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.a.extensions.wireplumber-a;
in {
  options.a.extensions.wireplumber-a = {
    enable = mkEnableOption "Enable wireplumber-a extension";
  };

  config = mkIf cfg.enable {
    services.pipewire.extraConfig = {
      client."101-kodi" = {
        "stream.rules" = [
          {
            matches = [
              {
                "application.name" = "Kodi";
              }
            ];
            actions = {
              update-props = {
                "node.target" = "kodi_combine";
              };
            };
          }
        ];
      };
      pipewire."100-kodi-combine" = {
        "context.modules" = [
          {
            name = "libpipewire-module-combine-stream";
            args = {
              "combine.mode" = "sink";
              "node.name" = "kodi_combine";
              "node.description" = "Kodi Combine";
              "combine.latency-compensate" = false;
              "combine.props" = {
                "audio.position" = [ "FL" "FR" "RL" "RR" "FC" "LFE" "SL" "SR" ];
              };
              "stream.props" = {};
              "stream.rules" = [
                {
                  matches = [
                    {
                      "node.name" = "alsa_output.pci-0000_03_00.1.hdmi-surround71-extra3";
                      "media.class" = "Audio/Sink";
                    }
                    {
                      "node.name" = "Kodi Mirror";
                      "media.class" = "Audio/Sink";
                    }
                  ];
                  actions = {
                    create-stream = {};
                  };
                }
              ];
            };
          }
        ];
      };
    };
    services.pipewire.wireplumber = {
      extraConfig."wireplumber-a" = {
        "context.properties" = {
          # Output Debug log messages as opposed to only the default level (Notice)
          #"log.level" = "D";
        };
        "wireplumber.components" = [
          {
            name = "linking/rescan-mowbark-snapcast.lua";
            type = "script/lua";
            provides = "hooks.linking.rescan-mowbark-snapcast";
          }
        ];
        "wireplumber.profiles" = {
          main = {
            "hooks.linking.rescan-mowbark-snapcast" = "required";
          };
        };
      };
      extraScripts = {
        "linking/rescan-mowbark-snapcast.lua" = (builtins.readFile ./rescan-mowbark-snapcast.lua);
      };
    };
  };
}

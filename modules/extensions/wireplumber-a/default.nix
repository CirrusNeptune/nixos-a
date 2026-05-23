{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.a.extensions.wireplumber-a;
in {
  options.a.extensions.wireplumber-a = {
    enable = mkEnableOption "Enable wireplumber-a extension";
  };

  config = mkIf cfg.enable {
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

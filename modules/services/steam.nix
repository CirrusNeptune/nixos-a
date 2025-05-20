{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.steam;
in {
  options.a.services.steam = {
    enable = lib.mkEnableOption "Enable steam service";
    user = lib.mkOption {
      type = lib.types.str;
      description = "User to run steam as";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.a.makeGamescopeService {
      inherit config lib pkgs;
      service = "steam";
      tty = "tty2";
      user = cfg.user;
      #user = "root";
      #program = "/run/current-system/sw/bin/runuser";
      #args = [ "-u" cfg.user "--" "${lib.getBin pkgs.steam}/bin/steam" "-tenfoot" "-pipewire-dmabuf" ];
      program = "/run/current-system/sw/bin/steam";
      args = [ "-tenfoot" "-pipewire-dmabuf" ];
      gamescopeArguments = [
        "--steam"
        "--rt"
        #"--mangoapp"
        "--hdr-enabled"
      ];
      #program = "/run/current-system/sw/bin/bash";
      #args = [ "-c" "cat /proc/self/status" ];
      environment = {
        #MANGOHUD = "1";
        #MANGOHUD_CONFIG = "cpu_temp,gpu_temp,ram,vram";
      };
      path = [ pkgs.mangohud ];
    })
    {
      programs.steam = {
        enable = true;
        gamescopeSession = {
          enable = true;
        };
        extraCompatPackages = [ pkgs.proton-custom pkgs.proton-ge-bin ];
      };
      programs.gamescope.capSysNice = true;
      programs.gamemode = {
        enable = true;
        settings = {
          general = {
            renice = 10;
          };
        };
      };
      #security.wrappers.gamescope.capabilities = lib.mkForce "cap_sys_nice+p";
    }
  ]);
}

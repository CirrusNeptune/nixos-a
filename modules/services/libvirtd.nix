{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.libvirtd;
in {
  options.a.services.libvirtd = {
    enable = lib.mkEnableOption "Enable libvirtd virtualisation";
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Users to add to the libvirtd group";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;

    users.users = lib.genAttrs cfg.users (user: {
      extraGroups = [ "libvirtd" ];
    });

    environment.systemPackages = [ pkgs.virt-manager ];
  };
}

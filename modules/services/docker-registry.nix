{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.docker-registry;
in {
  options.a.services.docker-registry = {
    enable = lib.mkEnableOption "Enable Docker registry service";
  };

  config = lib.mkIf cfg.enable {
    services.dockerRegistry = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = 5000;
      enableDelete = true;
      enableGarbageCollect = true;
    };
  };
}

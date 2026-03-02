{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.ollama;
in {
  options.a.services.ollama = {
    enable = lib.mkEnableOption "Enable ollama service";
  };

  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      acceleration = "rocm";
      host = "0.0.0.0";
    };
  };
}

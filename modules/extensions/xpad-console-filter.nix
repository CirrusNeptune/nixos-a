{ config, lib, pkgs, ... }:
let
  cfg = config.a.extensions.xpad-console-filter;
in {
  options.a.extensions.xpad-console-filter = {
    enable = lib.mkEnableOption "Enable xpad console filter extension";
  };

  config = lib.mkIf cfg.enable {
    boot.kernelPatches = [{
      name = "xpad console filter";
      patch = ./xpad-console-filter.patch;
    }];
  };
}

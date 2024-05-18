{ lib, pkgs, ... }:
let
  mowbark-rf = pkgs.callPackage ./Cargo.nix { inherit pkgs; };
in lib.trace mowbark-rf {}
#{
  #systemd.services.mowbark-rf = {
  #  description = "Mowbark RF";
  #  wantedBy = [ "podman-homeassistant.service" ];
  #  serviceConfig = {
  #    Type = "simple";
  #    ExecStart = "${lib.getBin mowbark-rf}/bin/nexus-revo-io";
  #  };
  #};
#}

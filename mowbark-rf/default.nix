{ lib, pkgs, fetchFromGithub, symlinkJoin, rustPlatform, ... }:
let
  #crate2nixTools = lib.crate2nix.tools { inherit lib pkgs; };
  #mowbark-rf = pkgs.callPackage ./Cargo.nix { inherit pkgs; };
in {}
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

{ lib, pkgs, ... }:
#let
#  mowbark-rf = pkgs.callPackage ./Cargo.nix { inherit pkgs; };
#in
{
  mowbark-rf = import ./Cargo.nix { inherit pkgs; };
}
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

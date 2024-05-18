{ lib, pkgs, ... }:
let
  crate2nix_tools = lib.crate2nix.tools { inherit lib pkgs; };
  #mowbark-rf = pkgs.callPackage ./Cargo.nix { inherit pkgs; };
in
{
  #mowbark-rf = import ./Cargo.nix { inherit pkgs; };
  blah = lib.trace crate2nix_tools {};
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

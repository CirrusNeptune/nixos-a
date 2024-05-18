{ lib, pkgs, fetchFromGithub, symlinkJoin, rustPlatform, ... }:
let
  #crate2nixTools = lib.crate2nix.tools { inherit lib pkgs; };
  #mowbark-rf = pkgs.callPackage ./Cargo.nix { inherit pkgs; };
in rustPlatform.buildRustPackage {
  pname = "mowbark-rf";
  version = "0.0.1";

  src = fetchFromGithub {
    owner = "CirrusNeptune";
    repo = "nexus-revo-io";
    rev = "0feaa6052d3429c6ddfc1727bd157d5bbc8aa731";
  };
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

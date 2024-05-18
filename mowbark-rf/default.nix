{ lib, pkgs, ... }:
let
  crate2nixTools = lib.crate2nix.tools { inherit lib pkgs; };
  #mowbark-rf = pkgs.callPackage ./Cargo.nix { inherit pkgs; };
in
rec {
  mowbark-rf = crate2nixTools.appliedCargoNix {
    name = "mowbark-rf";
    src = ./.;
  };
  blah = lib.trace mowbark-rf {};
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

{ lib, pkgs, symlinkJoin, ... }:
let
  src = pkgs.symlinkJoin {
    name = "mowbark-rf-workspace";
    paths = [
      lib.fetchFromGithub {
        owner = "CirrusNeptune";
        repo = "libftd2xx-cc1101";
        rev = "3ba5aaa4bda7af31a31850eb0ec6d5101b593f34";
      }
      lib.fetchFromGithub {
        owner = "CirrusNeptune";
        repo = "nexus-revo-io";
        rev = "0feaa6052d3429c6ddfc1727bd157d5bbc8aa731";
      }
    ];
  };
  #crate2nixTools = lib.crate2nix.tools { inherit lib pkgs; };
  #mowbark-rf = pkgs.callPackage ./Cargo.nix { inherit pkgs; };
in
rec {
  #mowbark-rf = crate2nixTools.appliedCargoNix {
  #  name = "mowbark-rf";
  #  src = ./.;
  #};
  blah = lib.trace src {};
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

{ lib }:

let
  callLibs = file: import file { inherit lib; };
in {
  macvlan = callLibs ./macvlan.nix;
}

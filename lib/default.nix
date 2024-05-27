{ lib }:
let
  callLibs = file: import file { inherit lib; };
in {
  mkCageService = callLibs ./mkCageService.nix;
}

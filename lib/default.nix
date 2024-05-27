{ lib }:
let
  callLibs = file: import file { inherit lib; };
in {
  makeCageService = callLibs ./make-cage-service.nix;
  makeGamescopeService = callLibs ./make-gamescope-service.nix;
}

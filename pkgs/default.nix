pkgs: with pkgs; {
  mowbark-rf = callPackage ./mowbark-rf {};
  dockerToolsLocal = callPackage ./docker {};
}

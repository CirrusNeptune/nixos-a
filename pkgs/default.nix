pkgs: with pkgs; {
  mowbark-rf = callPackage ./mowbark-rf {};
  dockerToolsLocal = callPackage ./docker {
    writePython3 = buildPackages.writers.writePython3;
  } // { __attrsFailEvaluation = true; };
}

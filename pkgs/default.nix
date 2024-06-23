pkgs: with pkgs; {
  mowbark-rf = callPackage ./mowbark-rf {};
  bluez = callPackage ./bluez.nix {};
}

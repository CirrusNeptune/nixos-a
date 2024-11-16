pkgs: with pkgs; {
  mowbark-rf = callPackage ./mowbark-rf {};
  bluez = callPackage ./bluez.nix {};
  refresh-profile = callPackage ./refresh-profile.nix {};
}

# Native library dependencies for the itch.io game browser.
# GTK/WebKit libs are added to nix-ld via jetbrains-ld.nix.
# GI_TYPELIB_PATH is set globally for GObject introspection (pywebview).
{ config, lib, pkgs, ... }:
let
  cfg = config.a.services.itchiodevtest;
in {
  options.a.services.itchiodevtest = {
    enable = lib.mkEnableOption "Enable itch.io game browser dependencies";
    wine.enable = lib.mkEnableOption "Include wine for Windows game compatibility";
  };

  config = lib.mkIf cfg.enable {
    environment.sessionVariables.GI_TYPELIB_PATH = lib.makeSearchPath "lib/girepository-1.0" (with pkgs; [
      gtk3
      webkitgtk_4_1
      gobject-introspection
      glib
      pango
      gdk-pixbuf
      atk
      harfbuzz
    ]);

    environment.systemPackages = lib.optionals cfg.wine.enable [
      pkgs.wine
    ];
  };
}

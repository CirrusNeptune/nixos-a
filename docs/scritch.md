# Scritch (itch.io Big Picture)

Scritch is a controller-friendly itch.io client built with Pygame-CE. It runs as its own Gamescope session on TTY4, alongside Kodi (TTY1), Steam (TTY2), and KWin (TTY3).

## Architecture

```
modules/services/scritch.nix   NixOS module (service + options)
pkgs/scritch/default.nix       Nix package (Python env + wrapper)
lib/make-gamescope-service.nix  Shared Gamescope service factory
```

The module uses `makeGamescopeService` to create a systemd service that:
- Owns TTY4 exclusively (conflicts with getty)
- Runs Scritch inside Gamescope (Wayland compositor)
- Launches fullscreen at native resolution (renders internally at 1920x1080)

## Configuration

In `configuration.nix`:
```nix
a.services.scritch = {
  enable = true;
  user = "a";
  src = /b/multimedia/scritch; # path to scritch source on the NixOS machine
};
```

`src` is a path to the Scritch source checkout. It gets copied into the nix store on rebuild, so source changes require a `nixos-rebuild`.

## Python Dependencies

The package creates a Python 3.13 environment with all dependencies. Most come from nixpkgs; these are built custom:

| Package | Approach | Notes |
|---------|----------|-------|
| pygame-ce | Source build (meson-python) | Needs SDL2, SDL2_image, SDL2_mixer, SDL2_ttf |
| curl_cffi | Manylinux wheel | Bundles curl-impersonate; too complex to build from source |
| segno | Source build | Pure Python |
| pywebview | Source build | Uses PyGObject + WebKit2GTK at runtime |
| mcp | Source build | Model Context Protocol SDK |
| wyoming | Source build | Voice assistant protocol |

## How To Build (First Time)

The package uses `lib.fakeHash` placeholders. You need to fill in real hashes iteratively:

1. Run `nixos-rebuild build` — it will fail on the first package with a hash mismatch
2. Copy the `got: sha256-...` hash from the error into the corresponding `hash = ` field in `pkgs/scritch/default.nix`
3. Repeat until all hashes are filled in

For `curl_cffi` specifically:
1. Go to https://pypi.org/project/curl-cffi/#files
2. Find the `cp313-cp313-manylinux_2_17_x86_64.manylinux2014_x86_64.whl` file
3. Copy its download URL into the `fetchurl.url` field (replace `TODO_FILL_IN_PATH`)
4. Build to get the hash

## Troubleshooting

### pygame-ce fails to build
The meson-python source build needs SDL2 headers via pkg-config. If it can't find them, try switching to a wheel approach like curl_cffi (fetch the manylinux wheel + `autoPatchelfHook`).

### Missing Python packages at runtime
If `mcp` or another package has sub-dependencies not in nixpkgs (e.g. `sse-starlette`, `pydantic-settings`), add a `buildPythonPackage` definition in `pkgs/scritch/default.nix` following the same pattern as `segno`.

### GObject/WebKit typelib errors (pywebview)
The package uses `wrapGAppsHook3` to set `GI_TYPELIB_PATH` automatically. If pywebview still can't find typelibs, check that `gtk3`, `webkitgtk_4_1`, and `gobject-introspection` are in `buildInputs`.

### HTML5 games (webview subprocess)
When running from source, `core/html_server.py` finds `webview_main.py` relative to the project root via `__file__`. This works because the full source tree is copied to `$out/share/scritch/`.

### No display / Gamescope errors
Verify TTY4 exists: `ls /dev/tty4`. Check service logs: `journalctl -u scritch`.

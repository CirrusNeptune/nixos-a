{ lib
, stdenv
, python313
, python313Packages
, fetchPypi
, fetchurl
, autoPatchelfHook
, makeWrapper
, wrapGAppsHook3
, pkg-config
# GObject Introspection / GTK / WebKit
, gobject-introspection
, gtk3
, glib
, webkitgtk_4_1
, gdk-pixbuf
, pango
, atk
, harfbuzz
, libsoup_3
, cairo
# Wine / Proton
, umu-launcher
, wine
# SDL2 (for pygame-ce)
, SDL2
, SDL2_image
, SDL2_mixer
, SDL2_ttf
# Audio
, portaudio
, pipewire
# Graphics (libgbm for WebKit2GTK)
, mesa
# X11 client libs (needed by pygame-ce's bundled SDL2 to render via Xwayland)
, xorg
# Source
, src
}:

let
  pyPkgs = python313Packages;

  # ---- Custom Python packages not in nixpkgs ----

  # pygame Community Edition — SDL2-based game framework.
  # Uses meson-python build system.  If the source build gives trouble,
  # fall back to a manylinux wheel + autoPatchelfHook.
  # pygame-ce wheels bundle SDL2 libraries. autoPatchelfHook fixes the rpaths.
  pygame-ce = pyPkgs.buildPythonPackage rec {
    pname = "pygame-ce";
    version = "2.5.7";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/fe/96/e400d3a2c6456e3a334d9fae1f8704d964027b60064935278028dd79293f/pygame_ce-2.5.7-cp313-cp313-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
      hash = "sha256-SOmk7OQ7CK3I/7C7vg/hg+70u1AafTFVKuc5hZLsCoI=";
    };
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib SDL2 SDL2_image SDL2_mixer SDL2_ttf ];
    doCheck = false;
  };

  # curl_cffi bundles curl-impersonate (patched curl for TLS fingerprinting).
  # Building from source is impractical — use the manylinux wheel.
  # Get the exact wheel URL from https://pypi.org/project/curl-cffi/#files
  # Pick: curl_cffi-VERSION-cp313-cp313-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
  curl-cffi = pyPkgs.buildPythonPackage rec {
    pname = "curl_cffi";
    version = "0.14.0";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/7c/d2/ce907c9b37b5caf76ac08db40cc4ce3d9f94c5500db68a195af3513eacbc/curl_cffi-0.14.0-cp39-abi3-manylinux_2_26_x86_64.manylinux_2_28_x86_64.whl";
      hash = "sha256-Bg/iyZxB08t/iU3jGN30sDAbCNynBFPXab1OdLNrhIM=";
    };
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];
    dependencies = with pyPkgs; [ cffi certifi ];
    doCheck = false;
  };

  # segno — pure Python QR code generator
  segno = pyPkgs.buildPythonPackage rec {
    pname = "segno";
    version = "1.6.1";
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-8j2niwWSUcNuIQ0M9b+xqewWBK5unz1C+afBbTBthH4=";
    };
    pyproject = true;
    build-system = with pyPkgs; [ flit-core ];
    doCheck = false;
  };

  # proxy-tools — dependency of pywebview
  proxy-tools = pyPkgs.buildPythonPackage rec {
    pname = "proxy-tools";
    version = "0.1.0";
    src = fetchPypi {
      pname = "proxy_tools";
      inherit version;
      hash = "sha256-zLN1H1KcBH4tilhEDYayBTA88P6BRveE0cvNlPCigBA=";
    };
    pyproject = true;
    build-system = with pyPkgs; [ setuptools ];
    doCheck = false;
  };

  # pywebview — lightweight cross-platform webview wrapper
  # On Linux uses PyGObject + WebKit2GTK (provided via GI_TYPELIB_PATH)
  pywebview = pyPkgs.buildPythonPackage rec {
    pname = "pywebview";
    version = "5.3.2";
    src = fetchPypi {
      inherit pname version;
      hash = "sha256-d7iKY+ZeEpE9JpIF6cbTV2ZtSGSCZ0nHOL9DK9OtI9k=";
    };
    pyproject = true;
    build-system = with pyPkgs; [ setuptools setuptools-scm ];
    dependencies = with pyPkgs; [ pygobject3 bottle proxy-tools ];
    doCheck = false;
  };

  # mcp — Model Context Protocol SDK
  mcp = pyPkgs.buildPythonPackage rec {
    pname = "mcp";
    version = "1.8.0";
    format = "wheel";
    src = fetchPypi {
      inherit pname version;
      format = "wheel";
      dist = "py3";
      python = "py3";
      hash = "sha256-iJ2dO08St9pZ56OTOgrK2uH85Ji/zSIN77WQqikaEzQ=";
    };
    dependencies = with pyPkgs; [
      pydantic
      pydantic-settings
      httpx
      anyio
      starlette
      uvicorn
      sse-starlette
    ];
    doCheck = false;
  };

  # wyoming — voice assistant protocol (STT/TTS transport)
  wyoming = pyPkgs.buildPythonPackage rec {
    pname = "wyoming";
    version = "1.8.0";
    format = "wheel";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/70/b3/8fbcbd8b6587cb33a7deafc5f20a1ec96ee40e8f7a9c2eccc1982a4e0f06/wyoming-1.8.0-py3-none-any.whl";
      hash = "sha256-G72fsq8fzH3I05eCFDj/iRc9Ku0z8QksYqrgs85tFo0=";
    };
    doCheck = false;
  };

  # ---- Combined Python environment ----

  pythonEnv = python313.withPackages (ps: with ps; [
    # In nixpkgs
    requests
    pillow
    beautifulsoup4
    platformdirs
    psutil
    pygobject3
    websocket-client
    uvicorn
    sounddevice
    evdev
    setproctitle
    cffi
    # Custom (defined above)
    pygame-ce
    curl-cffi
    segno
    pywebview
    mcp
    wyoming
  ]);

in stdenv.mkDerivation {
  pname = "scritch";
  version = "0.1.0";
  inherit src;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ makeWrapper wrapGAppsHook3 gobject-introspection pkg-config ];
  buildInputs = [
    gtk3 webkitgtk_4_1 glib gdk-pixbuf
    pango atk harfbuzz libsoup_3 cairo
  ];

  # Prevent wrapGAppsHook3 from creating its own compiled C wrapper (which
  # uses execve() and drops DISPLAY that Gamescope sets for children).
  # Instead we consume gappsWrapperArgs in postFixup via makeWrapper (shell script).
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/scritch
    cp -r ${src}/. $out/share/scritch/

    runHook postInstall
  '';

  # wrapGAppsHook3 populates gappsWrapperArgs during fixup with the correct
  # GI_TYPELIB_PATH, XDG_DATA_DIRS, etc. by scanning buildInputs.
  # We use a shell makeWrapper (not the compiled C wrapper) so that env vars
  # set by Gamescope (like DISPLAY) are inherited by the child process.
  postFixup = ''
    makeWrapper ${pythonEnv}/bin/python $out/bin/scritch \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "$out/share/scritch/main.py" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [
        portaudio pipewire mesa
        xorg.libX11 xorg.libXext xorg.libXcursor xorg.libXinerama
        xorg.libXi xorg.libXrandr xorg.libXxf86vm xorg.libXfixes
        xorg.libXrender xorg.libXScrnSaver
      ]}" \
      --prefix PATH : "${lib.makeBinPath [ umu-launcher wine ]}" \
      --set SDL_AUDIODRIVER pipewire
  '';
}

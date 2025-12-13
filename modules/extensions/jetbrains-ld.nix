{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.a.extensions.jetbrains-ld;
  userOpts = { name, config, ... }: {
    options = {
      devPackages = mkOption {
        type = types.listOf types.package;
        default = [];
        example = literalExpression "[ pkgs.firefox pkgs.thunderbird ]";
        description = ''
          The set of packages that should be made available to the user.
          This is in contrast to {option}`environment.systemPackages`,
          which adds packages to all users.
        '';
      };
      environment = mkOption {
        type = types.attrsOf types.str;
        default = {};
      };
      packages = mkOption {
        type = types.listOf types.package;
        default = [];
        example = literalExpression "[ pkgs.firefox pkgs.thunderbird ]";
        description = ''
          The set of packages that should be made available to the user.
          This is in contrast to {option}`environment.systemPackages`,
          which adds packages to all users.
        '';
      };
    };
  };
in {
  options.a.extensions.jetbrains-ld = {
    enable = mkEnableOption "Enable jetbrains-ld extension";
    users = mkOption {
      default = {};
      type = with types; attrsOf (submodule userOpts);
      description = "Dev users to create with their packages";
    };
  };

  config = mkIf cfg.enable {
    programs.nix-ld.enable = true;
    programs.nix-ld.package = pkgs.nix-ld;
    # Runtime libraries required by IDE server
    programs.nix-ld.libraries = with pkgs; [
      SDL
      SDL2
      SDL2_image
      SDL2_mixer
      SDL2_ttf
      SDL_image
      SDL_mixer
      SDL_ttf
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      bzip2
      cairo
      cups
      curlWithGnuTls
      dbus
      dbus-glib
      desktop-file-utils
      e2fsprogs
      expat
      flac
      fontconfig
      freeglut
      freetype
      fribidi
      fuse
      fuse3
      gdk-pixbuf
      glew110
      glib
      gmp
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-ugly
      gst_all_1.gstreamer
      gtk2
      harfbuzz
      icu
      keyutils.lib
      libGL
      libGLU
      libappindicator-gtk2
      libcaca
      libcanberra
      libcap
      libclang.lib
      libdbusmenu
      libdrm
      libgcrypt
      libgpg-error
      libidn
      libjack2
      libjpeg
      libmikmod
      libogg
      libpng12
      libpulseaudio
      librsvg
      libsamplerate
      libthai
      libtheora
      libtiff
      libudev0-shim
      libusb1
      libuuid
      libvdpau
      libvorbis
      libvpx
      libxcrypt-legacy
      libxkbcommon
      libxml2
      mesa
      nspr
      nss
      openssl
      p11-kit
      pango
      pcre2
      pixman
      python3
      speex
      stdenv.cc.cc
      tbb
      udev
      vulkan-loader
      wayland
      xorg.libICE
      xorg.libSM
      xorg.libX11
      xorg.libXScrnSaver
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXft
      xorg.libXi
      xorg.libXinerama
      xorg.libXmu
      xorg.libXrandr
      xorg.libXrender
      xorg.libXt
      xorg.libXtst
      xorg.libXxf86vm
      xorg.libpciaccess
      xorg.libxcb
      xorg.xcbutil
      xorg.xcbutilimage
      xorg.xcbutilkeysyms
      xorg.xcbutilrenderutil
      xorg.xcbutilwm
      xorg.xkeyboardconfig
      xz
      zlib
      systemd
      libselinux
    ];

    users.users = mapAttrs (name: user: {
      hashedPassword = "$y$j9T$4OwHrG/9t08OLgF.l0pqj0$JJu2hTsddDPF4o12pZUWi0zSap8eStNvymaYt9Ss272";
      isNormalUser = true;
    }) cfg.users;

    system.activationScripts = mapAttrs' (name: user: nameValuePair "build-dev-profile-${name}" {
      text = let
        userCfg = config.users.users.${name};
        userName = userCfg.name;
        groupName = userCfg.group;
        homeDir = userCfg.home;
        unwrappedCC = pkgs.stdenv.cc.cc;
        hostPlatformConfig = pkgs.stdenv.hostPlatform.config;
        shell = pkgs.mkShell {
          name = "${name}-shell";
          packages = [ pkgs.stdenv.cc.libc_dev ] ++ user.packages ++ user.devPackages;
          inputsFrom = user.devPackages;
          # Bash script ran during derivation build with all dev packages in the environment.
          # Manipulate environment as necessary before final `export`.
          buildPhase = ''
            { unset PWD;
              unset OLDPWD;
              unset HOME;
              unset TEMP;
              unset TEMPDIR;
              unset TMP;
              unset TMPDIR;
              unset NIX_ENFORCE_PURITY;
              unset SSL_CERT_FILE;
              unset NIX_SSL_CERT_FILE;
              export BINDGEN_EXTRA_CLANG_ARGS="-idirafter ${unwrappedCC}/lib/gcc/${hostPlatformConfig}/${unwrappedCC.version}/include $NIX_CFLAGS_COMPILE";
              export SHELL=/run/current-system/sw/bin/bash;
              ${concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${escapeShellArg n}=${escapeShellArg v}") user.environment)}
              export PATH=${pkgs.bashInteractive}/bin:$PATH:/run/current-system/sw/bin;
              export;
            } >> "$out"
          '';
        };
      in ''
        echo setting up dev profile for ${userName} in ${homeDir}
        ${pkgs.coreutils}/bin/install --mode=0644 --owner=${userName} --group=${groupName} ${shell} ${homeDir}/.bash_profile
      '';
    }) cfg.users;
  };
}

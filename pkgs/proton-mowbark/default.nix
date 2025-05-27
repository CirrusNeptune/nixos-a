{ stdenvNoCC,
  fetchFromGitHub,
  dockerTools,
  mount,
  gnumake,
  bash,
  lib,
  rustPlatform,
  fetchgit,
  fetchurl,
  fetchzip,
  replaceVars,
  zip,
  unzip,
  undocker,
  ...
}: stdenvNoCC.mkDerivation (finalAttrs:
let
  finalPackageName = finalAttrs.finalPackage.name;

  inherit (builtins) map;
  inherit (lib) mapAttrs mapAttrsToList concatStringsSep;

  # Expand patch vars with zip paths.
  patchZipRefs = patch: zips: (replaceVars patch (mapAttrs (name: value: "/build/source/${value.name}") zips));

  # Fetch, unzip, patch, rezip dependency with paths to transitive dependencies.
  makeZipMod = {name, url, hash, patch, zips}: stdenvNoCC.mkDerivation {
    name = "${name}-mod.zip";
    src = fetchurl {
      name = "${name}.zip";
      inherit url hash;
    };
    nativeBuildInputs = [ unzip ];
    phases = [ "unpackPhase" "patchPhase" "installPhase" ];
    patches = [ (patchZipRefs patch zips) ];
    installPhase = ''
      runHook preInstall
      ${zip}/bin/zip -r $out .
      runHook postInstall
    '';
  };

  # Fetch base steamrt image.
  steamrtImage = dockerTools.pullImage { # VAR
    imageName = "registry.gitlab.steamos.cloud/proton/sniper/sdk";
    imageDigest = "sha256:5e17c2a9f62d7a982fd22bdf721119d39bd756d4b5e129ef26d349c2c8186a03";
    sha256 = "sha256-VCxckZgliHK/bs1fPMVHC6dgvBAliyhUKNQotJnKdpo=";
    finalImageTag = "steamrt";
    finalImageName = "localhost/steamrt";
  };

  # Fetch gst-plugins-rs cargo deps.
  gstPluginRsCargoDeps = rustPlatform.importCargoLock { # VAR
    lockFile = ./gst-plugins-rs-cargo.lock;
    outputHashes = {
      "cairo-rs-0.16.9" = "sha256-0hEScmRh/0qLCUwx38JzaE7ksN05oHqWmFBe26lWoMo=";
      "ffv1-0.0.0" = "sha256-af2VD00tMf/hkfvrtGrHTjVJqbl+VVpLaR0Ry+2niJE=";
      "flavors-0.2.0" = "sha256-zBa0X75lXnASDBam9Kk6w7K7xuH9fP6rmjWZBUB5hxk=";
      "gdk4-0.5.6" = "sha256-XzruGCQRcgnG/Sn9NGm77n9a0yo3r0SclVRKaYztXmQ=";
      "gstreamer-0.19.8" = "sha256-8mvkIpWn1uX+Up5ZWVDTCsiANxj3ityG2LkSJvmOeGI=";
    };
  };

  # Fetch all piper and transitive deps.
  espeakNgZips = { # VAR
    sonicZip = let sonicRef = "fbf75c3d6d846bad3bb3d456cbc5d07d9fd8c104"; in fetchurl {
      name = "sonic-${sonicRef}.zip";
      url = "https://github.com/waywardgeek/sonic/archive/${sonicRef}.zip";
      hash = "sha256-18WnFfV0pKKlr+lw9InTlQvNUinxvtPw4BClQTlX7CA=";
    };
  };
  piperPhonemizeZips = { # VAR
    onnxruntimeTgz = let onnxruntimeVersion = "1.14.1"; in fetchurl {
      name = "onnxruntime-${onnxruntimeVersion}.tgz";
      url = "https://github.com/microsoft/onnxruntime/releases/download/v${onnxruntimeVersion}/onnxruntime-linux-x64-${onnxruntimeVersion}.tgz";
      hash = "sha256-AQWF9TTYIr8C1Ux8/FO1eqPrDPNPj7dQPuUZ7RjiXSk=";
    };
    espeakNgZip = let espeakNgRef = "0f65aa301e0d6bae5e172cc74197d32a6182200f"; in makeZipMod {
      name = "espeak-ng-${espeakNgRef}";
      url = "https://github.com/rhasspy/espeak-ng/archive/${espeakNgRef}.zip";
      hash = "sha256-FQ/JVZJqCEp36+JcnoKHveLioXu/myOiXBR7VWg3lJ8=";
      patch = ./espeak-ng.patch;
      zips = espeakNgZips;
    };
  };
  piperZips = { # VAR
    fmtZip = let fmtVersion = "10.0.0"; in fetchurl {
      name = "fmt-${fmtVersion}.zip";
      url = "https://github.com/fmtlib/fmt/archive/refs/tags/${fmtVersion}.zip";
      hash = "sha256-W/TVNYMB/fO9EAwBudTB+7IJHcImf7T6bXzVIrPkcXk=";
    };
    spdlogZip = let spdlogVersion = "1.12.0"; in fetchurl {
      name = "spdlog-${spdlogVersion}.zip";
      url = "https://github.com/gabime/spdlog/archive/refs/tags/v${spdlogVersion}.zip";
      hash = "sha256-YXS/iIUodCKmxqAxLrijDo0ivPzufEim0C0YNdd2kjI=";
    };
    piperPhonemizeZip = let piperPhonemizeRef = "5ecbb9b59abcffe03a9775ae82491c9ac5037f4d"; in makeZipMod {
      name = "piper-phonemize-${piperPhonemizeRef}";
      url = "https://github.com/shaunren/piper-phonemize/archive/${piperPhonemizeRef}.zip";
      hash = "sha256-zYmv9sNyh3b/vzgr1ldIdsxn0TQCFA/F4+yMK8gTM18=";
      patch = ./piper-phonemize.patch;
      zips = piperPhonemizeZips;
    };
  };
  allPiperZips = (piperZips // piperPhonemizeZips // espeakNgZips);

  # Fetch all proton contrib deps.
  contribTarballs = let # VAR
    wineGeckoVer = "2.47.4";
    wineMonoVer = "9.4.0";
    xaliaVer = "0.4.5";
  in [
    (fetchurl rec {
      name = "wine-gecko-${wineGeckoVer}-x86_64.tar.xz";
      url = "https://dl.winehq.org/wine/wine-gecko/${wineGeckoVer}/${name}";
      hash = "sha256-/Yj8flN9BY16ir8MHryQxXSJKkZt6GcGom0lRxCoKBQ=";
    })
    (fetchurl rec {
      name = "wine-gecko-${wineGeckoVer}-x86.tar.xz";
      url = "https://dl.winehq.org/wine/wine-gecko/${wineGeckoVer}/${name}";
      hash = "sha256-LPyNXJSGAuIe/4p4YT4YJvLQM9+WcsrOh/7VboMQr7Y=";
    })
    (fetchurl rec {
      name = "wine-mono-${wineMonoVer}-x86.tar.xz";
      url = "https://github.com/madewokherd/wine-mono/releases/download/wine-mono-${wineMonoVer}/${name}";
      hash = "sha256-/XciGarPRrgl+okaZHr0qd34Q5MgEBwjGRiyA3vxOFg=";
    })
    (fetchurl rec {
      name = "xalia-${xaliaVer}-net48-mono.zip";
      url = "https://github.com/madewokherd/xalia/releases/download/xalia-${xaliaVer}/${name}";
      hash = "sha256-fgYXg6zwBcjckL1H/qGvn8lB+AxFlHd1L8MvvCkk7GU=";
    })
  ];
in {
  pname = "proton-mowbark"; # VAR
  version = "0.1.0"; # VAR

  # Fetch proton source with submodules.
  # .git directory is removed to maintain determinism -
  # hook to harvest version information before this happens.
  src = (fetchgit {
    name = "source";
    url = "https://github.com/ValveSoftware/Proton";
    rev = "3a269ab9966409b968c8bc8f3e68bd0d2f42aadf";
    hash = "sha256-dzIid6UGeFbAmQepM3FPRFo88BStG4qI3aGWYDJewUo=";
    fetchSubmodules = true;
  }).overrideAttrs (_: {
    env.NIX_PREFETCH_GIT_CHECKOUT_HOOK = ''
      pushd "$dir" >/dev/null
      git -C vkd3d-proton describe --always --exclude=* --abbrev=15 --dirty=0 > .vkd3d-proton-build
      git -C vkd3d-proton describe --always --tags --dirty=+ > .vkd3d-proton-version
      git -C dxvk describe --always --abbrev=15 --dirty=0 > .dxvk-version
      git describe --always --tags > .version
      popd >/dev/null
    '';
  });

  # Package for use with programs.steam.extraCompatPackages.
  outputs = [
    "out"
    "steamcompattool"
  ];

  # Required nix.conf settings:
  # nix.settings = {
  #   experimental-features = [ "auto-allocate-uids" "cgroups" ];
  #   system-features = [ "uid-range" ];
  #   auto-allocate-uids = true;
  # };
  requiredSystemFeatures = [ "uid-range" ];

  dontUpdateAutotoolsGnuConfigScripts = true;
  enableParallelBuilding = true; # VAR
  dontStrip = true; # VAR
  dontFixup = true;

  nativeBuildInputs = [
    mount
    gnumake
    undocker
  ];

  patches = [ # VAR
    # ContainerId patches to enable Dualsense haptics.
    ./dualsense/0001-mmdevapi-correctly-read-and-write-containerid-as-cls.patch
    ./dualsense/0002-containerid-helper-to-generate-a-containerid-from-a-.patch
    ./dualsense/0003-Implement-SetupDiGetDeviceInterfacePropertyW-for-DEV.patch

    # Patch `git describe` with strings harvested during fetchgit.
    ./version.patch

    # Replace piper dependency download URLs with file paths.
    (patchZipRefs ./piper.patch piperZips)
  ];

  configurePhase = ''
    runHook preConfigure
    unset CONFIG_SHELL

    # Make piper dependency zips available to container.
    ${concatStringsSep "\n" (mapAttrsToList (name: value: "cp ${value} ${value.name}") allPiperZips)}

    # Make proton contrib tarballs available to container.
    mkdir -p contrib
    ${concatStringsSep "\n" (map (x: "cp ${x} contrib/${x.name}") contribTarballs)}

    # Make gst-plugins-rs cargo deps available to container.
    cp -Lr --reflink=auto -- ${gstPluginRsCargoDeps} gst-plugins-rs/cargo-vendor-dir
    chmod -R +644 -- gst-plugins-rs/cargo-vendor-dir
    mv gst-plugins-rs/cargo-vendor-dir/.cargo gst-plugins-rs

    # Establish out-of-tree build directory.
    mkdir -p $NIX_BUILD_TOP/build

    # Establish steamrt rootfs.
    local STEAMRT_ROOTFS=$NIX_BUILD_TOP/steamrt-rootfs
    mkdir -p $STEAMRT_ROOTFS
    pushd $STEAMRT_ROOTFS >/dev/null
    undocker ${steamrtImage} - | tar -x '--exclude=dev/*'
    popd >/dev/null
    mkdir -p $STEAMRT_ROOTFS$NIX_BUILD_TOP
    mount --bind $NIX_BUILD_TOP $STEAMRT_ROOTFS$NIX_BUILD_TOP
    mkdir -p $STEAMRT_ROOTFS/test
    mount --bind $NIX_BUILD_TOP/build $STEAMRT_ROOTFS/test
    mkdir -p $STEAMRT_ROOTFS/dev
    mount --rbind /dev $STEAMRT_ROOTFS/dev
    mkdir -p $STEAMRT_ROOTFS/proc
    mount --bind /proc $STEAMRT_ROOTFS/proc

    # Fake podman with chroot.
    mkdir -p $NIX_BUILD_TOP/bin
    export PATH=$NIX_BUILD_TOP/bin:$PATH
    cp ${./fake-podman.sh} $NIX_BUILD_TOP/bin/fake-podman.sh
    echo -e '#!${bash}/bin/bash\nexec' chroot $STEAMRT_ROOTFS /bin/bash $NIX_BUILD_TOP/bin/fake-podman.sh '"$@"' > $NIX_BUILD_TOP/bin/podman
    chmod +x $NIX_BUILD_TOP/bin/podman

    # Establish home directory.
    mkdir -p $NIX_BUILD_TOP/home
    export HOME=$NIX_BUILD_TOP/home

    # Run configure.sh to get Makefile.
    cd $NIX_BUILD_TOP/build
    bash $NIX_BUILD_TOP/source/configure.sh --build-name=${finalPackageName} --container-engine=podman

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    local cores=''${enableParallelBuilding:+''${NIX_BUILD_CORES}}
    local flagsArray=(
      -j''${cores:-1}
      ''${dontStrip:+UNSTRIPPED_BUILD=1}
      SHELL=bash
    )
    unset cores
    echoCmd 'build flags' "''${flagsArray[@]}"
    make "''${flagsArray[@]}"
    unset flagsArray

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Make it impossible to add to an environment. You should use the appropriate NixOS option.
    echo "${finalPackageName} should not be installed into environments. Please use programs.steam.extraCompatPackages instead." > $out

    # Actual compattool directory.
    mkdir $steamcompattool
    cp -a dist/. $steamcompattool

    runHook postInstall
  '';
})

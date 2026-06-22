{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }:
  let
    # Extend lib
    lib = nixpkgs.lib.extend (final: prev: {
      a = import ./lib { lib = final; };
    });
  in {
    # Configuration for host a
    nixosConfigurations.a = lib.nixosSystem {
      system = "x86_64-linux";
      extraModules = import ./modules/module-list.nix;
      modules = [
        ({ pkgs, ... }: {
          # Let 'nixos-version --json' know about the Git revision
          # of this flake.
          system.configurationRevision = lib.mkIf (self ? rev) self.rev;

          # Package overlays
          nixpkgs.overlays = [
            (final: prev: import ./pkgs final)
            (final: prev: {
              bubblewrap = prev.bubblewrap.overrideAttrs (finalAttrs: previousAttrs: {
                mesonFlags = [ (lib.mesonBool "support_setuid" true) ];
              });
              rpcs3 = prev.rpcs3.overrideAttrs (finalAttrs: previousAttrs: {
                version = "0.0.41";
                src = prev.fetchFromGitHub {
                  owner = "RPCS3";
                  repo = "rpcs3";
                  rev = "40e9ee5af0de7ca31691c58eebe64ba205a2900b";
                  postCheckout = ''
                    cd $out/3rdparty
                    git submodule update --init \
                      fusion/fusion asmjit/asmjit yaml-cpp/yaml-cpp SoundTouch/soundtouch stblib/stb \
                      feralinteractive/feralinteractive wolfssl/wolfssl
                  '';
                  hash = "sha256-d28DlmYchCU0QvFFhyf1GHx9NgcUX4zZ0XpV8/O6vJc=";
                };
                cmakeFlags = previousAttrs.cmakeFlags ++ [
                  (lib.cmakeBool "BUILD_SHARED_LIBS" false)
                ];
              });
            })
          ];

          # Use configuration.nix for everything
          imports = [ ./configuration.nix ];
        })
      ];
    };
  };
}

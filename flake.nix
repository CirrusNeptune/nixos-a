{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/24.05-beta";
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

          # Force kernel compile with gcc12
          boot.kernelPackages = pkgs.linuxPackages.extend (final: prev: {
            kernel = prev.kernel.override (prev: {
              stdenv = pkgs.gcc12Stdenv;
              buildPackages = pkgs.buildPackages // { stdenv = pkgs.buildPackages.gcc12Stdenv; };
            });
          });

          # Package overlays
          nixpkgs.overlays = [
            (final: prev: import ./pkgs final)
          ];

          # Use configuration.nix for everything
          imports = [ ./configuration.nix ];
        })
      ];
    };
  };
}

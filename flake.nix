{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    sops-nix.url = "github:Mic92/sops-nix/b6cb5de";
    crate2nix_stable.url = "github:nix-community/crate2nix/0.14.0";
  };

  outputs = { self, nixpkgs, sops-nix, crate2nix_stable }:
  let
    # Extend lib
    lib = nixpkgs.lib.extend (final: prev: {
      a = import ./lib { lib = final; };
      crate2nix = crate2nix_stable.lib;
    });
  in {
    # Module extensions
    #nixosModules.default = import ./modules;

    # Configuration for host a
    nixosConfigurations.a = lib.nixosSystem {
      system = "x86_64-linux";
      extraModules = import ./modules/module-list.nix;
      modules = [
        #self.nixosModules.default
        ({ pkgs, ... }: {
          # Let 'nixos-version --json' know about the Git revision
          # of this flake.
          system.configurationRevision = lib.mkIf (self ? rev) self.rev;

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

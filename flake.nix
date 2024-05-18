{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    sops-nix.url = "github:Mic92/sops-nix/b6cb5de";
    crate2nix_stable.url = "github:nix-community/crate2nix/0.14.0";
  };

  outputs = { self, nixpkgs, sops-nix, crate2nix_stable }:
  let
    pkgs = nixpkgs.extend (final: prev: {
      lib = final.lib.extend (final: prev: {
        a = import ./lib { lib = final; };
        crate2nix = crate2nix_stable.lib;
      });
    });
  in {
    nixosConfigurations.a = pkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules =
        [ ({ pkgs, ... }: {
            # Let 'nixos-version --json' know about the Git revision
            # of this flake.
            system.configurationRevision = pkgs.lib.mkIf (self ? rev) self.rev;

            # Use configuration.nix for everything
            imports = [ ./configuration.nix ];
          })
          sops-nix.nixosModules.sops
        ];
    };
  };
}

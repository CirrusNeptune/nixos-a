{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    sops-nix.url = "github:Mic92/sops-nix/b6cb5de";
    crate2nix_stable.url = "github:nix-community/crate2nix/0.14.0";
  };

  outputs = { self, nixpkgs, sops-nix }: {
    nixosConfigurations.a = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      lib = nixpkgs.lib.extend (final: prev: {
        a = import ./lib { lib = final; };
      });
      modules =
        [ ({ pkgs, ... }: {
            # Let 'nixos-version --json' know about the Git revision
            # of this flake.
            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

            # Use configuration.nix for everything
            imports = [ ./configuration.nix ];
          })
          sops-nix.nixosModules.sops
        ];
    };
  };
}

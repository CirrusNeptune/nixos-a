{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    sops-nix.url = "github:github:Mic92/sops-nix/b6cb5de";
  };

  outputs = { self, nixpkgs, sops-nix }: {

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      lib = nixpkgs.lib.extend (final: prev: {
        nixon = import ./nixon/lib { lib = final; };
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

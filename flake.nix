{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

  outputs = { self, nixpkgs }: {

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      _module.args = {
        mowbark = import ./mowbark { lib = nixpkgs.lib; };
      };
      #lib = nixpkgs.lib.extend (final: prev: {
      #  mowbark = import ./mowbark { lib = final; };
      #});
      modules =
        [ ({ pkgs, ... }: {
            # Let 'nixos-version --json' know about the Git revision
            # of this flake.
            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

            # Use configuration.nix for everything
            imports = [ ./configuration.nix ];
          })
        ];
    };
  };
}

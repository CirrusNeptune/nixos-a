{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
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
              steam = prev.steam.override {
                extraPkgs = pkgs: with pkgs; [
                   mangohud
                   gamemode
                ];
                buildFHSEnv = pkgs.buildFHSEnv.override {
                  # use the setuid wrapped bubblewrap
                  bubblewrap = "/run/wrappers/bin/..";
                };
                #extraBwrapArgs = [ "--unshare-user" "--uid" "1000" ];
              };
            })
          ];

          # Use configuration.nix for everything
          imports = [ ./configuration.nix ];
        })
      ];
    };
  };
}

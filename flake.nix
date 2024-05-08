{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";

  outputs = { self, nixpkgs }: {

    nixosConfigurations.a = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules =
        [ ({ pkgs, ... }: {
            # Let 'nixos-version --json' know about the Git revision
            # of this flake.
            system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

            imports =
              [ # Include the results of the hardware scan.
                ./hardware-configuration.nix
                ./cachix.nix
              ];

            # Enable flakes
            nix.settings.experimental-features = [ "nix-command" "flakes" ];

            # Use the systemd-boot EFI boot loader.
            boot.loader.systemd-boot.enable = true;
            boot.loader.efi.canTouchEfiVariables = true;

            # Network configuration.
            networking.useDHCP = false;
            networking.firewall.allowedTCPPorts = [ 80 ];

            # Enable a web server.
            services.httpd = {
              enable = true;
              adminAddr = "morty@example.org";
            };
          })
        ];
    };

  };
}

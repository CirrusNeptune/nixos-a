1. Clone flake repo: https://github.com/CirrusNeptune/nixos-a
  a. configuration.nix is the main configuration
  b. pkgs dir contains our custom packages
  c. modules/services contains applied packages with relevant configurations. These are accessed from other config files with a.services.<service-name>
2. Open repo dir in PyCharm (works well with NixIDEA plugin installed)
3. Clone nixpkgs for a local reference of stuff you can do: https://github.com/NixOS/nixpkgs
  a. all-packages.nix is the package list, follow paths from there to get configuration options
4. After pushing changes, ssh and rebuild server: sudo nixos-rebuild switch --flake github:CirrusNeptune/nixos-a/<five-chars-of-commit-sha-prefix>
  a. Trial-and-error is the best approach for this, don't worry about screwing up, we can always revert to a sane config
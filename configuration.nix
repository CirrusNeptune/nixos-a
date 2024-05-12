# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

let
  ethernetInterface = "enp0s1";
  timeZone = "America/Los_Angeles";
  makeIpHost = nodeId: "10.0.10.${toString nodeId}";
  gatewayHost = makeIpHost 1;
  lanHost = makeIpHost 2;
  hassHost = makeIpHost 3;
  giteaHost = makeIpHost 4;
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  #networking.networkmanager = {
  #  enable = true;
  #  ensureProfiles.profiles = lib.attrsets.mapAttrs'
  #    (lib.nixon.macvlan.makeMacvlanProfile ethernetInterface)
  #    { gitea = "git"; hass = "homeassistant"; };
  #};
  networking.useNetworkd = true;
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    netdevs = {
      "20-macvlan-hass" = {
        netdevConfig = {
          Kind = "macvlan";
          Name = "macvlan-hass";
        };
        macvlanConfig.Mode = "bridge";
      };
      "30-gitea-hass" = {
        netdevConfig = {
          Kind = "macvlan";
          Name = "macvlan-gitea";
        };
        macvlanConfig.Mode = "bridge";
      };
    };
    networks = {
      "10-lan" = {
        # match the interface by name
        matchConfig.Name = "${ethernetInterface}";
        address = [
          # configure addresses including subnet mask
          (lanHost + "/24")
        ];
        macvlan = [
          "macvlan-hass"
        ];
        routes = [
          # create default routes
          { routeConfig.Gateway = gatewayHost; }
        ];
        # make the routes on this interface a dependency for network-online.target
        linkConfig.RequiredForOnline = "routable";
      };
      "20-macvlan-hass" = {
        # match the interface by name
        matchConfig.Name = "macvlan-hass";
        address = [
          # configure addresses including subnet mask
          (hassHost + "/24")
        ];
        routes = [
          # create default routes
          { routeConfig.Gateway = gatewayHost; }
        ];
        # make the routes on this interface a dependency for network-online.target
        linkConfig.RequiredForOnline = "routable";
      };
      "30-gitea-hass" = {
        # match the interface by name
        matchConfig.Name = "macvlan-gitea";
        address = [
          # configure addresses including subnet mask
          (giteaHost + "/24")
        ];
        routes = [
          # create default routes
          { routeConfig.Gateway = gatewayHost; }
        ];
        # make the routes on this interface a dependency for network-online.target
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  # Set your time zone.
  time.timeZone = timeZone;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;


  

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.alice = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  #   packages = with pkgs; [
  #     firefox
  #     tree
  #   ];
  # };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
  ];

  # Add docker containers
  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      homeassistant = {
        volumes = [
          "/var/home-assistant:/config"
          "/etc/localtime:/etc/localtime:ro"
        ];
        environment.TZ = timeZone;
        image = "ghcr.io/home-assistant/home-assistant:2024.5.3";
        ports = [
          "${hassHost}:80:8123"
        ];
        extraOptions = [
          "--network=bridge"
          #"--device=/dev/ttyACM0:/dev/ttyACM0"  # Example, change this to match your own hardware
        ];
      };
      gitea = {
        volumes = [
          "/var/gitea:/data"
          "/etc/timezone:/etc/timezone:ro"
          "/etc/localtime:/etc/localtime:ro"
        ];
        environment.TZ = timeZone;
        image = "gitea/gitea:1.21.11";
        ports = [
          "${giteaHost}:80:3000"
        ];
        extraOptions = [
          "--network=bridge"
        ];
        environment = {
          USER_UID = "1000";
          USER_GID = "1000";
        };
      };
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "23.11"; # Did you read the comment?

}


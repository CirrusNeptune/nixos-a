# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

let
  ethernetInterface = "enp7s0";
  timeZone = "America/Los_Angeles";
  makeIpHost = nodeId: "10.0.0.${toString nodeId}";
  gatewayHost = makeIpHost 1;
  lanHost = makeIpHost 2;
  hassHost = makeIpHost 3;
  kodiHost = makeIpHost 4;
  makeIotHost = nodeId: "10.0.1.${toString nodeId}";
  iotGatewayHost = makeIotHost 1;
  iotHost = makeIotHost 2;
  dualsenseRule = pkgs.writeTextFile {
    name = "dualsense-wireless-controller-udev-rule";
    text = ''SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0666"'';
    destination = "/etc/udev/rules.d/99-dualsense-wireless-controller.rules";
  };
in
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.memtest86.enable = true;
  nixpkgs.config.allowUnfree = true;

  # Enable flakes and uid-range
  nix.settings.experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" "cgroups" ];
  nix.settings.system-features = [ "kvm" "uid-range" "big-parallel" ];
  nix.settings.auto-allocate-uids = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Early KMS and HISENSE + Nakamichi EDID
  hardware.amdgpu.initrd.enable = true;
  hardware.display = {
    edid.packages = [
      (pkgs.runCommand "edid-custom" {} ''
        mkdir -p $out/lib/firmware/edid
        ln -s ${./hdmi2_edid_capture.bin} $out/lib/firmware/edid/hdmi2_edid_capture.bin
      '')
    ];
    outputs."HDMI-A-2" = {
      mode = "e";
      edid = "hdmi2_edid_capture.bin";
    };
  };

  programs.mtr.enable = true;

  networking.hostName = "a"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking.useNetworkd = true;
  networking.useDHCP = false;
  systemd.network = {
    enable = true;
    netdevs = {
      "20-vlan-iot" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-iot";
        };
        vlanConfig.Id = 2;
      };
    };
    networks = {
      "10-lan" = {
        # match the interface by name
        matchConfig.Name = ethernetInterface;
        address = [
          # configure addresses including subnet mask
          (lanHost + "/24")
          (hassHost + "/24")
          (kodiHost + "/24")
        ];
        routes = [
          # create default routes
          { Gateway = gatewayHost; }
        ];
        # make the routes on this interface a dependency for network-online.target
        linkConfig.RequiredForOnline = "routable";
        # IoT vlan
        vlan = [ "vlan-iot" ];
      };
      "20-vlan-iot" = {
         # match the interface by name
         matchConfig.Name = "vlan-iot";
         address = [
           # configure addresses including subnet mask
           (iotHost + "/24")
         ];
         # make the routes on this interface a dependency for network-online.target
         linkConfig.RequiredForOnline = "routable";
      };
    };
  };

  # Open ports in the firewall.
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ ethernetInterface "podman0" ];
    interfaces."vlan-iot" = let
      wizPorts = [ 38900 38899 5577 9999 8883 ];
    in {
      allowedTCPPorts = wizPorts;
      allowedUDPPorts = wizPorts;
    };
  };

  # Kodi NAT
  networking.nat = {
    enable = true;
    extraCommands = ''
      iptables -w -t nat -A nixos-nat-pre \
        -p tcp \
        -d ${kodiHost} \
        --dport 80 \
        -j DNAT \
        --to-destination ${kodiHost}:9191
    '';
  };

  # Add wireshark for remote capture
  programs.wireshark.enable = true;

  # Configure DNS
  services.resolved = {
    domains = [ "mow" ];
    fallbackDns = [ gatewayHost ];
  };

  # Set your time zone.
  time.timeZone = timeZone;
  environment.etc.timezone.text = timeZone;

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

  # Pipewire audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.udev.packages = [ dualsenseRule ];

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
  a.services.steam = {
    enable = true;
    user = "a";
  };
  a.services.kwin-session = {
    enable = true;
    user = "a";
  };
  a.services.kodi = {
    enable = true;
    user = "a";
  };

  systemd.defaultUnit = lib.mkForce "graphical.target";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

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
  users = {
    mutableUsers = false;
    users = {
      root = {
        hashedPassword = "$y$j9T$4OwHrG/9t08OLgF.l0pqj0$JJu2hTsddDPF4o12pZUWi0zSap8eStNvymaYt9Ss272";
      };
      a = {
        hashedPassword = "$y$j9T$4OwHrG/9t08OLgF.l0pqj0$JJu2hTsddDPF4o12pZUWi0zSap8eStNvymaYt9Ss272";
        isNormalUser = true;
        extraGroups = [ "wheel" "video" "render" "wireshark" ];
        packages = with pkgs; [
          firefox
          intiface-central
        ];
      };
    };
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    gdb
    file
  ];

  # Add docker containers
  virtualisation.oci-containers.backend = "podman";
  a.services.homeassistant = {
    enable = true;
    host = hassHost;
  };
  a.services.cec.cecPhysAddr = "1.3.0.0";
  a.services.borgbackup.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  fileSystems."/b" = {
    device = "/dev/disk/by-uuid/bc630d37-a38a-4221-9a6f-c04288306d1f";
    fsType = "ext4"; #  sudo lsblk -f
  };

  # https://nixos.wiki/wiki/Samba
  # deleted hosts params, user stuff,
  # make sure to run smbpasswd -a a as sudos
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      "global" = {
        "workgroup" = "WORKGROUP";
        "server string" = "smbnix";
        "netbios name" = "smbnix";
        "security" = "user";
      };
      "public" = {
        "path" = "/b/multimedia";
        "read only" = "no";
        "browseable" = "yes";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "comment" = "Multimedia samba share.";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  networking.firewall.allowPing = true;

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  # nix-ld config for jetbrains remote server
  a.extensions.jetbrains-ld = {
    enable = true;
    users = {
      linuxdev = { devPackages = [ pkgs.linux ]; };
      pipewiredev = { devPackages = [ pkgs.pkg-config pkgs.pipewire ]; environment = { PIPEWIRE_RUNTIME_DIR = "/run/user/1000"; }; };
    };
  };

  # Filter xpad events to clients of the active VT session
  a.extensions.xpad-console-filter.enable = true;

  # Copy the Nix:wqOS configuration file and link it from the resulting system
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


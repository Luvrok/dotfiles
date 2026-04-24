{ modulesPath, pkgs, ... }:

{
  imports = [
    ./disk-config.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  system.stateVersion = "25.11";

  networking = {
    hostName = "jedha";

    networkmanager = {
      enable = false;
    };

    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        80
        443
        8448
      ];
      allowPing = true;
    };

    wireless = {
      enable = false;

      iwd = {
        enable = true;
        settings = {
          Settings.AutoConnect = true;
          General = {
            AddressRandomization = "network";
            AddressRandomizationRange = "full";
            EnableNetworkConfiguration = false;
            RoamRetryInterval = 10;
          };

          Network = {
            EnableIPv6 = false;
            RoutePriorityOffset = 300;
          };
        };
      };
    };
  };

  services = {
    resolved.enable = true;
    vnstat.enable = true;

    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };

  systemd.network = {
    enable = true;
    wait-online.enable = false;
    wait-online.anyInterface = true;
    networks = {
      "10-eth" = {
        matchConfig.MACAddress = "bc:c3:42:af:59:e6";

        networkConfig = {
          Address = [ "192.168.0.216/24" ];
          DNS = [ "9.9.9.9" ];
        };

        routes = [
          { routeConfig.Gateway = "192.168.0.1"; }
        ];
      };
      "20-wifi" = {
        matchConfig.Name = "wlp2s0";
        networkConfig.DHCP = "ipv4";
      };
    };
  };

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
  };

  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_GB.UTF-8";

  networking.useNetworkd = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
  ];

  users.users.jedha = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "nopassword";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
    ];
  };

  environment.etc."nixos".source = ./.;
  system.activationScripts.copyConfig.text = ''
    rm -rf /root/nixos-config
    mkdir -p /root
    cp -rT ${./../..} /root/nixos-config
    chown -R root:root /root/nixos-config
  '';

  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
    wget
    git
    btop
    vnstat
    dig
    git-crypt
    nh
  ];
}

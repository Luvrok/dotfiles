{
  pkgs,
  inputs,
  username,
  ...
}:

{
  imports = [
    ./overlays
    ./services
    ./modules
    ./security.nix
    ./options.nix
    ./boot.nix
    ./env.nix
    ./packages.nix
    ./network.nix
  ];

  time.timeZone = "Europe/Moscow";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "ru_RU.UTF-8";
      LC_IDENTIFICATION = "ru_RU.UTF-8";
      LC_MEASUREMENT = "ru_RU.UTF-8";
      LC_MONETARY = "ru_RU.UTF-8";
      LC_NAME = "ru_RU.UTF-8";
      LC_NUMERIC = "ru_RU.UTF-8";
      LC_PAPER = "ru_RU.UTF-8";
      LC_TELEPHONE = "ru_RU.UTF-8";
      LC_TIME = "en_GB.UTF-8";
    };
  };

  console = {
    packages = with pkgs; [ terminus_font ];
    font = "${pkgs.terminus_font}/share/consolefonts/ter-u24n.psf.gz";
    useXkbConfig = true;

    colors = [
      "020202" # 0  black
      "cc241d" # 1  red
      "98971a" # 2  green
      "d65d0e" # 3  yellow
      "458588" # 4  blue
      "b16286" # 5  purple
      "689d6a" # 6  aqua
      "a89984" # 7  light grey (fg)
      "504945" # 8  dark grey
      "fb4934" # 9  bright red
      "b8bb26" # 10 bright green
      "fabd2f" # 11 bright yellow
      "83a598" # 12 bright blue
      "d3869b" # 13 bright purple
      "8ec07c" # 14 bright aqua
      "ebdbb2" # 15 white / bright fg
    ];
  };

  # maybe someday

  # systemd.services = {
  #   "autovt@".enable = false;
  #   "getty@".enable = false;
  #   "getty@tty1".enable = lib.mkForce false;
  #   "kmsconvt@".enable = lib.mkForce false;
  #   "kmsconvt@tty1".enable = lib.mkForce false;
  #   "ly@".enable = false;
  #   "kmscon-ly@tty1" = {
  #     description = "Kmscon + Ly on tty1";
  #     after = [
  #       "systemd-user-sessions.service"
  #       "plymouth-quit-wait.service"
  #       "systemd-logind.service"
  #     ];
  #     conflicts = [
  #       "getty@tty1.service"
  #       "kmsconvt@tty1.service"
  #     ];
  #     before = [
  #       "getty.target"
  #       "multi-user.target"
  #     ];
  #
  #     serviceConfig = {
  #       Type = "simple";
  #       User = "root";
  #       DynamicUser = false;
  #       ExecStart = "${pkgs.kmscon}/bin/kmscon --vt=%I --seats=seat0 --login -- ${pkgs.ly}/bin/ly";
  #       Restart = "always";
  #       TTYPath = "/dev/%I";
  #       TTYReset = "yes";
  #       TTYVHangup = "yes";
  #       StandardInput = "tty";
  #       StandardOutput = "tty";
  #     };
  #
  #     wantedBy = [ "multi-user.target" ];
  #   };
  # };
  #
  # services.kmscon = {
  #   enable = true;
  #   fonts = [
  #     {
  #       name = "JetBrainsMono Nerd Font Mono";
  #       package = pkgs.nerd-fonts.jetbrains-mono;
  #     }
  #   ];
  #   # hwRender = lib.mkDefault false;
  #   useXkbConfig = true;
  #   extraConfig = ''
  #     font-size=12
  #     font-dpi=109
  #   '';
  # };

  nix = {
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  security.sudo.extraConfig = ''
    Defaults lecture = never
    Defaults timestamp_timeout=450
  '';

  users = {
    groups = {
      libvirt = { };
      vboxsf = { };
      plugdev = { };
      storage = { };
    };

    users = {
      root = {
        shell = pkgs.bash;
      };
      ${username} = {
        shell = pkgs.zsh;
        isNormalUser = true;
        extraGroups = [
          "i2c" # monitor brightness
          "networkmanager"
          "network"
          "wheel"
          "kvm"
          "libvirt"
          "libvirtd"
          "vboxusers"
          "vboxsf"
          "audio"
          "plugdev"
          "storage"
          "input"
          "video"
          "dialout"
        ];
      };
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [
          "gtk"
        ];
      };
    };
  };

  programs = {
    thunar.enable = true;
    throne = {
      enable = true;
      tunMode.enable = true;
    };
    slock = {
      enable = false;
      package = pkgs.slock;
    };
    nix-ld.enable = true;
    steam.enable = true;
    gamemode.enable = true;
    zsh.enable = true;
    dconf.enable = true;
  };

  system.stateVersion = "25.11";
}

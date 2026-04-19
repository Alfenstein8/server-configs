# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  hostname,
  pkgs,
  system,
  inputs,
  nvfNeovim,
  ...
}:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  imports = [
    ./hardware-configuration.nix
    ./hardware-acceleration.nix # QSV use GPU
    ./secrets.nix
    # ./root-certificates.nix
    # ./backup.nix # Upload backup to backblaze
    # ./dawarich.nix
    ./zfs.nix # zsf Mirror
    ./users.nix
    ./services # Custom systemd services
    ./caddy.nix # Reverse proxy
    ./headscale.nix
    ./immich.nix # Image backup
    ./immichframe.nix
    ./paperless.nix # Document management
    ./radicale.nix # Contacts and calendar
    # ./netdata.nix # Server Monitor
    ./uptime-kuma.nix # Services monitor
    ./homepage.nix
    ./wg-easy # Wireguard VPN with web ui
    ./arr # The arr stack
    ./jellyfin.nix # Video streaming
    ./samba.nix # Samba server
    ./jellyseerr.nix # Jellyfin video requests
    # ./tailscale.nix # Easy VPN setup
    ./syncthing.nix # Sync files to divices
    ./navidrome.nix # Music streaming
    # ./owntracks
    ./cockpit.nix
    ./bash.nix
    ./acme.nix # dns-01 challenge to get ssl certificate for caddy
    ./tubearchivist # Youtube
    # ./rustdesk.nix
    # ./minecraft.nix
    # ./adguardhome.nix
    ./forgejo.nix
    ./adguardhome.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = hostname; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Copenhagen";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_DK.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "da_DK.UTF-8";
    LC_IDENTIFICATION = "da_DK.UTF-8";
    LC_MEASUREMENT = "da_DK.UTF-8";
    LC_MONETARY = "da_DK.UTF-8";
    LC_NAME = "da_DK.UTF-8";
    LC_NUMERIC = "da_DK.UTF-8";
    LC_PAPER = "da_DK.UTF-8";
    LC_TELEPHONE = "da_DK.UTF-8";
    LC_TIME = "da_DK.UTF-8";
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "dk";
    variant = "";
  };

  # Configure console keymap
  console.keyMap = "dk-latin1";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages =
    with pkgs;
    [
      git
      lazygit
      ripgrep
      btop
      tree
      tmux
      ocl-icd
      clinfo
      lsd
      yazi
      nixfmt
    ]
    ++ [
      inputs.compose2nix.packages.${system}.default
      nvfNeovim
    ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    # settings = {
    # PasswordAuthentication = true;
    # };
    extraConfig = "AuthenticationMethods \"publickey,password\"";
  };
  services.fail2ban.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [
    80
    443
    51820
    2222
    53
  ]; # HTTP, HTTPS, Wireguard, forgejo SSH, adguard home
  networking.firewall.enable = true;
  networking.firewall.allowedUDPPorts = [ 53 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}

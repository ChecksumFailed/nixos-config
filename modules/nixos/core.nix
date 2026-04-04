{ config, pkgs, lib, ... }:

{
  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false; # Limine manages boot order, don't let systemd-boot touch NVRAM
  boot.kernelPackages = pkgs.linuxPackages_zen;

 
  # Networking
  networking.networkmanager.enable = true;

  # Timezone & Locale
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # User
  users.users.ben = {
    isNormalUser = true;
    description = "Ben";
    extraGroups = ["wheel" "video" "audio" "input" "docker"];
    shell = pkgs.zsh;
  };

  # Shell
  programs.zsh.enable = true;

  # Core Tools
  environment.systemPackages = with pkgs; [
    git
    vim
    gh
    curl
    wget
    zip
    unzip
    htop
    btop
    neovim
    fastfetch
    rsync
    pciutils
    usbutils
  ];

  # Fonts
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
  ];

  # Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # Allow Unfree
  nixpkgs.config.allowUnfree = true;
}

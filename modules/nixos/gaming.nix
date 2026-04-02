{ config, pkgs, ... }:

{
  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Gamemode
  programs.gamemode.enable = true;

  # Xbox Elite Series 2 support (xpadneo)
  hardware.xpadneo.enable = true;

  # Gaming & Streaming Packages
  environment.systemPackages = with pkgs; [
    lutris
    heroic
    wineWowPackages.staging
    mangohud # Performance overlay
    gamescope # Microcompositor for gaming
    obs-studio # For streaming
  ];
}

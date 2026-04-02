{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Browsers
    brave
    microsoft-edge
    
    # Communication
    discord
    slack
    whatsapp-for-linux
    teams-for-linux
    
    # Tools
    vscode
    obsidian
    kitty
    foot
    
    # Desktop Utilities
    pavucontrol
    nautilus
    wl-clipboard
    grim
    slurp
    cliphist
    
    # Media
    vlc
    mpv
  ];
}

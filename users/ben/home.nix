{ config, pkgs, inputs, ... }:

{
  imports = [
    ../../modules/home-manager/desktop/hyprland.nix
    ../../modules/home-manager/desktop/waybar.nix
    ../../modules/home-manager/desktop/rofi.nix
    ../../modules/home-manager/shell/zsh.nix
    ../../modules/home-manager/shell/git.nix
    ../../modules/home-manager/apps.nix
  ];

  home.username = "ben";
  home.homeDirectory = "/home/ben";
  home.stateVersion = "24.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    BROWSER = "brave";
  };
}

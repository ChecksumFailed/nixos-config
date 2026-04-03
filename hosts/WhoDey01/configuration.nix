{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/core.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/services.nix
  ];

  networking.hostName = "WhoDey01";
  system.stateVersion = "24.11";
}

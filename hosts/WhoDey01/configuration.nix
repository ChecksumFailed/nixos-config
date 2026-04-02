{ config, pkgs, inputs, ... }:

{
  imports = [
    inputs.impermanence.nixosModules.impermanence
    ./hardware-configuration.nix
    ../../modules/nixos/core.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/gaming.nix
    ../../modules/nixos/services.nix
    ../../modules/nixos/persistence.nix
  ];

  networking.hostName = "WhoDey01";
  system.stateVersion = "24.11";
}

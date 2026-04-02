{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # Btrfs Subvolume Layout
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" "noatime" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };

  # Persistence removed: /persist subvolume is not mounted anymore.
  # Previously this block mounted a @persist subvolume for system-level persistent data.
  # The system will no longer rely on /persist; persistent paths should be handled
  # explicitly via other mechanisms if needed.

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  # Your existing Brave subvolume preservation
  fileSystems."/home/ben/.config/BraveSoftware/Brave-Browser/Default/Login Data-journal" = {
    device = "/dev/disk/by-label/nixos"; # Assuming it's on the same disk
    fsType = "btrfs";
    options = [ "subvol=@.config/BraveSoftware/Brave-Browser/Default/Login Data-journal" "compress=zstd" "noatime" ];
  };

  swapDevices = [ ];

  # CPU Power Management
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

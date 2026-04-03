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
    device = "/dev/disk/by-uuid/ea08e3ac-27b5-4825-9fad-94421b4855ac";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" "noatime" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/ea08e3ac-27b5-4825-9fad-94421b4855ac";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/ea08e3ac-27b5-4825-9fad-94421b4855ac";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };

  # Persistence removed: /persist subvolume is not mounted anymore.
  # Previously this block mounted a @persist subvolume for system-level persistent data.
  # The system will no longer rely on /persist; persistent paths should be handled
  # explicitly via other mechanisms if needed.

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0367-C1BF";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/ea08e3ac-27b5-4825-9fad-94421b4855ac";
    fsType = "btrfs";
    options = [ "subvol=@data" "compress=zstd" "noatime" ];
  };

  swapDevices = [ ];

  # CPU Power Management
  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}

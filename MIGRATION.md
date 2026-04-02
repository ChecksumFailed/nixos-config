# Arch to NixOS Migration Guide (with Impermanence)

This guide outlines the steps to move from your current Arch Linux setup to your new modular NixOS configuration.

## 1. Preparation (on Arch)
*   **Backup**: Ensure your `new-nixos-config` folder is backed up to a USB drive or cloud storage.
*   **Brave Data**: Back up the full profile: `cp -r ~/.config/BraveSoftware/ /path/to/backup/`.

## 2. Installation (NixOS ISO)
1.  **Boot the Installer**: Use the NixOS 24.11 minimal ISO.
    > **WARNING**: Do NOT use the GUI (Calamares) installer — it does not support custom Btrfs subvolume layouts or the blank snapshot required for impermanence. You must partition manually.
2.  **Partitioning (Btrfs)**:
    *   Create a **512MiB FAT32** partition (mount at `/boot`).
    *   Create the rest as a **Btrfs** partition. **Label it `nixos`** — the wipe hook depends on this:
    ```bash
    mkfs.btrfs -L nixos /dev/sda2
    ```
3.  **Subvolumes Setup**:
    Inside the Btrfs partition (let's say it's `/dev/sda2`):
    ```bash
    mount /dev/sda2 /mnt
    btrfs subvolume create /mnt/@root        # This will be wiped on boot
    btrfs subvolume create /mnt/@home        # Persistent /home
    btrfs subvolume create /mnt/@nix         # Persistent /nix (software)
    btrfs subvolume create /mnt/@persist     # Persistent system files
    btrfs subvolume create /mnt/@snapshots   # Btrfs snapshots location
    ```
4.  **Blank Snapshot (CRITICAL for Impermanence)**:
    You MUST create the blank snapshot before installing:
    ```bash
    # Ensure @root is EMPTY (just created)
    btrfs subvolume snapshot -r /mnt/@root /mnt/@root-blank
    umount /mnt
    ```
5.  **Mounting for Installation**:
    Mount the subvolumes to `/mnt`:
    *   `/dev/sda2` (subvol=@root) -> `/mnt`
    *   `/dev/sda2` (subvol=@home) -> `/mnt/home`
    *   `/dev/sda2` (subvol=@nix) -> `/mnt/nix`
    *   `/dev/sda2` (subvol=@persist) -> `/mnt/persist`
    *   `/dev/sda1` -> `/mnt/boot`

## 3. Applying your Configuration
1.  **Generate Hardware Config**: `nixos-generate-config --root /mnt`.
2.  **Copy your Flake**: Put it in `/mnt/etc/nixos/`.
3.  **Hardware Config Sync**: Ensure the UUIDs and Btrfs options (like `compress=zstd`) are correct in `hosts/WhoDey01/hardware-configuration.nix`. Find your partition UUIDs with:
    ```bash
    blkid
    ```
    Make sure the `@home` subvolume is mounted:
    ```nix
    fileSystems."/home" = {
      device = "/dev/disk/by-uuid/YOUR-UUID";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd" ];
    };
    ```
4.  **Impermanence Boot Script**: Already handled in `modules/nixos/core.nix` via `boot.initrd.postResumeCommands`. No action needed — just ensure the Btrfs partition is labeled `nixos` (see step 2).
5.  **Install**:
    ```bash
    nixos-install --flake /mnt/etc/nixos/#WhoDey01
    ```

## 4. Brave Subvolume Migration
To mount your *existing* Brave subvolume:
1.  Find the UUID of the drive containing the Brave subvolume:
    ```bash
    blkid
    ```
2.  Add an entry to `hardware-configuration.nix`:
    ```nix
    fileSystems."/home/ben/.config/BraveSoftware" = {
      device = "/dev/disk/by-uuid/YOUR-UUID";
      fsType = "btrfs";
      options = [ "subvol=BraveSubvolName" "compress=zstd" ];
    };
    ```

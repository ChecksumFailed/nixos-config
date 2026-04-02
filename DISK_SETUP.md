# Complex Btrfs Disk Setup & Safe Migration Plan

This document describes a safe, repeatable procedure to migrate an existing Arch Linux Btrfs layout to a NixOS installation without losing your important data (for example subvolume `@data`). It covers:

- Inspecting the existing layout
- Snapshotting / renaming the Arch `@home` to `@archhome` (non-destructive)
- Creating new NixOS subvolumes (root, blank template, nix, persist)
- Copying configs and dotfiles you forgot to include in your flake
- Backing up important subvolumes (rsync and btrfs send/receive)
- Cleaning up old subvolumes safely
- Example `hardware-configuration.nix` fragments to mount preserved subvolumes

Important safety notes
- Never run destructive commands (format, delete) until you have verified a working backup.
- A snapshot inside the same Btrfs filesystem is not a substitute for an external backup: snapshots share the same device.
- Always perform `rsync` or `btrfs send` to an external disk before deleting important subvolumes.
- Replace placeholders (e.g. `YOUR-BTRFS-UUID`) with real device identifiers from `lsblk` / `blkid` before running commands.

---

## 1. Assumptions & goals

- You have a Btrfs partition with multiple existing subvolumes including the one you want to keep (`@data`) and an Arch `@home`.
- You want to preserve `@data` and migrate to a NixOS layout.
- You prefer a non-destructive approach: create new NixOS subvolumes rather than formatting or deleting the whole partition.
- Device placeholders in all examples must be replaced with the values from your system.

---

## 2. Quick inspection (always run first)

Mount the raw partition read-only and list subvolumes to confirm names and IDs.

```new-nixos-config/DISK_SETUP.md#L401-520
# Inspect devices and subvolumes (replace /dev/sdXN)
lsblk -f
blkid
# Mount read-only to inspect subvolumes
mount -o ro /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt
btrfs subvolume list /mnt
umount /mnt
```

From your output you should identify the exact subvolume names you want to keep (e.g. `@data`, `@home`) and confirm there is free space for snapshots / new subvolumes.

---

## 3. Snapshot old `@home` as `@archhome` (non-destructive rename)

You cannot directly "rename" a subvolume; instead snapshot it to a new name. If you want an immutable backup, create a read-only snapshot.

```new-nixos-config/DISK_SETUP.md#L521-720
# Create a writable snapshot named @archhome
mount /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt
btrfs subvolume snapshot /mnt/@home /mnt/@archhome
# OR create a read-only snapshot (safer):
btrfs subvolume snapshot -r /mnt/@home /mnt/@archhome
btrfs subvolume list /mnt
umount /mnt
```

Notes:
- A writable snapshot allows you to tweak/copy files directly in the snapshot; a read-only snapshot better protects the original.
- Snapshots are metadata-light but will consume space when changes are made.

---

## 4. Create new NixOS subvolumes (recommended, non-destructive)

Create dedicated subvolumes for NixOS so you don't touch the existing Arch subvolumes.

```new-nixos-config/DISK_SETUP.md#L721-960
# Create NixOS-specific subvolumes if they don't exist yet
mount /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt
# Create NixOS root and blank template
btrfs subvolume create /mnt/@root-nixos
btrfs subvolume snapshot -r /mnt/@root-nixos /mnt/@root-nixos-blank
# Create /nix and persistent storage
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@persist
# Optionally create a snapshots directory (if you manage snapshots manually)
btrfs subvolume create /mnt/@snapshots
btrfs subvolume list /mnt
umount /mnt
```

Mount these in the installer when you perform the install:

```new-nixos-config/DISK_SETUP.md#L961-1100
# Example installation mount commands
mount -o subvol=@root-nixos,compress=zstd,noatime /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt
mkdir -p /mnt/home /mnt/nix /mnt/persist /mnt/boot
mount -o subvol=@nix,compress=zstd,noatime /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt/nix
mount -o subvol=@persist,compress=zstd,noatime /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt/persist
mount /dev/disk/by-uuid/YOUR-BOOT-UUID /mnt/boot
```

---

## 5. Copy configs and dotfiles from `@archhome` to new root

Mount both the preserved snapshot and the new NixOS root subvolume and copy data selectively.

```new-nixos-config/DISK_SETUP.md#L1101-1400
# Mount both locations
mount -o subvol=@root-nixos,compress=zstd,noatime /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt/newroot
mkdir -p /mnt/archhome
mount -o subvol=@archhome,compress=zstd,noatime /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt/archhome

# Example: copy Waybar config and dotfiles safely
rsync -aHAX --progress /mnt/archhome/ben/.config/waybar/ /mnt/newroot/home/ben/.config/waybar/
rsync -aHAX --progress /mnt/archhome/ben/.config/ /mnt/newroot/home/ben/.config/ --exclude='cache' --exclude='node_modules' --exclude='Downloads'
# Optionally copy shell dotfiles (careful with machine-specific settings)
rsync -aHAX --progress /mnt/archhome/ben/.z* /mnt/newroot/home/ben/ --exclude='.cache'

# Fix ownership for the new root
chown -R 1000:1000 /mnt/newroot/home/ben

# Unmount after copying
umount /mnt/archhome
umount /mnt/newroot
```

Tips:
- Use `--exclude` for cache, build directories, or other large transient items.
- Consider copying only specific subfolders (e.g. `.config/waybar`, `.config/hyprland`, `.config/kitty`) instead of the entire `.config` directory.

---

## 6. Back up important subvolumes externally

Snapshots inside the same filesystem are not backups. Use `rsync` to external disk or `btrfs send/receive` to another Btrfs device.

Rsync backup (generic, slower but widely supported):

```new-nixos-config/DISK_SETUP.md#L1401-1640
# Mount and rsync to external disk (mounted at /mnt/backup)
mount /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt
mount /dev/disk/by-uuid/YOUR-BACKUP-UUID /mnt/backup
rsync -aHAX --progress /mnt/@archhome/ /mnt/backup/archhome-backup/
umount /mnt
umount /mnt/backup
```

Btrfs send/receive (efficient for subvolume snapshots):

```new-nixos-config/DISK_SETUP.md#L1641-1920
# Create a read-only snapshot to send (if not already)
mount /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt
btrfs subvolume snapshot -r /mnt/@archhome /mnt/@archhome-send
# Mount destination btrfs device at /mnt/backup and receive
mount /dev/disk/by-uuid/YOUR-BACKUP-UUID /mnt/backup
btrfs send /mnt/@archhome-send | btrfs receive /mnt/backup/
# Cleanup (optional)
umount /mnt
umount /mnt/backup
```

Important:
- Verify the backup before deleting originals.
- Use checksums or manual spot checks for critical files.

---

## 7. Optional: remove old subvolumes when ready (destructive)

Only after you have external backups and verified everything, you may delete old subvolumes to reclaim space.

```new-nixos-config/DISK_SETUP.md#L1921-2160
# Deleting old subvolumes (destructive) - only after backup
mount /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt
# example: delete the old @home if you no longer need it
btrfs subvolume delete /mnt/@home
# delete large snapshot collections if you removed duplicates
btrfs subvolume delete /mnt/@snapshots/old-snapshot-name
# verify
btrfs subvolume list /mnt
umount /mnt
```

Notes:
- If you delete and free space does not immediately show as available, run `btrfs balance` or review `btrfs filesystem df` to reconcile space.
- Deletions are irreversible without external backups.

---

## 8. Example `hardware-configuration.nix` entries

Mount the preserved data and the new NixOS subvolumes in the Nix configuration. Replace UUIDs with your real values.

```new-nixos-config/DISK_SETUP.md#L2161-2440
# Mount preserved @data at /data
fileSystems."/data" = {
  device = "/dev/disk/by-uuid/YOUR-BTRFS-UUID";
  fsType = "btrfs";
  options = [ "subvol=@data" "compress=zstd" "noatime" ];
};

# Mount NixOS root (if using @root-nixos)
fileSystems."/" = {
  device = "/dev/disk/by-uuid/YOUR-BTRFS-UUID";
  fsType = "btrfs";
  options = [ "subvol=@root-nixos" "compress=zstd" "noatime" ];
};

# Mount /nix and /persist
fileSystems."/nix" = {
  device = "/dev/disk/by-uuid/YOUR-BTRFS-UUID";
  fsType = "btrfs";
  options = [ "subvol=@nix" "compress=zstd" "noatime" ];
};
fileSystems."/persist" = {
  device = "/dev/disk/by-uuid/YOUR-BTRFS-UUID";
  fsType = "btrfs";
  options = [ "subvol=@persist" "compress=zstd" "noatime" ];
  neededForBoot = true;
};
```

If you prefer to use `@root` and `@root-blank` names exactly as your flake expects, snapshot or rename accordingly (see section 9 below).

---

## 9. If you want canonical names (`@root`, `@root-blank`) for impermanence

If your flake/hook expects `@root` and `@root-blank`, you can create those names after making backups and snapshots.

Two choices:
- Create new `@root` subvolume and `@root-blank` snapshot (recommended if you are creating new NixOS root subvolume).
- Or, if you want to overwrite the existing `@root` with a new empty template, snapshot the old `@root` to a backup name (e.g. `@root-old-backup`) then create a fresh `@root` and `@root-blank`.

Example: backup old root and create fresh `@root` names.

```new-nixos-config/DISK_SETUP.md#L2441-2720
mount /dev/disk/by-uuid/YOUR-BTRFS-UUID /mnt
# Backup the old root
btrfs subvolume snapshot -r /mnt/@root /mnt/@root-old-backup
# Delete original @root only if you have external backup and are ready:
# btrfs subvolume delete /mnt/@root
# Create new empty @root and blank template
btrfs subvolume create /mnt/@root
btrfs subvolume snapshot -r /mnt/@root /mnt/@root-blank
btrfs subvolume list /mnt
umount /mnt
```

Be cautious: deleting `@root` is destructive. Prefer to snapshot and keep backups first.

---

## 10. Recommended workflow summary (safe, minimal risk)

1. Inspect and list subvolumes.
2. Snapshot `@home` to `@archhome` (read-only recommended).
3. Create new NixOS subvolumes (`@root-nixos`, `@root-nixos-blank`, `@nix`, `@persist`).
4. Mount both snapshot and new root and copy selective configs (rsync with excludes).
5. Back up `@archhome` and other important subvolumes externally (rsync or btrfs send/receive).
6. Verify the new system and copied configs.
7. After confidence, delete old subvolumes if desired.

---

## 11. Useful troubleshooting & verification commands

```new-nixos-config/DISK_SETUP.md#L2721-3000
# Useful checks
lsblk -f
blkid
findmnt -t btrfs -o TARGET,SOURCE,FSTYPE,OPTIONS
btrfs subvolume list /mnt      # after mounting raw partition
btrfs filesystem df /mnt
# For space accounting:
btrfs filesystem du -s /mnt/@archhome
```

---

## 12. Example `rsync` exclude suggestions for dotfiles / configs

- Exclude caches, builds, large binary trees you don't need:
  - `.cache`, `node_modules`, `Downloads`, `thumbs.db`, `.local/share/Trash`
- Example rsync exclude pattern:

```new-nixos-config/DISK_SETUP.md#L3001-3200
# example rsync invocation with common excludes
rsync -aHAX --progress \
  --exclude '.cache' \
  --exclude 'node_modules' \
  --exclude 'Downloads' \
  --exclude '.local/share/Trash' \
  /mnt/archhome/ben/.config/ /mnt/newroot/home/ben/.config/
```

---

## 13. Final checklist before you run destructive commands

- [ ] External backup of `@archhome` and any other important subvolumes exists and verified.
- [ ] You know the exact device UUIDs (`blkid`) you will reference in `hardware-configuration.nix`.
- [ ] You have created a read-only snapshot of any subvolume you intend to delete or replace.
- [ ] You tested mounting and copying the important configs into the new NixOS root.
- [ ] You are comfortable running `btrfs subvolume delete` only after verification.

---

If you want, I can:
- Produce a one-shot command script (copy/paste) for your exact device UUIDs — paste the output of `blkid` and I will generate the script.
- Produce a sample `hardware-configuration.nix` ready to paste with your actual UUID values filled in.
- Add `btrfs send/receive` examples tailored to your external backup device.

Stay safe — back up before deleting anything.
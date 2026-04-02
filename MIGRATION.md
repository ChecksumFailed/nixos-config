# Arch to NixOS Migration Guide (with Impermanence)

This guide documents a reproducible, safe workflow to move from an existing Arch Linux system to the modular NixOS configuration in this repository. It expands the previous notes with explicit commands, Btrfs subvolume creation, mounting details, UUID guidance, Brave profile migration options, and troubleshooting tips.

Important: follow these steps from the NixOS live ISO environment (minimal ISO recommended). Do not use the Calamares GUI installer if you plan to use a custom Btrfs layout or the impermanence pattern.

---

Table of contents
- 1) Preparation (on Arch)
- 2) Partitioning and formatting
- 3) Create Btrfs subvolumes and the blank snapshot
- 4) Mount subvolumes for installation
- 5) Preserve / migrate Brave profile (options)
- 6) Generate hardware configuration & place your flake
- 7) Update `hardware-configuration.nix` (LABEL vs UUID)
- 8) Install using your flake
- 9) Post-install verification and first boot
- 10) Troubleshooting and common errors
- 11) Safety notes and recommended workflow

---

1) Preparation (on Arch)
- Backup your `new-nixos-config` repo (zip or copy to external disk/cloud).
- Backup any important profile data (e.g. Brave, dotfiles):
  ```/dev/null/commands.sh#L1-3
  cp -r ~/.config/BraveSoftware/ /path/to/backup/Brave-profile-backup/
  tar -czf new-nixos-config-backup.tgz ~/path/to/new-nixos-config
  ```
- If you have LUKS or encryption on your current disk, ensure you know your passphrase — steps below assume unencrypted Btrfs for simplicity; if using LUKS, adapt by creating LUKS before mkfs and unlocking it (`cryptsetup open`) then run `mkfs.btrfs` on the unlocked device.

---

2) Partitioning and formatting
- Decide which disk you'll use (example uses `/dev/sda`). Confirm with:
  ```/dev/null/commands.sh#L1-4
  lsblk -f
  blkid
  ```
- Create partitions (GPT recommended):
  - Partition 1: EFI, 512MiB, FAT32, labeled `boot`
  - Partition 2: remaining space, Btrfs, will be labeled `nixos`
- Example using `parted`:
  ```/dev/null/commands.sh#L5-12
  parted /dev/sda -- mklabel gpt
  parted /dev/sda -- mkpart primary fat32 1MiB 513MiB
  parted /dev/sda -- set 1 esp on
  parted /dev/sda -- mkpart primary btrfs 513MiB 100%
  ```
- Format partitions and label them:
  ```/dev/null/commands.sh#L13-18
  mkfs.vfat -F32 -n boot /dev/sda1
  mkfs.btrfs -L nixos /dev/sda2
  # verify
  blkid /dev/sda1
  blkid /dev/sda2
  ```

Why label `nixos`?  
- The `postResumeCommands` in this repository look for a Btrfs partition labeled `nixos`. Labeling makes the wipe-and-snapshot hook work without changing the flake. You may prefer `by-uuid` in production — see section 7.

---

3) Create Btrfs subvolumes and the blank snapshot
- Mount the raw partition temporarily and create the expected subvolumes:
  ```/dev/null/commands.sh#L1-16
  # mount the raw partition
  mount /dev/disk/by-label/nixos /mnt

  # create expected subvolumes
  btrfs subvolume create /mnt/@root
  btrfs subvolume create /mnt/@home
  btrfs subvolume create /mnt/@nix
  btrfs subvolume create /mnt/@persist
  btrfs subvolume create /mnt/@snapshots

  # verify
  btrfs subvolume list /mnt
  ```
- Create the blank snapshot (CRITICAL for impermanence)
  - The blank snapshot is the template used on each (impermanent) boot to restore a pristine root filesystem.
  ```/dev/null/commands.sh#L17-22
  # make the blank snapshot read-only
  btrfs subvolume snapshot -r /mnt/@root /mnt/@root-blank

  # verify blank snapshot exists
  btrfs subvolume list /mnt
  umount /mnt
  ```
- Notes:
  - Ensure `@root` was empty when `@root-blank` was created. `-r` makes it read-only and safer as a template.
  - If you later want to update the blank snapshot (a new base system), create a writable snapshot, update it, then replace the blank snapshot accordingly (advanced workflow).

---

4) Mount subvolumes for installation
- Mount subvolumes using the `subvol` option and include the same Btrfs mount options used in the NixOS config (e.g. `compress=zstd,noatime`). Example:
  ```/dev/null/commands.sh#L1-18
  # Mount root (@root) to /mnt
  mount -o subvol=@root,compress=zstd,noatime /dev/disk/by-label/nixos /mnt

  # Create mount points for others
  mkdir -p /mnt/home /mnt/nix /mnt/persist /mnt/boot

  # Mount other subvolumes
  mount -o subvol=@home,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/home
  mount -o subvol=@nix,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/nix
  mount -o subvol=@persist,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/persist

  # Mount EFI
  mount /dev/disk/by-label/boot /mnt/boot
  ```
- Verify mounts:
  ```/dev/null/commands.sh#L19-22
  findmnt -t btrfs -o TARGET,SOURCE,FSTYPE,OPTIONS
  btrfs subvolume list /mnt
  ```

---

5) Preserve / migrate Brave profile (optional)
There are two approaches depending on whether Brave data already lives in a subvolume on the same partition or on another disk.

A) Brave profile is on the same Btrfs partition as a subvolume you want to keep:
- Find the subvolume name where Brave profile lives:
  ```/dev/null/commands.sh#L1-6
  # temporarily mount the partition (source) somewhere:
  mount /dev/sdXY /mnt2
  btrfs subvolume list -a /mnt2
  ```
- To mount that Brave subvolume directly in your NixOS layout:
  - Add a `fileSystems` entry in `hardware-configuration.nix` pointing to the partition and `subvol=NameOfBraveSubvol`.
  - Example (edit paths/UUIDs appropriately):
    ```new-nixos-config/hosts/WhoDey01/hardware-configuration.nix#L1-16
    fileSystems."/home/ben/.config/BraveSoftware" = {
      device = "/dev/disk/by-uuid/YOUR-UUID";
      fsType = "btrfs";
      options = [ "subvol=NameOfBraveSubvol" "compress=zstd" "noatime" ];
    };
    ```
  - This keeps Brave in a separate subvolume but requires adding many tiny mounts if you have multiple app profiles.

B) Brave profile on another disk or you prefer copying into new @home:
- Safer approach: copy your profile into the new `/mnt/home/ben/.config/BraveSoftware`:
  ```/dev/null/commands.sh#L1-12
  # mount both source and target and rsync
  mount /dev/sdXY /mnt2                # source disk containing Brave
  rsync -aHAX --progress /mnt2/path/to/Brave/ /mnt/home/ben/.config/BraveSoftware/
  # check ownership/permissions
  chown -R 1000:1000 /mnt/home/ben/.config/BraveSoftware
  ```
- This is easier to manage and integrates with the new @home subvolume.

Notes:
- If Brave stores encrypted or locked data (e.g. keyrings), ensure the system user (ben) and keyring services will be configured correctly on first login.
- Back up the profile before copying.

---

6) Generate hardware configuration & place your flake
- Generate the NixOS hardware configuration (this creates `/mnt/etc/nixos/hardware-configuration.nix`):
  ```/dev/null/commands.sh#L1-2
  nixos-generate-config --root /mnt
  ```
- Copy your flake and repo contents into `/mnt/etc/nixos/` so `nixos-install` can see it:
  ```/dev/null/commands.sh#L3-6
  mkdir -p /mnt/etc/nixos
  # from the host where your repo lives (adjust path)
  cp -r /path/to/new-nixos-config/* /mnt/etc/nixos/
  ```
- Edit `/mnt/etc/nixos/hosts/WhoDey01/hardware-configuration.nix` to reflect actual UUIDs/subvol options — see section 7.

---

7) Update `hardware-configuration.nix` (LABEL vs UUID)
- Using the partition LABEL (e.g. `/dev/disk/by-label/nixos`) works if you guarantee the label exists. Using UUIDs (`/dev/disk/by-uuid/<UUID>`) is more robust if device names or labels could change.
- Get UUIDs:
  ```/dev/null/commands.sh#L1-3
  blkid /dev/sda2
  lsblk -no NAME,UUID,SIZE,PARTLABEL,PARTUUID /dev/sda
  ```
- Example replacement snippet you can paste into `hosts/WhoDey01/hardware-configuration.nix` (replace `YOUR-UUID` placeholders):
  ```new-nixos-config/hosts/WhoDey01/hardware-configuration.nix#L1-40
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/YOUR-UUID-FOR-SDA2";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" "noatime" ];
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/YOUR-UUID-FOR-SDA2";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" "noatime" ];
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/YOUR-UUID-FOR-SDA2";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };
  fileSystems."/persist" = {
    device = "/dev/disk/by-uuid/YOUR-UUID-FOR-SDA2";
    fsType = "btrfs";
    options = [ "subvol=@persist" "compress=zstd" "noatime" ];
    neededForBoot = true;
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/YOUR-UUID-FOR-SDA1";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };
  ```
- Replace placeholders with values obtained with `blkid`. Using `by-uuid` ensures the correct partition is used even if multiple disks are present.

---

8) Install using your flake
- Run the installer pointing at your flake in `/mnt/etc/nixos`:
  ```/dev/null/commands.sh#L1-2
  # from live ISO shell:
  nixos-install --flake /mnt/etc/nixos#WhoDey01
  ```
- If `nixos-install` fails due to missing `hardware-configuration.nix`, edit `/mnt/etc/nixos/hosts/WhoDey01/hardware-configuration.nix` or copy the generated one from `/mnt/etc/nixos/hardware-configuration.nix` into your flake's `hosts/WhoDey01/` prior to `nixos-install`.

---

9) Post-install verification and first boot
- After `nixos-install` completes, reboot into the new system.
- On first boot:
  - If the impermanence hook is enabled (default in this repo), it will delete `@root` and snapshot `@root-blank` to `@root` — effectively restoring the blank root. If you want to debug the first boot before wiping root, comment out or temporarily disable the `boot.initrd.postResumeCommands` in `modules/nixos/core.nix` (or conditionally guard it).
  - Verify mounts:
    ```/dev/null/commands.sh#L1-4
    findmnt -t btrfs -o TARGET,SOURCE,FSTYPE,OPTIONS
    mount | grep /persist
    ```
  - Verify persistent files are stored in `/persist` (logs, Docker, SSH host keys are listed in `persistence.nix`).

---

10) Troubleshooting and common errors
- "device not found" or `nixos-install` fails to mount:
  - Check `blkid` and ensure your `hardware-configuration.nix` uses correct UUIDs or labels.
  - Ensure subvolume names match the `subvol=` options you used when mounting during install.
- Boot fails immediately after install:
  - Temporarily boot from live ISO, mount your Btrfs subvolumes and inspect `/boot` for kernel and initrd files.
  - If using the impermanence wipe hook, ensure `@root-blank` exists and `/dev/disk/by-label/nixos` resolves to the right partition.
- `btrfs subvolume list` shows unexpected names:
  - You may have created subvolumes under a path rather than root. Use `btrfs subvolume list -a /mnt` where `/mnt` is the raw partition mount to see all subvolumes and their exact names.
- SSH not starting or keys missing:
  - If `/etc/ssh` was declared persistent and you copied files, ensure the listed host keys exist under `/persist/etc/ssh` or your `environment.persistence` configuration includes these paths. Check file ownership and permissions.
- Services failing due to missing runtime files:
  - Confirm `environment.persistence` includes directories required for services that expect state in `/var/lib` and `/var/log`. Your `persistence.nix` lists many common directories, but you can add additional paths as needed.

Useful debug commands (live ISO or after boot):
```/dev/null/commands.sh#L1-10
# list all mounts and btrfs info
lsblk -f
blkid
findmnt -t btrfs -o TARGET,SOURCE,FSTYPE,OPTIONS
btrfs filesystem df /mnt   # after mounting the partition
btrfs subvolume list /mnt
```

---

11) Safety notes and recommended workflow
- First install without enabling the impermanence wipe hook (comment it out or wrap in an `if` guard). Boot once, confirm hardware, GPU drivers, and services, then enable the hook and create a fresh `@root-blank` if desired.
- Keep a backup of your flake outside the machine (USB/cloud).
- Prefer the UUID-based `hardware-configuration.nix` device entries for reliability.
- If you maintain separate disks with many subvolumes, prefer copying data into a well-structured set of subvolumes for clarity.
- When updating the blank snapshot for the impermanence template:
  - Create a writable snapshot from `@root-blank` (or from current root after provisioning), make updates, and then create a new read-only `@root-blank` replacing the previous one. Always keep a backup.

---

Appendix: quick checklist (copyable)
```/dev/null/commands.sh#L1-20
# On live ISO:
lsblk -f
blkid

# Partition:
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart primary fat32 1MiB 513MiB
parted /dev/sda -- set 1 esp on
parted /dev/sda -- mkpart primary btrfs 513MiB 100%

# Format and label:
mkfs.vfat -F32 -n boot /dev/sda1
mkfs.btrfs -L nixos /dev/sda2

# Create subvolumes:
mount /dev/disk/by-label/nixos /mnt
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@persist
btrfs subvolume create /mnt/@snapshots
btrfs subvolume snapshot -r /mnt/@root /mnt/@root-blank
umount /mnt

# Mount for install:
mount -o subvol=@root,compress=zstd,noatime /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/home /mnt/nix /mnt/persist /mnt/boot
mount -o subvol=@home,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/home
mount -o subvol=@nix,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/nix
mount -o subvol=@persist,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/persist
mount /dev/disk/by-label/boot /mnt/boot

# Generate config and copy flake:
nixos-generate-config --root /mnt
mkdir -p /mnt/etc/nixos
cp -r /path/to/new-nixos-config/* /mnt/etc/nixos/

# Edit hardware-configuration.nix to use UUIDs if desired, then:
nixos-install --flake /mnt/etc/nixos#WhoDey01
reboot
```

---

If you want, I can:
- Produce a ready-to-paste `hardware-configuration.nix` with placeholders already filled if you paste your `blkid`/`lsblk` output here.
- Walk you through migrating Brave interactively (you can paste `btrfs subvolume list` output from the source disk).
- Suggest a step-by-step first-boot checklist for enabling the impermanence hook safely.

Good luck — shout if you want me to fill in a `hardware-configuration.nix` example using your actual UUIDs or to draft a guarded version of the impermanence hook so you can test first boot safely.
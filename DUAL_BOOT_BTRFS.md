# Dual-boot NixOS + Arch on a single Btrfs partition

NixOS alongside Arch Linux on the same Btrfs partition (`/dev/nvme0n1p2`), with separate home subvolumes and a shared `@data` subvolume. Limine (Arch's bootloader) stays in charge of the UEFI boot order and chainloads systemd-boot for NixOS.

**Safety note:** Back up important data before starting. Subvolume operations are non-destructive but snapshots on the same device are not a substitute for an external backup.

---

## Devices

| Role | Device | UUID |
|------|--------|------|
| ESP (FAT32) | `/dev/nvme0n1p1` | `0367-C1BF` |
| Btrfs partition | `/dev/nvme0n1p2` | `ea08e3ac-27b5-4825-9fad-94421b4855ac` |

---

## Table of contents

1. Subvolume layout
2. Create NixOS subvolumes
3. Mount subvolumes for installation
4. Clone flake and run installer
5. Limine: chainload systemd-boot for NixOS
6. Kernel / initrd upgrades (automatic with systemd-boot)
7. Sharing data and separate homes
8. Troubleshooting
9. Final checklist

---

## 1) Subvolume layout

| Subvolume | Mount point | OS |
|-----------|-------------|----|
| `@` | `/` | Arch |
| `@home` | `/home` | Arch |
| `@nixos` | `/` | NixOS |
| `@nixos-home` | `/home` | NixOS |
| `@nix` | `/nix` | NixOS |
| `@data` | `/data` | Shared |

Verify current subvolumes on your machine before creating anything:

```bash
mount -o ro /dev/nvme0n1p2 /mnt
btrfs subvolume list /mnt
umount /mnt
```

---

## 2) Create NixOS subvolumes (non-destructive)

```bash
mount /dev/disk/by-uuid/ea08e3ac-27b5-4825-9fad-94421b4855ac /mnt

btrfs subvolume create /mnt/@nixos
btrfs subvolume create /mnt/@nixos-home
btrfs subvolume create /mnt/@nix

# Skip if @data already exists
btrfs subvolume create /mnt/@data

# Verify
btrfs subvolume list /mnt

umount /mnt
```

---

## 3) Mount subvolumes for installation

Run from a NixOS live ISO.

```bash
# Root
mount -o subvol=@nixos,compress=zstd,noatime \
  /dev/disk/by-uuid/ea08e3ac-27b5-4825-9fad-94421b4855ac /mnt

# Other mountpoints
mkdir -p /mnt/home /mnt/nix /mnt/boot /mnt/data

mount -o subvol=@nixos-home,compress=zstd,noatime \
  /dev/disk/by-uuid/ea08e3ac-27b5-4825-9fad-94421b4855ac /mnt/home

mount -o subvol=@nix,compress=zstd,noatime \
  /dev/disk/by-uuid/ea08e3ac-27b5-4825-9fad-94421b4855ac /mnt/nix

mount -o subvol=@data,compress=zstd,noatime \
  /dev/disk/by-uuid/ea08e3ac-27b5-4825-9fad-94421b4855ac /mnt/data

# ESP — shared with Arch, do not format
mount /dev/disk/by-uuid/0367-C1BF /mnt/boot
```

Confirm:

```bash
findmnt | grep /mnt
```

---

## 4) Clone flake and run installer

```bash
# Clone repo
git clone https://github.com/YOUR-USER/new-nixos-config.git /tmp/nixos-config

# Sync into target
rsync -a --delete /tmp/nixos-config/ /mnt/etc/nixos/
chown -R root:root /mnt/etc/nixos

# Install
nixos-install --flake /mnt/etc/nixos#WhoDey01
```

`nixos-install` will:
- Build the system closure
- Populate `/mnt/nix/store`
- Install systemd-boot to `/mnt/boot/EFI/systemd/systemd-bootx64.efi`
- Write boot entries to `/mnt/boot/loader/entries/`

Do **not** reboot into NixOS yet — add the Limine entry first.

---

## 5) Limine: chainload systemd-boot for NixOS

NixOS uses systemd-boot as its bootloader. Limine stays as the primary UEFI entry and chainloads systemd-boot when you want NixOS. This works because `canTouchEfiVariables = false` is set in the NixOS config, so systemd-boot won't overwrite Limine's NVRAM entry.

### 5.1 Verify systemd-boot was installed

```bash
ls /mnt/boot/EFI/systemd/systemd-bootx64.efi
ls /mnt/boot/loader/entries/
```

You should see at least one `.conf` file in `entries/`.

### 5.2 Find your Limine config

```bash
# From Arch (after rebooting back or from chroot)
find /boot -name "limine.cfg" 2>/dev/null
```

It is typically at `/boot/limine.cfg` or `/boot/EFI/limine/limine.cfg`.

### 5.3 Add a chainload entry

Add this to `limine.cfg`:

```ini
/NixOS
    COMMENT=NixOS (via systemd-boot)
    PROTOCOL=chainload
    IMAGE_PATH=boot():/EFI/systemd/systemd-bootx64.efi
```

> `boot()` tells Limine to look on the same partition as the config file (the ESP). The path `/EFI/systemd/systemd-bootx64.efi` is where NixOS installs systemd-boot.

### 5.4 Verify before rebooting

```bash
ls /boot/EFI/systemd/systemd-bootx64.efi
cat /boot/limine.cfg | grep -A4 NixOS
```

Reboot → select "NixOS" from Limine → systemd-boot appears → select NixOS generation → boots.

---

## 6) Kernel / initrd upgrades (automatic)

The chainload approach means **you never need to manually copy kernels**. After each `nixos-rebuild switch`:

- systemd-boot entries in `/boot/loader/entries/` are updated automatically by NixOS
- Old generations remain selectable from the systemd-boot menu
- Limine's entry never changes — it always just chainloads systemd-boot

Nothing extra to do after upgrades.

---

## 7) Sharing data and separate homes

- Mount `@data` at `/data` on both Arch and NixOS — already in `hardware-configuration.nix`.
- Keep per-OS home subvolumes (`@home` for Arch, `@nixos-home` for NixOS) entirely separate. Do **not** share `~/.config`.
- Use identical UIDs for the same user on both OSes (UID 1000) to avoid ownership conflicts on `/data`.
- Symlink or bind-mount selective folders (`~/Documents`, `~/Games`, etc.) into `/data` on each OS.

Arch `/etc/fstab` entry for `@data`:

```
UUID=ea08e3ac-27b5-4825-9fad-94421b4855ac  /data  btrfs  subvol=@data,compress=zstd,noatime  0 0
```

---

## 8) Troubleshooting

**Limine doesn't show NixOS entry**
- Confirm the entry was saved to the correct `limine.cfg` (there may be multiple copies on the ESP).
- Run `limine bios-install` or `limine uefi-install` from Arch if the config needs a refresh.

**systemd-boot shows no entries after chainload**
- Confirm `/boot/loader/entries/*.conf` files exist.
- Confirm `/boot/EFI/nixos/` contains the kernel/initrd referenced by those entries.

**NixOS kernel panics: can't mount root**
- Verify `hardware-configuration.nix` UUID is `ea08e3ac-27b5-4825-9fad-94421b4855ac` and subvol is `@nixos` for `/`.
- From rescue shell: `mount -o subvol=@nixos /dev/disk/by-uuid/ea08e3ac-27b5-4825-9fad-94421b4855ac /mnt` — if this fails, the subvolume doesn't exist yet.

**systemd-boot stomped Limine's NVRAM entry**
- Should not happen with `canTouchEfiVariables = false` in `core.nix`.
- If it does: `efibootmgr --list`, find Limine's entry, restore order with `efibootmgr --bootorder XXXX,...`.

**Verify mounts on running NixOS system**

```bash
findmnt -t btrfs -o TARGET,SOURCE,OPTIONS
btrfs subvolume list /
```

---

## 9) Final checklist

- [ ] Btrfs subvolumes created: `@nixos`, `@nixos-home`, `@nix`, `@data`
- [ ] All subvolumes mounted under `/mnt` with ESP at `/mnt/boot`
- [ ] Flake cloned/synced into `/mnt/etc/nixos`
- [ ] `nixos-install --flake /mnt/etc/nixos#WhoDey01` completed successfully
- [ ] `/boot/EFI/systemd/systemd-bootx64.efi` exists on ESP
- [ ] `/boot/loader/entries/` contains NixOS boot entries
- [ ] Limine `chainload` entry added to `limine.cfg` pointing to `/EFI/systemd/systemd-bootx64.efi`
- [ ] Booted NixOS successfully via Limine → systemd-boot
- [ ] Arch still boots normally from Limine
- [ ] `/data` subvolume accessible from both OSes

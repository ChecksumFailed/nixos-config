# NixOS Config
My first attempt at NixOS.  Built using a combination of Gemini, Copilot, and google-fu

## Stack

- **OS**: NixOS 24.11
- **WM**: Hyprland (Wayland)
- **Bar**: Waybar
- **Launcher**: Rofi
- **Terminal**: Kitty
- **Shell**: Zsh + Starship
- **Display Manager**: SDDM
- **Impermanence**: Btrfs root wipe on every boot via `@root-blank` snapshot

## Structure

```
flake.nix
hosts/
  WhoDey01/           # Host-specific config and hardware
modules/
  nixos/              # System-level modules (boot, desktop, gaming, services, persistence)
  home-manager/       # User-level modules (shell, desktop apps, Hyprland config)
users/
  ben/
    home.nix          # Home Manager entry point
```

## Usage

Rebuild and switch:
```bash
sudo nixos-rebuild switch --flake .#WhoDey01
```

Build without switching:
```bash
nixos-rebuild build --flake .#WhoDey01
```

## Installation

See [MIGRATION.md](MIGRATION.md) for full installation instructions including Btrfs partitioning and impermanence setup.

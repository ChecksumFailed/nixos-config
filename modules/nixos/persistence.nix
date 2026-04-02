{ config, pkgs, lib, ... }:

{
  # This sets up the @persist subvolume to hold system-level persistent data
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      "/var/lib/docker"
    ];
    files = [
      "/etc/machine-id"
      "/etc/shadow"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];
  };

  # Since / is wiped, we need to make sure certain files are linked correctly
  security.sudo.keepTerminfo = true;
}

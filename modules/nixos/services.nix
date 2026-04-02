{ config, pkgs, ... }:

{
  # Audio (Pipewire)
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  # Bluetooth
  services.blueman.enable = true;
  hardware.bluetooth.enable = true;

  # Stream Deck
  programs.streamdeck-ui.enable = true;

  # Other services
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  # SSH Agent
  programs.ssh.startAgent = true;

  # Insecure packages (sometimes needed for older Electron apps)
  nixpkgs.config.permittedInsecurePackages = [
    "electron-33.4.11"
  ];
}

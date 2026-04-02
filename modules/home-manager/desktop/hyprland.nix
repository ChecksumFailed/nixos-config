{ config, pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$menu" = "rofi -show drun";
      "$fileManager" = "nautilus";

      monitor = [
        "DP-3,2560x1440@74.92,0x0,1.0"
        "DP-1,3440x1440@144.0,2560x0,1.0"
        ",preferred,auto,1"
      ];

      exec-once = [
        "waybar"
        "swaync"
        "nm-applet --indicator"
        "blueman-applet"
        "hypridle"
        "hyprpaper"
        "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent"
        "${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets,pkcs11,ssh"
        "wl-paste --watch cliphist store"
      ];

      input = {
        kb_layout = "us";
        numlock_by_default = true;
        follow_mouse = 1;
        mouse_refocus = false;
        sensitivity = 0;
      };

      general = {
        gaps_in = 2;
        gaps_out = 2;
        border_size = 1;
        "col.active_border" = "rgb(e1c46d)";
        "col.inactive_border" = "rgb(eae2d4)";
        layout = "dwindle";
        resize_on_border = true;
      };

      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 0.9;
        
        blur = {
          enabled = true;
          size = 4;
          passes = 4;
        };

        shadow = {
          enabled = true;
          range = 32;
          color = "rgba(00000050)";
        };
      };

      animations = {
        enabled = true;
        # ... (simplified for now, can add more later if needed)
      };

      # Keybinds
      bind = [
        "$mod, RETURN, exec, $terminal"
        "$mod, SPACE, exec, $menu"
        "$mod, Q, killactive"
        "$mod, E, exec, $fileManager"
        "$mod, B, exec, brave"
        "$mod, F, fullscreen, 0"
        "$mod, T, togglefloating"
        
        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"

        # Media keys
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", Print, exec, grim -g \"$(slurp)\" - | wl-copy"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  # Dependency packages
  home.packages = with pkgs; [
    hyprpaper
    hypridle
    hyprlock
    hyprpolkitagent
    swaynotificationcenter
    libnotify
    gnome-keyring
    networkmanagerapplet
  ];
}

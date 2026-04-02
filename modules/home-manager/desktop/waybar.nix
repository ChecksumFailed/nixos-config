{ config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "cpu" "memory" "tray" ];

        "hyprland/workspaces" = {
          on-click = "activate";
          format = "{}";
        };

        "clock" = {
          format = "{:%Y-%m-%d %I:%M %p}";
        };

        "pulseaudio" = {
          format = "{icon} {volume}%";
          format-icons = {
            default = [ "" " " " " ];
          };
          on-click = "pavucontrol";
        };
        
        "cpu" = { format = "C {usage}%"; };
        "memory" = { format = "M {}%"; };
      };
    };
    # Simplified style for now, can be expanded
    style = ''
      * {
          font-family: "JetBrainsMono Nerd Font";
          font-size: 14px;
      }
      window#waybar {
          background-color: rgba(30, 30, 46, 0.8);
          color: #cdd6f4;
      }
      #workspaces button {
          color: #cdd6f4;
      }
      #workspaces button.active {
          color: #e1c46d;
      }
    '';
  };
}

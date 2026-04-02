{ pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "Ben";
    userEmail = "ben@users.noreply.github.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
}

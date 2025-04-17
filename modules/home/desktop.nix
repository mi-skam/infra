{pkgs, ...}:

{

  imports = [
    ./common.nix
  ];

  programs = {
    firefox.enable = true;
    ghostty.enable = true;
    vscode.enable = true;
  };

  home.packages = with pkgs; [
    bitwarden-desktop
    brave
    freecad-wayland
    obsidian
    signal-desktop
    spotify-qt
    kdePackages.kasts
  ];

}

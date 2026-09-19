{ config, pkgs, ... }:

{
  users.users.temidaradev = {
    isNormalUser = true;
    description = "temidaradev";
    extraGroups = [ "networkmanager" "wheel" "docker" "plugdev" "input" "uinput" ];
    shell = pkgs.zsh;
  };

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/temidaradev/.dotfiles/";
  };

  programs.firefox.enable = true;
  programs.zsh.enable = true;
}

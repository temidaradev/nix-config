{ config, pkgs, ... }:

{
  programs.appimage = {
    enable = true;
    binfmt = true;
    # Extra libs for AppImages that don't bundle them (e.g. Amadeus needs libgpg-error).
    package = pkgs.appimage-run.override {
      extraPkgs = pkgs: with pkgs; [
        libgpg-error
        libgcrypt
      ];
    };
  };
}

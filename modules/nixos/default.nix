{ ... }:

{
  imports = [
    ../home/git.nix
    ../shared/fonts.nix
    ../shared/nix-settings.nix
    ./boot
    ./desktop
    ./discord
    ./gaming
    ./hardware
    ./networking
    ./services
    ./system
    ./users
    ./virtualization
  ];
}

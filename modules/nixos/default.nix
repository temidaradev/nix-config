{ ... }:

{
  imports = [
    ../home/git.nix
    ../shared/fonts.nix
    ../shared/nix-settings.nix
    ./boot
    ./desktop
    ./gaming
    ./hardware
    ./networking
    ./services
    ./system
    ./users
    ./virtualization
  ];
}

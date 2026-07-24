{ ... }:

{
  imports = [
    ../home/git.nix
    ../shared/fonts.nix
    ../shared/nix-settings.nix
    ../nixos/discord
    ./homebrew
    ./services
    ./system
    ./users
  ];
}

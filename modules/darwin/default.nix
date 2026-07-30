{ ... }:

{
  imports = [
    ../home/git.nix
    ../shared/fonts.nix
    ../shared/nix-settings.nix
    ./homebrew
    ./services
    ./system
    ./users
  ];
}

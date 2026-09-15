{ ... }:

{
  imports = [
    ../home/git.nix
    ../shared/fonts.nix
    ../shared/nix-settings.nix
    ./homebrew
    ./keyboard
    ./services
    ./system
    ./users
  ];
}

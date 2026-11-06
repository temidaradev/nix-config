{ ... }:

{
  imports = [
    ../home/git.nix
    ../shared/fonts.nix
    ../shared/nix-settings.nix
    ./homebrew
    ./keyboard
    ./services
    ./sketchybar
    ./system
    ./users
  ];
}

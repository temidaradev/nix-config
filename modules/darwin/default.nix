{ ... }:

{
  imports = [
    ../home/git.nix
    ../shared/fonts.nix
    ./homebrew
    ./services
    ./system
    ./users
  ];
}

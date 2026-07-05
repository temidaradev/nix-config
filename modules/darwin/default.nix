{ ... }:

{
  imports = [
    ../home/git.nix
    ./homebrew
    ./services
    ./system
    ./users
  ];
}

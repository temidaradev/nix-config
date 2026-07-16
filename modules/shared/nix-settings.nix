{ pkgs, flakeInputs, ... }:

{
  # Pin the system registry + NIX_PATH to this flake's nixpkgs:
  # `nix run nixpkgs#foo` and legacy <nixpkgs> tools reuse the locked input
  # instead of fetching a fresh nixpkgs every time.
  nix.registry.nixpkgs.flake = flakeInputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${flakeInputs.nixpkgs}" ];

  # Flakes only, no channels.
  nix.channel.enable = false;

  environment.systemPackages = [
    pkgs.nix-index
    pkgs.nix-output-monitor
  ];
}

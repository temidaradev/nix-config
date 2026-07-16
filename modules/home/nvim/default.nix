{ pkgs, flakeInputs, ... }:

let
  # Standalone Neovim built with nvf (github:notashelf/nvf).
  # The whole config lives in ./nvf.nix as nvf's `vim.*` options.
  nvim =
    (flakeInputs.nvf.lib.neovimConfiguration {
      inherit pkgs;
      modules = [ ./nvf.nix ];
    }).neovim;
in
{
  environment.systemPackages = [ nvim ];
}

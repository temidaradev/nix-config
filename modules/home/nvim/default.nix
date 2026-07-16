{ pkgs, hmUsername, ... }:

{
  hjem.users.${hmUsername} = {
    # neovim itself comes from modules/shared/packages.nix.
    # NvChad-based config, kept in-repo under ./config.
    # Note: the deployed directory is a read-only store symlink, so lazy.nvim
    # can't rewrite lazy-lock.json in place — update it here in the repo and
    # rebuild instead.
    xdg.config.files."nvim".source = ./config;
  };
}

{ pkgs, ... }:

let
  username = if pkgs.stdenv.isDarwin then "lidldev" else "temidaradev";
in
{
  # git.nix is system-level (GIT_CONFIG_SYSTEM) and already imported by
  # modules/darwin and modules/nixos.
  imports = [
    ./shell.nix
    ./nushell.nix
    ./jj.nix
    ./helix.nix
    ./tools.nix
    ./claude-code.nix
    ./ghostty
    ./nvim
    ./dotfiles
  ];

  # Make the per-platform username available to the other home modules.
  _module.args.hmUsername = username;

  hjem.users.${username} = {
    enable = true;
    clobberFiles = true;
  };
}

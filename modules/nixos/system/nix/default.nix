{ config, pkgs, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org"
      "https://symbolics.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "symbolics.cachix.org-1:Wdgpxequ4fzP4FAckIf4MqMG9OpNxWz6CttNwiGf4AI="
    ];
  };

  programs.nix-ld.enable = true;
}

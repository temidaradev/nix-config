{ config, pkgs, ... }:

{
  services.cloudflare-warp.enable = false;

  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];
}

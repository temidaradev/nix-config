{ config, pkgs, ...}:

{
  services.mullvad-vpn.enable = true;
  services.mullvad-vpn.gui.enable = true;
}

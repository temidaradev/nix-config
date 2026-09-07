{ lib, config, pkgs, ... }:

{
  config = lib.mkIf (config.temidaradev.role == "desktop") {
  virtualisation.vmware.host.enable = true;
  };
}

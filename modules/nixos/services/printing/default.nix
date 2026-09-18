{ config, lib, pkgs, ... }:

{
  services.printing.enable = config.temidaradev.role == "desktop";
}

{ lib, ... }:

{
  # Which kind of machine this is. Desktop-only modules (xmrig, samba, VMware,
  # OpenTabletDriver) and laptop-only ones (power, fingerprint, lid) key off it.
  options.temidaradev.role = lib.mkOption {
    type = lib.types.enum [ "desktop" "laptop" ];
    default = "desktop";
    description = "Machine role; selects desktop- or laptop-specific modules.";
  };
}

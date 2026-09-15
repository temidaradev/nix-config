{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.callPackage ./vial.nix { })
  ];
}

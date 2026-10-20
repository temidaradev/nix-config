{ lib, pkgs, ... }:

let
  # Remove once these packages generate module certificates in nixpkgs.
  # Their custom install phases bypass Kbuild's module signing rule.
  withModuleCertificates = package: package.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      while IFS= read -r -d $'\0' module; do
        if [[ ! -e "$module.cer" ]]; then
          ${lib.getExe pkgs.buildPackages.kmodigest} "$module"
        fi
      done < <(find "$out/lib/modules" -type f -name '*.ko' -print0)
    '';
  });
in
{
  boot.loader.efi.canTouchEfiVariables = true;
  
  boot.kernelPackages = pkgs.linuxPackages_latest.extend (_final: prev: {
    openrazer = withModuleCertificates prev.openrazer;
    vmware = withModuleCertificates prev.vmware;
  });


  boot.loader = {
    timeout = 10;

    efi = {
      efiSysMountPoint = "/boot";
    };

    grub.enable = false;
    systemd-boot = {
      enable = true;
      configurationLimit = 3;
    };
  };
}

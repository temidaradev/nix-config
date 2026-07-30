{ pkgs, hmUsername, ... }:

# Add widevine support, see:
# https://github.com/imputnet/helium/issues/116#issuecomment-3668370766
#
# The hint file is a Linux-only Chromium mechanism, and widevine-cdm is
# x86_64-linux/aarch64-linux only, so this is skipped on Darwin.
{
  hjem.users.${hmUsername} = pkgs.lib.mkIf pkgs.stdenv.isLinux {
    xdg.config.files."net.imput.helium/WidevineCdm/latest-component-updated-widevine-cdm".text = ''
      {"Path":"${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm"}
    '';
  };
}

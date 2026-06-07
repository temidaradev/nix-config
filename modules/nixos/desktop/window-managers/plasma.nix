{ ... }:

{
  services.desktopManager.plasma6.enable = true;

  environment.sessionVariables.KWIN_DRM_NO_DIRECT_SCANOUT = "1";
}

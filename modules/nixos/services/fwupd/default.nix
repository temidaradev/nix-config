{ config, pkgs, ... }:

{
  services.fwupd.enable = true;

  # fwupd-refresh.service runs as a sandboxed DynamicUser, which polkit treats
  # as an inactive session and denies the auth_admin-gated refresh-remote action
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.fwupd.refresh-remote" &&
          subject.user == "fwupd-refresh") {
        return polkit.Result.YES;
      }
    });
  '';
}

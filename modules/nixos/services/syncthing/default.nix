{ config, lib, pkgs, ... }:

{
  services.syncthing = {
    enable = config.temidaradev.role == "desktop";
    user = "temidaradev";
    group = "users";
    dataDir = "/home/temidaradev";
    configDir = "/home/temidaradev/.config/syncthing";
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = false;
    guiAddress = "127.0.0.1:8384";
  };
}

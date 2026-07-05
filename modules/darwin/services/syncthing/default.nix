{ config, pkgs, ... }:

{
  services.syncthing = {
    enable = true;
    user = "lidldev";
    dataDir = "/Users/lidldev";
    configDir = "/Users/lidldev/Library/Application Support/Syncthing";
    overrideDevices = false;
    overrideFolders = false;
    guiAddress = "127.0.0.1:8384";
  };
}

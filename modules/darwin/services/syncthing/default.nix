{ config, pkgs, ... }:

{
  launchd.user.agents.syncthing = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.syncthing}/bin/syncthing"
        "serve"
        "--no-browser"
        "--no-restart"
        "--gui-address=127.0.0.1:8384"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Background";
    };
  };
}

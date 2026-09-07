{ config, lib, pkgs, ... }:

{
  config = lib.mkIf (config.temidaradev.role == "desktop") {
  systemd.tmpfiles.rules = [
    "d /var/lib/samba/usershares 0755 temidaradev users -"
  ];

  environment.etc."samba/smbusers".text = ''
    nobody = guest
  '';

  services.samba = {
    enable = true;
    openFirewall = true;
    winbindd.enable = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = config.networking.hostName;
        "netbios name" = config.networking.hostName;
        security = "user";
        "use sendfile" = "yes";
        "max protocol" = "SMB3";
        "min protocol" = "SMB2";
        "hosts allow" = "192.168.0.0/16 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "Bad User";
        "usershare path" = "/var/lib/samba/usershares";
        "usershare max shares" = "100";
        "usershare allow guests" = "yes";
        "usershare owner only" = "no";
        "usershare prefix allow list" = "/mnt /home";
        "usershare template share" = "1TB-HDD";
        "idmap config * : backend" = "tdb";
        "idmap config * : range" = "3000-7999";
        "username map" = "/etc/samba/smbusers";
      };
      "1TB-HDD" = {
        path = "/mnt/1TB-HDD";
        browseable = "yes";
        public = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "guest only" = "yes";
        "create mask" = "0777";
        "directory mask" = "0777";
        "force user" = "temidaradev";
        "force group" = "users";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
  };
}

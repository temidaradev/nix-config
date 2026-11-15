# Steins;Gate wallpapers for the shell's Steins;Gate mode, fetched from
# wallhaven at build time (pinned by hash) rather than committed: the art
# belongs to its artists / MAGES., this repo is public. Shown in the wallpaper
# picker while the Steins;Gate theme is on; add your own under
# ~/Pictures/Wallpapers/steinsgate.
{ pkgs }:

let
  wall = name: path: hash: {
    name = name + "." + (pkgs.lib.last (pkgs.lib.splitString "." path));
    path = pkgs.fetchurl { url = "https://w.wallhaven.cc/full/${path}"; inherit hash; };
  };
in
pkgs.linkFarm "steinsgate-wallpapers" [
  (wall "kurisu-gears" "0w/wallhaven-0wdv67.png" "sha256-aPJ5WFqJjhHrv4WCY/wJmKbdK0S/BTdz/ywBZEC7Vgw=")
  (wall "nixie"        "vg/wallhaven-vgmjzp.jpg" "sha256-QIsbQhUAf3PdWIAK51UoxcWHpolcS/phXUMsn4slbXY=")
  (wall "lab-mems"     "j8/wallhaven-j829k5.png" "sha256-9+t6LnyjDPt/0mgnL1iupsJnV5JMabiu1673Czonebg=")
  (wall "lab-table"    "jx/wallhaven-jxl9kq.jpg" "sha256-aOLVU+TKaqOigX3nASAjKMh/B+jXEZvBlZkCVqqQqvQ=")
  (wall "crt-lab"      "3k/wallhaven-3k2m6v.jpg" "sha256-wmpAphdK5SOL7WgyQ24+Zq7DJ7cmBnstrsahzKYwi4M=")
  (wall "monitors"     "42/wallhaven-42x69y.jpg" "sha256-OxdcQrX9JJdn/3QN5pqaFXM5yXKOdwBuzygmcCP+lkc=")
  (wall "sparks"       "w8/wallhaven-w826w7.jpg" "sha256-CBNKpiOz6UfJOKCHRPQhubOTN93beUX3NRcUPVqa7sg=")
  (wall "silhouette"   "5d/wallhaven-5dg579.png" "sha256-nTeSgt4l/2GIsVPnXzDkydKcqbhHnGbsXU1WnRBUCfg=")
  (wall "kurisu-crowd" "n6/wallhaven-n61re7.jpg" "sha256-ko+13Hl/O3kwUVnFWV7VBduf51AfJv56xJB0Smhlu4w=")
  (wall "gears-duo"    "4d/wallhaven-4dpl8g.jpg" "sha256-Lw+RGHoIArEc1CaHoAj6CnbOC257nwrn7Mb7YOmRTnE=")
  (wall "autumn"       "nm/wallhaven-nm81m0.jpg" "sha256-Jb0tyVfJyPJNT7nzdvvdUo33B8HIVIl0tWMd0zls1Ro=")
  (wall "suzuha"       "49/wallhaven-49wk8x.jpg" "sha256-lhLeQLls8FCht1wi1P8ZThLCWFe9noCy82QQjgTD4xk=")
]

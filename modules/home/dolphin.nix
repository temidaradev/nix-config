{ pkgs, ... }:

{
  home.packages = with pkgs.kdePackages; [
    breeze
    breeze-icons
  ];

  qt = {
    enable = true;
    platformTheme.name = "kde";
    style.name = "breeze";
  };

  xdg.configFile."kdeglobals".source =
    pkgs.runCommandLocal "kdeglobals" { } ''
      cat ${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors > $out
      cat >> $out <<'EOF'

      [KDE]
      widgetStyle=Breeze

      [Icons]
      Theme=breeze-dark
      EOF
    '';
}

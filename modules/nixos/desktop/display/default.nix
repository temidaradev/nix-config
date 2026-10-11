{ config, pkgs, ... }:

let
  gruvbox-sddm = pkgs.sddm-astronaut.override {
    embeddedTheme = "astronaut";
    themeConfig = {
      Background = "";
      BackgroundColor = "#1d2021";
      DimBackgroundColor = "#1d2021";
      FormBackgroundColor = "#282828";
      HaveFormBackground = "true";
      PartialBlur = "false";

      HeaderTextColor = "#ebdbb2";
      DateTextColor = "#a89984";
      TimeTextColor = "#ebdbb2";

      LoginFieldBackgroundColor = "#3c3836";
      PasswordFieldBackgroundColor = "#3c3836";
      LoginFieldTextColor = "#ebdbb2";
      PasswordFieldTextColor = "#ebdbb2";
      PlaceholderTextColor = "#928374";
      UserIconColor = "#ebdbb2";
      PasswordIconColor = "#ebdbb2";

      LoginButtonBackgroundColor = "#d79921";
      LoginButtonTextColor = "#282828";

      SystemButtonsIconsColor = "#ebdbb2";
      SessionButtonTextColor = "#ebdbb2";
      VirtualKeyboardButtonTextColor = "#ebdbb2";

      DropdownTextColor = "#ebdbb2";
      DropdownBackgroundColor = "#282828";
      DropdownSelectedBackgroundColor = "#504945";

      HighlightTextColor = "#fbf1c7";
      HighlightBackgroundColor = "#458588";
      HighlightBorderColor = "#458588";

      HoverUserIconColor = "#fabd2f";
      HoverPasswordIconColor = "#fabd2f";
      HoverSystemButtonsIconsColor = "#fabd2f";
      HoverSessionButtonTextColor = "#fabd2f";
      HoverVirtualKeyboardButtonTextColor = "#fabd2f";

      WarningColor = "#fb4934";
    };
  };
in
{
  services.xserver.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "sddm-astronaut-theme";
    extraPackages = gruvbox-sddm.propagatedBuildInputs;
    settings.Users.RememberLastSession = false;
  };

  # SDDM prefers its saved session over services.displayManager.defaultSession.
  # Clear an existing choice so the configured default is selected on startup.
  systemd.services.display-manager.preStart = ''
    if [ -f /var/lib/sddm/state.conf ]; then
      ${pkgs.gnused}/bin/sed -i '/^Session=/d' /var/lib/sddm/state.conf
    fi
  '';

  environment.systemPackages = with pkgs; [
    gruvbox-sddm
  ];

  services.libinput.enable = true;

  services.xserver.xkb = {
    layout = "us,tr";
    variant = "";
  };

  console.keyMap = "us";
}

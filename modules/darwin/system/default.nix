{ pkgs, config, lib, ... }:

let
  inherit (lib) mkAfter;
in

{
  nix.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@admin" ];
  };

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 14d";
  };

  time.timeZone = "Europe/Istanbul";

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      ApplePressAndHoldEnabled = false;
      AppleShowAllFiles = true;
      AppleShowAllExtensions = true;
      "com.apple.springing.enabled" = true;
      "com.apple.springing.delay" = 0.0;
    };
    CustomSystemPreferences = {
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.AdLib" = {
        allowApplePersonalizedAdvertising = false;
        allowIdentifierForAdvertising = false;
        forceLimitAdTracking = true;
        personalizedAdsMigrated = false;
      };
    };
    dock = {
      autohide = true;
      orientation = "bottom";
      tilesize = 48;
      show-recents = false;
      mru-spaces = false;
    };
    screencapture = {
      location = "~/Pictures/screenshots";
      type = "png";
      disable-shadow = true;
    };
    menuExtraClock.ShowSeconds = true;
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      FXEnableExtensionChangeWarning = false;
      NewWindowTarget = "Home";
      FXPreferredViewStyle = "Nlsv";
    };
    loginwindow = {
      DisableConsoleAccess = true;
      GuestEnabled = false;
    };
    LaunchServices.LSQuarantine = false;
  };

  system.activationScripts.postActivation.text = mkAfter ''
    echo "unhiding ${config.users.users.${config.system.primaryUser}.home}/Library..."
    /usr/bin/chflags nohidden ${config.users.users.${config.system.primaryUser}.home}/Library

    # screencapture silently falls back to Desktop if the target dir is missing
    /usr/bin/install -d -o ${config.system.primaryUser} -g staff \
      ${config.users.users.${config.system.primaryUser}.home}/Pictures/screenshots
  '';
}

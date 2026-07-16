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

  nix.optimise.automatic = true;

  time.timeZone = "Europe/Istanbul";

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  security.sudo.extraConfig = ''
    Defaults lecture = never
    Defaults pwfeedback
    Defaults env_keep += "EDITOR PATH"
  '';

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

      # Full keyboard access: tab through all controls in dialogs
      AppleKeyboardUIMode = 3;

      # Jump to the spot that was pressed in the scrollbar
      AppleScrollerPagingBehavior = true;

      # CMD+CTRL click anywhere in a window to drag it
      NSWindowShouldDragOnGesture = true;
      NSWindowResizeTime = 0.003;

      # Kill "smart" text mangling
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;

      # Expand save/print panels by default
      NSNavPanelExpandedStateForSaveMode = true;
      PMPrintingExpandedStateForPrint = true;

      # Don't switch workspaces implicitly when an app activates
      AppleSpacesSwitchOnActivate = false;

      # Save to disk, not iCloud, by default
      NSDocumentSaveNewDocumentsToCloud = false;

      # Faster trackpad tracking
      "com.apple.trackpad.scaling" = 1.5;

      # 24h time + metric
      AppleICUForce24HourTime = true;
      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
      AppleTemperatureUnit = "Celsius";
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
      # Require password immediately after screensaver/sleep
      "com.apple.screensaver" = {
        askForPassword = 1;
        askForPasswordDelay = 0;
      };
      # Kill dock/mission-control animations, disable hot corners
      "com.apple.dock" = {
        autohide-time-modifier = 0.0;
        autohide-delay = 0.0;
        expose-animation-duration = 0.0;
        springboard-show-duration = 0.0;
        springboard-hide-duration = 0.0;
        springboard-page-duration = 0.0;
        launchanim = 0;
        wvous-tl-corner = 0;
        wvous-tr-corner = 0;
        wvous-bl-corner = 0;
        wvous-br-corner = 0;
      };
      "com.apple.finder" = {
        DisableAllAnimations = true;
        # Default Finder search scope: current folder
        FxDefaultSearchScope = "SCcf";
        WarnOnEmptyTrash = false;
      };
      # Dim keyboard backlight after 60s idle
      "com.apple.CoreBrightness" = {
        "Keyboard Dim Time" = 60;
        KeyboardBacklight.KeyboardBacklightIdleDimTime = 60;
      };
      # Maccy clipboard manager (installed via homebrew cask)
      "org.p0deje.Maccy" = {
        # control+command+v (carbonKeyCode 9 = v, carbonModifiers 4352 = control+command)
        KeyboardShortcuts_popup = builtins.toJSON {
          carbonKeyCode = 9;
          carbonModifiers = 4352;
        };
        SUEnableAutomaticChecks = 0;
        menuIcon = "clipboard";
        popupPosition = "window";
        searchMode = "fuzzy";
        showFooter = 0;
        showSearch = 1;
        showTitle = 0;
      };
    };
    dock = {
      autohide = true;
      orientation = "bottom";
      tilesize = 48;
      show-recents = false;
      mru-spaces = false;
      showhidden = true;
      mouse-over-hilite-stack = true;
      enable-spring-load-actions-on-all-items = true;
    };
    screencapture = {
      location = "~/Pictures/screenshots";
      type = "png";
      disable-shadow = true;
    };
    menuExtraClock.ShowSeconds = true;
    menuExtraClock.Show24Hour = true;
    controlcenter.BatteryShowPercentage = true;
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = false;
    finder = {
      AppleShowAllExtensions = true;
      AppleShowAllFiles = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXEnableExtensionChangeWarning = false;
      FXRemoveOldTrashItems = true;
      NewWindowTarget = "Home";
      FXPreferredViewStyle = "Nlsv";
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      QuitMenuItem = true;
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

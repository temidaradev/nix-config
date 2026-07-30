# Discord with Vencord, configured declaratively.
#
# The package comes straight from nixpkgs -- `discord` takes withVencord /
# withOpenASAR / commandLineArgs as override arguments, which covers everything
# nixcord used to do at the package level. Settings are written by hjem rather
# than by a module, so the plugin list below is the whole story.
#
# vencord.patch in this directory is no longer applied: it patched Vencord's
# own patcher.ts (adding AcceleratedVideoDecodeLinuxGL to the enable-features
# Chromium switch on Linux) and only had an effect when Nix built Vencord from
# source. It is kept for reference should that ever be revisited.
{ hmUsername, lib, pkgs, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;

  # nixpkgs takes these as one string, unlike nixcord's list.
  commandLineArgs = lib.concatStringsSep " " (
    [ "--enable-blink-features=MiddleClickAutoscroll" ]
    ++ lib.optionals (!isDarwin) [
      # enable vaapi (single Intel GPU -> renderD128)
      "--render-node-override=/dev/dri/renderD128"
      # use wayland and enable IME
      "--ozone-platform-hint=auto"
      "--enable-wayland-ime"
    ]
  );

  discord = pkgs.discord.override {
    withVencord = true;
    withOpenASAR = true;
    inherit commandLineArgs;
  };

  # Vencord's config root differs per platform: XDG on Linux, Application
  # Support on macOS. Both are expressed home-relative because hjem's `files`
  # targets are relative to the user's home directory and reject absolute paths.
  vencordRoot =
    if isDarwin then "Library/Application Support/Vencord" else ".config/Vencord";
  vencordDir = "${vencordRoot}/settings";

  # Themes fetched by Vencord over the network at startup. Adding one through
  # the Vencord UI does not survive a rebuild -- settings.json is rewritten
  # wholesale -- so online themes have to be listed here to stick.
  themeLinks = [
    "https://maendisease.github.io/Steam/Steam.css"
  ];

  # Local themes: drop a .css next to this file under ./themes/, name it here,
  # and add the same filename to enabledThemes below to switch it on. Kept as an
  # explicit map rather than a directory read so an unused file cannot silently
  # end up installed.
  localThemes = {
    # "mytheme.css" = ./themes/mytheme.css;
  };

  # Filenames from localThemes that Vencord should actually apply.
  enabledThemes = [ ];

  settings = {
    autoUpdate = false;
    autoUpdateNotification = false;
    notifyAboutUpdates = false;

    # Vencord has carried both spellings; write both so neither loses.
    useQuickCss = true;
    useQuickCSS = true;

    inherit themeLinks enabledThemes;

    # disable translate button on chatbar
    uiElements.chatBarButtons.Translate.enabled = false;

    plugins = import ./plugins.nix { inherit lib isDarwin; };
  };

  settingsFile = pkgs.writeText "vencord-settings.json" (builtins.toJSON settings);

  quickCssFile = pkgs.writeText "vencord-quickcss.css" (
    builtins.readFile ./quickCss.css
    # Appended, not prepended: quickCss.css opens with @import rules, which
    # CSS requires to come before any other rule.
    + lib.optionalString isDarwin (builtins.readFile ./lowPower.css)
  );

  # `copy` rather than the default `symlink`: Vencord rewrites settings.json at
  # runtime (it normalises the schema and expands every plugin to its defaults
  # on first load, before you touch the UI). A symlink would point into the
  # read-only store and that write would fail. hjem re-copies on every rebuild,
  # so this file is still the source of truth.
  mutable = source: {
    inherit source;
    type = "copy";
    permissions = "0644";
    clobber = true;
  };

  discordDir =
    if isDarwin then "Library/Application Support/discord" else ".config/discord";

  # Discord's own client settings, separate from Vencord's.
  #
  # The three update keys are load-bearing, not cosmetic. Vencord is injected by
  # replacing Discord.app's app.asar with a stub that requires patcher.js; if
  # Discord's self-updater runs it downloads a stock app.asar straight over that
  # stub and Vencord silently stops loading. The nixpkgs wrapper guards against
  # this, but only when launched via bin/Discord -- opening the .app from
  # Spotlight or the Dock goes directly to the bundle and skips it, so the guard
  # has to live in the settings file too.
  updateSettings = {
    SKIP_HOST_UPDATE = true;
    SKIP_MODULE_UPDATE = true;
    USE_NEW_UPDATER = false;
  };

  # OpenASAR picks a Chromium flag preset at launch and defaults to `perf` when
  # unset -- that is where the --force_high_performance_gpu and
  # --enable-gpu-rasterization on the GPU process come from, along with a 300s
  # BackForwardCache. Ask for its `battery` preset on the laptop.
  darwinSettings = {
    openasar = {
      setup = true;
      cmdPreset = "battery";
    };
    BACKGROUND_COLOR = "#121214";
    # Left on: on Apple Silicon, GPU compositing costs less than making the CPU
    # rasterize every frame.
    enableHardwareAcceleration = true;
    DANGEROUS_ENABLE_DEVTOOLS_ONLY_ENABLE_IF_YOU_KNOW_WHAT_YOURE_DOING = true;
  };

  # Written wholesale on every rebuild, so anything worth keeping has to be
  # named here. Window geometry is deliberately left out: Discord re-persists it
  # on its own afterwards.
  discordSettingsFile = pkgs.writeText "discord-settings.json" (
    builtins.toJSON (updateSettings // lib.optionalAttrs isDarwin darwinSettings)
  );

  # Discord refuses to get past the "STARTING" splash until its native modules
  # are present under <configDir>/<version>/modules. nixpkgs stages them from a
  # wrapper around bin/Discord, but on macOS the Dock and Spotlight launch the
  # .app bundle directly and never touch that wrapper, so the modules have to be
  # linked declaratively instead. Linux keeps using the wrapper via its .desktop
  # entry and needs none of this.
  #
  # The list matches nixpkgs' own staging script; a module missing from it is
  # simply not linked, which shows up as the same splash-screen hang.
  discordModuleNames = [
    "discord_cloudsync"
    "discord_desktop_core"
    "discord_dispatch"
    "discord_erlpack"
    "discord_game_utils"
    "discord_intents"
    "discord_krisp"
    "discord_modules"
    "discord_notifications"
    "discord_rpc"
    "discord_spellcheck"
    "discord_utils"
    "discord_voice"
    "discord_webauthn"
    "discord_zstd"
  ];

  bundleModules = "${discord}/Applications/Discord.app/Contents/Resources/modules";
  modulesDir = "${discordDir}/${discord.version}/modules";

  # Symlinks, matching what nixpkgs' staging script creates: Discord only reads
  # these, and pointing at the store keeps them in step with the package.
  moduleLinks = lib.listToAttrs (
    map (m: {
      name = "${modulesDir}/${m}";
      value.source = "${bundleModules}/${m}";
    }) discordModuleNames
  );

  installedJsonFile = pkgs.writeText "discord-installed.json" (
    builtins.toJSON (
      lib.listToAttrs (map (m: { name = m; value.installedVersion = 1; }) discordModuleNames)
    )
  );
in
{
  environment.systemPackages = [ discord ];

  hjem.users.${hmUsername}.files = {
    "${vencordDir}/settings.json" = mutable settingsFile;
    "${vencordDir}/quickCss.css" = mutable quickCssFile;
    "${discordDir}/settings.json" = mutable discordSettingsFile;
  } // lib.mapAttrs' (name: src: lib.nameValuePair "${vencordRoot}/themes/${name}" (mutable src)) localThemes
  // lib.optionalAttrs isDarwin (
    moduleLinks // { "${modulesDir}/installed.json" = mutable installedJsonFile; }
  );
}

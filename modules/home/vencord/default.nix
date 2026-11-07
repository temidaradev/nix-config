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
{ hmUsername, lib, pkgs, system, ... }:
let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # nixpkgs takes these as one string, unlike nixcord's list.
  commandLineArgs = lib.concatStringsSep " " (
    [ "--enable-blink-features=MiddleClickAutoscroll" ]
    ++ lib.optionals (!isDarwin) [
      # enable vaapi -- the Arc B580 is the only render node on this box, so
      # renderD128 is unambiguous. Kept explicit so a second GPU appearing
      # later cannot silently move VA-API onto the wrong node.
      "--render-node-override=/dev/dri/renderD128"
      # use wayland and enable IME
      "--ozone-platform-hint=auto"
      "--enable-wayland-ime"
    ]
  );

  # Vencord 1.15.13 crashes Discord 0.0.420 during web startup (blank window).
  vencord = pkgs.vencord.overrideAttrs (finalAttrs: old: {
    version = "1.15.16";
    src = old.src.override {
      tag = "v${finalAttrs.version}";
      hash = "sha256-aUJubLJpyLAZWiOezqFxPY6oVPgWVPQpajFqrJvrO9U=";
    };
    # Upstream now pins @types/react through a catalog; nixpkgs' lockfile fix is obsolete.
    patches = [ ];
    postPatch = "";
    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version src patches postPatch;
      pnpm = pkgs.pnpm_11;
      fetcherVersion = 4;
      hash = "sha256-HS8uZNepvDefjrsG3buVLFCVv7sHvazcwdpcT3EQ/78=";
    };
  });

  discord = pkgs.discord.override {
    withVencord = true;
    withOpenASAR = true;
    inherit commandLineArgs vencord;
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
  themeLinks = [ ];

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
  # unset. Its presets are `base`, `perf` and `battery`, and it always merges
  # `base` with the one named here -- it looks the name up as `presets[x]?.split`
  # and concatenates, so an unrecognised name contributes nothing and is then
  # dropped by the falsy check in the flag loop. `none` is therefore the way to
  # ask for "base only"; naming `base` would instead apply it twice.
  #
  # Linux is deliberately NOT on `perf`. That preset expands to
  #   --enable-gpu-rasterization --enable-zero-copy --ignore-gpu-blocklist
  #   --enable-hardware-overlays=single-fullscreen,single-on-top,underlay
  #   --enable-features=EnableDrDc,... --disable-features=Vulkan
  #   --force_high_performance_gpu
  # and on the Arc B580 (Battlemage, `xe` driver, Mesa 26.x, KDE Wayland) that
  # combination kills the Chromium GPU process with SIGTRAP -- a CHECK failure,
  # not a kernel GPU hang -- whenever an image, GIF or video is composited. The
  # window survives but goes black or grey. Every coredump under
  # `coredumpctl list` for .Discord-wrapped is `--type=gpu-process` carrying
  # exactly these flags. The dangerous ones are the non-default four:
  # --ignore-gpu-blocklist overrides Chromium's own driver blocklist on very new
  # hardware, --enable-zero-copy and --enable-hardware-overlays push dmabuf tiles
  # and Xe2 compression modifiers through paths Chromium mishandles, EnableDrDc
  # is Android-oriented cross-thread GL context sharing, and disabling Vulkan
  # forces the less-exercised iris GL backend on a discrete Arc card. What is
  # left behind on `base` costs close to nothing: GPU rasterization and the Skia
  # renderer are Chromium defaults on Linux anyway.
  #
  # macOS stays on `battery` -- it only adds --force_low_power_gpu and a media
  # caching tweak, and that machine has never crashed.
  #
  # `setup = true` suppresses OpenASAR's first-run setup prompt; without it the
  # prompt returns on every rebuild, since this file is rewritten each time.
  openasarSettings = {
    openasar = {
      setup = true;
      cmdPreset = if isDarwin then "battery" else "none";
    };
  };

  darwinSettings = {
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
    builtins.toJSON (
      updateSettings // openasarSettings // lib.optionalAttrs isDarwin darwinSettings
    )
  );

  # Discord refuses to get past the "STARTING" splash until its native modules
  # are present under <configDir>/<version>/modules. nixpkgs stages them from a
  # wrapper around bin/Discord, but on macOS the Dock and Spotlight launch the
  # .app bundle directly and never touch that wrapper, so the modules have to be
  # staged declaratively instead. Linux keeps using the wrapper via its .desktop
  # entry and needs none of this.
  #
  # They must be real copies, not symlinks into the store: discord_desktop_core
  # resolves each native module (following symlinks) and throws "resolved
  # outside the native module directories" unless the real path sits under the
  # modules dir -- the renderer then never mounts (blank window). hjem's `copy`
  # only handles single files, so activation copies the directories instead
  # (a no-op unless the Discord build changed). Keep the parent
  # writable: Discord creates pending/ during startup even with module updates
  # disabled.
  isDarwinHost = lib.hasSuffix "darwin" system;
  bundleModules = "${discord}/share/discord/modules";
  modulesDir = "${discordDir}/${discord.version}/modules";
  discordModuleNames = [
    "discord_cloudsync" "discord_desktop_core" "discord_dispatch"
    "discord_erlpack" "discord_game_utils" "discord_intents" "discord_krisp"
    "discord_modules" "discord_ndi" "discord_notifications" "discord_rpc"
    "discord_spellcheck" "discord_sysimg" "discord_utils" "discord_voice"
    "discord_webauthn" "discord_zstd"
  ];
  stageModules = pkgs.writeShellApplication {
    name = "discord-stage-modules";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      dest="$HOME/${modulesDir}"
      src=${bundleModules}
      stamp="$dest/.nix-source"
      mkdir -p "$dest"

      # Up to date only if every module is a real directory from this build.
      fresh=1
      [[ "$(cat "$stamp" 2>/dev/null)" == "$src" ]] || fresh=0
      for name in ${lib.concatStringsSep " " discordModuleNames}; do
        if [[ -L "$dest/$name" || ! -d "$dest/$name" ]]; then fresh=0; fi
      done
      [[ $fresh == 1 ]] && exit 0

      for name in ${lib.concatStringsSep " " discordModuleNames}; do
        tmp="$dest/.$name.tmp"
        rm -rf "$tmp"
        cp -RL "$src/$name" "$tmp"
        chmod -R u+w "$tmp"
        rm -rf "''${dest:?}/$name"
        mv "$tmp" "$dest/$name"
      done
      echo "$src" > "$stamp"
      echo "staged Discord modules from $src"
    '';
  };
in
{
  environment.systemPackages = [ discord ];

  hjem.users.${hmUsername}.files = {
    "${vencordDir}/settings.json" = mutable settingsFile;
    "${vencordDir}/quickCss.css" = mutable ./quickCss.css;
    "${discordDir}/settings.json" = mutable discordSettingsFile;
  } // lib.mapAttrs' (name: src: lib.nameValuePair "${vencordRoot}/themes/${name}" (mutable src)) localThemes
  // lib.optionalAttrs isDarwin {
    "${modulesDir}/installed.json" = mutable "${bundleModules}/installed.json";
  };
}
# Gated on the `system` specialArg rather than pkgs: these options only exist
# on nix-darwin, and deciding attribute names from pkgs would recurse.
// lib.optionalAttrs isDarwinHost {
  # Run inline during activation rather than from a launchd agent: macOS
  # privacy protection denies background agents access to another app's
  # Application Support folder, while darwin-rebuild inherits the terminal's.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "staging Discord native modules..."
    /usr/bin/sudo -H -u ${hmUsername} ${lib.getExe stageModules} \
      || echo "warning: staging Discord native modules failed" >&2
  '';
}

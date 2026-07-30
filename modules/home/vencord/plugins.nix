# Vencord's `plugins` attrset.
#
# Keys are Vencord's own PascalCase plugin identifiers and the toggle is
# `enabled` -- these are written straight to settings.json, so a typo here
# is silently ignored by Vencord rather than caught at eval.
#
# Vencord fills in every unlisted plugin with its own defaults on load, so
# this only names what we actually care about.
{ lib, isDarwin }:
let
  # The only two plugins worth losing on the laptop. Everything else in the
  # main list is deliberately kept on Darwin too -- the frame and memory cost
  # is real, but so is the feature.
  darwinDisabled = {
    # Lets Discord drop us out of voice on idle again instead of holding the
    # connection (and the mic) open indefinitely.
    DisableCallIdle.enabled = false;
    # A CSS blur filter, re-sampled every frame while the embed is on screen.
    BlurNSFW.enabled = false;
  };

  # Plugins carrying settings beyond the on/off toggle.
  configured = {
    TextReplace = {
      enabled = true;
      regexRules = import ./text-replace.nix;
    };
    LoadingQuotes = {
      enabled = true;
      # Both preset sources off so only the quotes below can appear.
      enablePluginPresetQuotes = false;
      enableDiscordPresetQuotes = false;
      # Pipe-separated; that is LoadingQuotes' default delimiter.
      additionalQuotes = "BENJAMIN NETANYAHU|RECEP TAYYIP ERDOGAN|CLOD KISSED MY ASS UWU";
    };
    ConsoleJanitor = {
      enabled = true;
      disableLoggers = true;
    };
    ImageZoom = {
      enabled = true;
      square = true;
      size = 500;
    };
    MessageLogger = {
      enabled = true;
      inlineEdits = false;
      ignoreBots = true;
    };
    NewGuildSettings = {
      enabled = true;
      messages = 1;
    };
    NoBlockedMessages = {
      enabled = true;
      ignoreMessages = true;
    };
    NotificationVolume = {
      enabled = true;
      notificationVolume = 50;
    };
    PinDMs = {
      enabled = true;
      pinOrder = 1;
    };
    PlatformIndicators = {
      enabled = true;
      messages = false;
    };
    RelationshipNotifier = {
      enabled = true;
      notices = true;
    };
    ServerListIndicators = {
      enabled = true;
      mode = 3;
      useCompact = true;
    };
    ShikiCodeblocks = {
      enabled = true;
      theme = "https://raw.githubusercontent.com/shikijs/textmate-grammars-themes/bc5436518111d87ea58eb56d97b3f9bec30e6b83/packages/tm-themes/themes/catppuccin-mocha.json";
    };
    VolumeBooster = {
      enabled = true;
      multiplier = 3;
    };
  };

  # Plain on/off toggles.
  toggles = {
    AlwaysAnimate.enabled = false;
    AnonymiseFileNames.enabled = true;
    BetterGifAltText.enabled = true;
    BetterRoleContext.enabled = true;
    BetterSessions.enabled = true;
    BetterSettings.enabled = true;
    BiggerStreamPreview.enabled = true;
    BlurNSFW.enabled = true;
    CallTimer.enabled = true;
    ClearURLs.enabled = true;
    CopyEmojiMarkdown.enabled = true;
    CopyFileContents.enabled = true;
    CopyUserURLs.enabled = true;
    CrashHandler.enabled = true;
    Dearrow.enabled = true;
    DisableCallIdle.enabled = true;
    DisableDeepLinks.enabled = true;
    DontRoundMyTimestamps.enabled = true;
    Experiments.enabled = true;
    ExpressionCloner.enabled = true;
    FakeNitro.enabled = true;
    FakeProfileThemes.enabled = true;
    FavoriteEmojiFirst.enabled = true;
    FixCodeblockGap.enabled = true;
    FixImagesQuality.enabled = true;
    FixSpotifyEmbeds.enabled = true;
    FixYoutubeEmbeds.enabled = true;
    ForceOwnerCrown.enabled = true;
    FullSearchContext.enabled = true;
    GifPaste.enabled = true;
    GreetStickerPicker.enabled = true;
    HideMedia.enabled = true;
    ImplicitRelationships.enabled = true;
    MemberCount.enabled = true;
    MentionAvatars.enabled = true;
    MessageLatency.enabled = true;
    MessageLinkEmbeds.enabled = true;
    MutualGroupDMs.enabled = true;
    NoDevtoolsWarning.enabled = true;
    NoF1.enabled = true;
    NoMaskedUrlPaste.enabled = true;
    NoOnboardingDelay.enabled = true;
    NoPendingCount.enabled = true;
    NoUnblockToJump.enabled = true;
    OpenInApp.enabled = true;
    PauseInvitesForever.enabled = true;
    PermissionFreeWill.enabled = true;
    PermissionsViewer.enabled = true;
    PictureInPicture.enabled = true;
    ReactErrorDecoder.enabled = true;
    ReplyTimestamp.enabled = true;
    RevealAllSpoilers.enabled = true;
    ReverseImageSearch.enabled = true;
    ReviewDB.enabled = true;
    RoleColorEverywhere.enabled = true;
    SecretRingToneEnabler.enabled = true;
    ServerInfo.enabled = true;
    ShowConnections.enabled = true;
    ShowHiddenChannels.enabled = true;
    ShowHiddenThings.enabled = true;
    SpotifyCrack.enabled = true;
    SpotifyShareCommands.enabled = true;
    StickerPaste.enabled = true;
    ThemeAttributes.enabled = true;
    Translate.enabled = true;
    TypingTweaks.enabled = true;
    Unindent.enabled = true;
    UnlockedAvatarZoom.enabled = true;
    UnsuppressEmbeds.enabled = true;
    ValidReply.enabled = true;
    ValidUser.enabled = true;
    VencordToolbox.enabled = true;
    ViewIcons.enabled = true;
    VoiceDownload.enabled = true;
    VoiceMessages.enabled = true;
    YoutubeAdblock.enabled = true;
  };
in
lib.foldl' lib.recursiveUpdate toggles [
  configured
  (lib.optionalAttrs isDarwin darwinDisabled)
]

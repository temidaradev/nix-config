{ lib, stdenvNoCC, fetchurl, _7zz }:

# nixpkgs' `vial` is the x86_64 AppImage and is marked linux-only, and the
# `vial` Homebrew cask was disabled upstream in September 2026 for failing the
# Gatekeeper check. Upstream's own .dmg still works: nothing Nix downloads gets
# a com.apple.quarantine attribute, so Gatekeeper never assesses it. The build
# is x86_64 only, so it runs through Rosetta 2 on Apple Silicon.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "vial";
  version = "0.7.5";

  src = fetchurl {
    url = "https://github.com/vial-kb/vial-gui/releases/download/v${finalAttrs.version}/Vial-v${finalAttrs.version}.dmg";
    hash = "sha256-tijbEfjfAS+q/M7vfes2tUghtQfUyXAzb4WlbIAOiHY=";
  };

  # The image is APFS, which `undmg` cannot read.
  nativeBuildInputs = [ _7zz ];

  unpackPhase = ''
    runHook preUnpack
    7zz x -snld "$src"
    runHook postUnpack
  '';

  sourceRoot = "Vial.app";

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/Applications/Vial.app" "$out/bin"
    cp -R . "$out/Applications/Vial.app"

    # The bundle is a PyInstaller build that resolves its payload relative to
    # the executable, so launch the bundle itself rather than symlinking the
    # inner binary onto PATH.
    cat > "$out/bin/vial" <<EOF
    #!${stdenvNoCC.shell}
    exec /usr/bin/open -na "$out/Applications/Vial.app" --args "\$@"
    EOF
    chmod +x "$out/bin/vial"

    runHook postInstall
  '';

  meta = {
    description = "Open-source GUI for configuring your keyboard in real time";
    homepage = "https://get.vial.today/";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "vial";
  };
})

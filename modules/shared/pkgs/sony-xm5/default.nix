{ lib, rustPlatform, pkg-config, dbus }:

rustPlatform.buildRustPackage {
  pname = "sony-xm5";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./Cargo.toml ./Cargo.lock ./src ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ dbus ];

  meta = {
    description = "Sony WH-1000XM5 control channel speaking JSON lines";
    license = lib.licenses.agpl3Plus;
    mainProgram = "sony-xm5";
    platforms = lib.platforms.linux;
  };
}

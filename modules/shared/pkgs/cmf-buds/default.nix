{ lib, rustPlatform, pkg-config, dbus }:

rustPlatform.buildRustPackage {
  pname = "cmf-buds";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./Cargo.toml ./Cargo.lock ./src ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ dbus ];

  meta = {
    description = "CMF Buds Pro 2 control channel speaking JSON lines";
    license = lib.licenses.agpl3Plus;
    mainProgram = "cmf-buds";
    platforms = lib.platforms.linux;
  };
}

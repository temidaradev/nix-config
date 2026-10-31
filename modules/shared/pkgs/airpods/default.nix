{ lib, rustPlatform, pkg-config, dbus }:

rustPlatform.buildRustPackage {
  pname = "airpods";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./Cargo.toml ./Cargo.lock ./src ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ dbus ];

  meta = {
    description = "AirPods AAP control channel speaking JSON lines";
    license = lib.licenses.mit;
    mainProgram = "airpods";
    platforms = lib.platforms.linux;
  };
}

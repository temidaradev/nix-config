{ lib, rustPlatform }:

rustPlatform.buildRustPackage {
  pname = "mouse-battery";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./Cargo.toml ./Cargo.lock ./src ];
  };

  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "Battery of LXDDZ 2.4G (1d57:fa60) mice from the receiver heartbeat, as JSON lines";
    license = lib.licenses.mit;
    mainProgram = "mouse-battery";
    platforms = lib.platforms.linux;
  };
}

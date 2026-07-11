{ config, pkgs, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  btusb-ub600 = pkgs.stdenv.mkDerivation {
    pname = "btusb-ub600";
    version = kernel.version;
    src = kernel.src;

    nativeBuildInputs = kernel.moduleBuildDependencies;
    hardeningDisable = [ "pic" ];

    postPatch = ''
      sed -i 's#.*USB_DEVICE(0x2357, 0x0604).*#\t{ USB_DEVICE(0x37ad, 0x0600), .driver_info = BTUSB_REALTEK | BTUSB_WIDEBAND_SPEECH },\n&#' \
        drivers/bluetooth/btusb.c
      grep -q '0x37ad' drivers/bluetooth/btusb.c
    '';

    buildPhase = ''
      runHook preBuild
      make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
        M=$PWD/drivers/bluetooth modules
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm444 drivers/bluetooth/btusb.ko \
        $out/lib/modules/${kernel.modDirVersion}/updates/btusb.ko
      runHook postInstall
    '';
  };
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  boot.extraModulePackages = [ btusb-ub600 ];
}

{ pkgs, ... }:

{
  services.xserver.videoDrivers = [ "modesetting" ];

  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
      intel-compute-runtime
      level-zero
      vulkan-validation-layers
    ];

    extraPackages32 = with pkgs.pkgsi686Linux; [
      intel-media-driver
    ];
  };

  environment.variables.LIBVA_DRIVER_NAME = "iHD";

  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    nvtopPackages.intel
    libva-utils
    clinfo
    vulkan-tools
  ];

  security.wrappers.btop = {
    source = "${pkgs.btop}/bin/btop";
    owner = "root";
    group = "root";
    capabilities = "cap_perfmon=+ep";
  };
}

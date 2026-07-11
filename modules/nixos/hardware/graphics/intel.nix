{ pkgs, ... }:

{
  services.xserver.videoDrivers = [ "modesetting" ];

  boot.blacklistedKernelModules = [ "radeon" "amdgpu" ];

  # Early KMS so the B580 is initialized before SDDM/Plasma start
  boot.initrd.kernelModules = [ "xe" ];

  hardware.enableRedistributableFirmware = true;

  hardware.graphics = {
    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
      intel-compute-runtime
      level-zero
    ];
  };

  environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

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

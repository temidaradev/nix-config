{ pkgs, ... }:

{
  imports = [
    ./steam
  ];

  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings = {
      general = {
        renice = 10;
        softrealtime = "auto";
        ioprio = 0;
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
      };
      cpu = {
        park_cores = "no";
        pin_cores = "no";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    gamemode
    gamescope
  ];
}

{ pkgs }:

with pkgs; {
  system = [
    # Shell + CLI
    git
    vim
    wget
    unzip
    zip

    # Monitoring
    (btop.override { cudaSupport = false; rocmSupport = false; })
    nvtopPackages.nvidia
    smartmontools
    lm_sensors

    # Disks
    parted

    # Containers
    docker-compose
  ];
}

{ config, pkgs, ... }:

{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;

    extraConfig.pipewire."92-hires" = {
      "context.properties" = {
        "default.clock.rate" = 192000;
        "default.clock.allowed-rates" = [ 192000 ];
      };
    };

    wireplumber.extraConfig.bluetoothEnhancements = {
      "monitor.bluez.properties" = {
        "bluez5.codecs" = [ "ldac" "aac" "sbc" ];
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.roles" = [ "hsp_hs" "hfp_hf" "a2dp_sink" "a2dp_source" ];
      };
    };
  };
}

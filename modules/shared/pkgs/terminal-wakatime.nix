{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "terminal-wakatime";
  version = "1.1.5";

  src = fetchFromGitHub {
    owner = "hackclub";
    repo = "terminal-wakatime";
    tag = "v${version}";
    hash = "sha256-zS4u9iViMYGjqViBCxAiT04BVfwJnuLMejXRGBW0TT4=";
  };

  vendorHash = "sha256-fchZVBY43ccu6nbWn572Qzfgeq4uIwpLf99lOuJCO44=";

  subPackages = [ "cmd/terminal-wakatime" ];

  ldflags = [ "-s" "-w" "-X main.version=${version}" ];

  # The test suite downloads wakatime-cli from GitHub.
  doCheck = false;

  meta = {
    description = "WakaTime/Hackatime heartbeats for shell commands";
    homepage = "https://github.com/hackclub/terminal-wakatime";
    license = lib.licenses.mit;
    mainProgram = "terminal-wakatime";
    platforms = lib.platforms.unix;
  };
}

{ pkgs, lib, ... }:

let
  base = ''
    [user]
    	name = temidaradev
    	email = temidaradev@proton.me
    	signingkey = CF0CCF7E9AD5BD9D
    [commit]
    	gpgsign = true
    [tag]
    	gpgsign = true
    [fetch]
    	fsckObjects = true
    [receive]
    	fsckObjects = true
    [transfer]
    	fsckObjects = true
  '';

  darwinExtra = ''
    [credential]
    	helper = osxkeychain
  '';

  linuxExtra = ''
    [credential "https://github.com"]
    	helper = !${pkgs.gh}/bin/gh auth git-credential
  '';

  gitconfig = pkgs.writeText "gitconfig"
    (base + (if pkgs.stdenv.isDarwin then darwinExtra else linuxExtra));
in
{
  environment.variables.GIT_CONFIG_SYSTEM = "${gitconfig}";
}

{ pkgs, hmUsername, ... }:

let
  # Read-only commands Claude Code may run without asking.
  allowedCommands = [
    "rg*"
    "ls*"
    "eza*"
    "fd*"
    "tokei*"

    "jj bookmark list*"
    "jj config get*"
    "jj config list*"
    "jj diff*"
    "jj evolog*"
    "jj file annotate*"
    "jj file list*"
    "jj file show*"
    "jj help*"
    "jj interdiff*"
    "jj log*"
    "jj op diff*"
    "jj op log*"
    "jj op show*"
    "jj resolve --list"
    "jj root*"
    "jj show*"
    "jj st*"
    "jj status*"
    "jj version*"
    "jj workspace list*"
    "jj workspace root*"

    "git status*"
    "git log*"
    "git diff*"
    "git show*"
    "git branch*"
    "git remote -v"

    "gh auth status*"
    "gh issue list*"
    "gh issue view*"
    "gh pr checks*"
    "gh pr diff*"
    "gh pr list*"
    "gh pr status*"
    "gh pr view*"
    "gh release list*"
    "gh release view*"
    "gh repo view*"
    "gh run list*"
    "gh run view*"

    "nix flake show*"
    "nix flake metadata*"
    "nix eval*"
    "nix-instantiate --parse*"
  ];
in
{
  hjem.users.${hmUsername} = {
    files.".claude/settings.json" = {
      generator = (pkgs.formats.json { }).generate "claude-settings.json";
      value = {
        "$schema" = "https://json.schemastore.org/claude-code-settings.json";

        permissions.allow = map (cmd: "Bash(${cmd})") allowedCommands ++ [
          "Glob"
          "Grep"
          "WebFetch"
          "WebSearch"
        ];

        # `find` over the whole store hangs forever.
        permissions.deny = [
          "Bash(find /nix/store*)"
          "Bash(find /nix/store/*)"
        ];

        env.DISABLE_TELEMETRY = "1";
        env.DISABLE_ERROR_REPORTING = "1";
        env.CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
      };
    };
  };
}

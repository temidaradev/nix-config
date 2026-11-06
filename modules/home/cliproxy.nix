{ pkgs, hmUsername, ... }:

let
  # CLIProxy on the home server. At home it's reached over the LAN; anywhere
  # else over Tailscale. The client API key is a secret, so it stays out of the
  # Nix store: put it in ~/.config/cliproxy/api-key (chmod 600) on each machine.
  lanUrl = "http://192.168.1.15:8317";
  tailnetUrl = "http://100.81.57.15:8317";

  # Read-only Autolith site configuration (loaded before the user's own
  # init.lisp, which stays editable). Registers CLIProxy as an OpenAI-compatible
  # provider at whichever URL the wrapper detected; the key lives in Autolith's
  # credential store (`cliproxy autolith auth cliproxy`).
  autolithSite = pkgs.writeTextDir "init.lisp" ''
    (let ((base (string-right-trim
                 "/" (or (uiop:getenv "CLIPROXY_URL") "${tailnetUrl}"))))
      (register-openai-compatible-provider
       :name            "cliproxy"
       :description     "CLIProxy on the home server"
       :endpoint        (concatenate 'string base "/v1/chat/completions")
       :models-endpoint (concatenate 'string base "/v1/models")))
  '';

  cliproxy = pkgs.writeShellApplication {
    name = "cliproxy";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      key_file="''${CLIPROXY_KEY_FILE:-$HOME/.config/cliproxy/api-key}"

      usage() {
        cat <<USAGE
      usage: cliproxy <command>

        url              print the reachable proxy URL (LAN first, then Tailscale)
        key              print the client API key
        env              print shell exports (eval "\$(cliproxy env)")
        run <cmd> ...    run any command with Anthropic/OpenAI env pointed at the proxy
        claude [args]    run Claude Code through the proxy
        codex [args]     run Codex through the proxy
        autolith [args]  run Autolith with the "cliproxy" provider registered

      CLIPROXY_URL overrides URL detection; CLIPROXY_KEY_FILE overrides the key path.
      USAGE
      }

      proxy_url() {
        if [[ -n "''${CLIPROXY_URL:-}" ]]; then
          echo "$CLIPROXY_URL"
          return
        fi
        # At home: LAN, no Tailscale needed.
        if reachable ${lanUrl}; then
          echo ${lanUrl}
          return
        fi
        # Away: use Tailscale, starting it on demand (CLIPROXY_NO_TAILSCALE_UP=1 disables).
        if ! reachable ${tailnetUrl} && [[ -z "''${CLIPROXY_NO_TAILSCALE_UP:-}" ]]; then
          tailscale_up
          for _ in $(seq 1 15); do
            reachable ${tailnetUrl} && break
            sleep 1
          done
        fi
        if reachable ${tailnetUrl}; then
          echo ${tailnetUrl}
          return
        fi
        echo "cliproxy: unreachable on LAN (${lanUrl}) and Tailscale (${tailnetUrl})" >&2
        return 1
      }

      # Any HTTP response counts as reachable; refused/timeout falls through.
      reachable() {
        curl -s -o /dev/null --connect-timeout 2 --max-time 4 "$1/"
      }

      tailscale_up() {
        if ! command -v tailscale >/dev/null; then
          echo "cliproxy: off the home LAN and tailscale isn't installed" >&2
          return 0
        fi
        echo "cliproxy: not on the home LAN, starting Tailscale..." >&2
        if [[ "$(uname)" == Darwin ]] && ! tailscale status >/dev/null 2>&1; then
          # The macOS CLI needs the app running.
          open -g -a Tailscale 2>/dev/null || true
          sleep 2
        fi
        tailscale up >/dev/null 2>&1 \
          || echo "cliproxy: 'tailscale up' failed; run it yourself to log in" >&2
      }

      proxy_key() {
        if [[ ! -r "$key_file" ]]; then
          echo "cliproxy: no API key at $key_file" >&2
          return 1
        fi
        tr -d '[:space:]' < "$key_file"
      }

      export_env() {
        url=$(proxy_url)
        key=$(proxy_key)
        export CLIPROXY_URL="$url" CLIPROXY_API_KEY="$key"
        export ANTHROPIC_BASE_URL="$url" ANTHROPIC_AUTH_TOKEN="$key"
        export OPENAI_BASE_URL="$url/v1" OPENAI_API_KEY="$key"
        unset ANTHROPIC_API_KEY
      }

      cmd="''${1:-}"
      shift || true
      case "$cmd" in
        url) proxy_url ;;
        key) proxy_key ;;
        env)
          export_env
          for v in CLIPROXY_URL CLIPROXY_API_KEY ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN OPENAI_BASE_URL OPENAI_API_KEY; do
            printf 'export %s=%q\n' "$v" "''${!v}"
          done
          ;;
        run)
          [[ $# -gt 0 ]] || { usage >&2; exit 1; }
          export_env
          exec "$@"
          ;;
        claude)
          export_env
          exec claude "$@"
          ;;
        codex)
          export_env
          exec codex \
            -c model_provider=cliproxy \
            -c 'model_providers.cliproxy.name="CLIProxy"' \
            -c "model_providers.cliproxy.base_url=\"$OPENAI_BASE_URL\"" \
            -c 'model_providers.cliproxy.env_key="CLIPROXY_API_KEY"' \
            -c 'model_providers.cliproxy.wire_api="responses"' \
            "$@"
          ;;
        autolith)
          CLIPROXY_URL=$(proxy_url)
          export CLIPROXY_URL AUTOLITH_SITE_CONFIG_ROOT=${autolithSite}
          exec autolith "$@"
          ;;
        ""|-h|--help|help) usage ;;
        *) echo "cliproxy: unknown command '$cmd'" >&2; usage >&2; exit 1 ;;
      esac
    '';
  };
in
{
  hjem.users.${hmUsername}.packages = [ cliproxy ];
}

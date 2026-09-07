pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// power-profiles-daemon; also the NixOS maintenance actions (run in a terminal).
Singleton {
    id: root
    property string profile: ""
    readonly property var profiles: ["power-saver", "balanced", "performance"]
    readonly property string flake: Quickshell.env("HOME") + "/.dotfiles"

    Process { id: get; command: ["powerprofilesctl", "get"]; stdout: StdioCollector { onStreamFinished: root.profile = text.trim() } }
    function refresh() { get.running = true }
    function set(p) { Quickshell.execDetached(["powerprofilesctl", "set", p]); profile = p }

    function term(title, cmd) {
        Quickshell.execDetached(["ghostty", "--title=" + title, "-e", "sh", "-c", cmd + "; echo; echo '--- done, press enter ---'; read _"])
    }
    function rebuild() { term("nixos rebuild", "cd " + flake + " && nh os switch . && systemctl --user restart quickshell-niri") }
    function update() { term("flake update", "cd " + flake + " && nix flake update && git diff --stat") }
    function clean() { term("nix clean", "nh clean all --keep 3") }
}

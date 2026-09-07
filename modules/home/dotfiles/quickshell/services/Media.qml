pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Picks the "interesting" MPRIS player: the one chosen in the popup if still
// alive, else a playing one, else the first one.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer chosen: null
    readonly property MprisPlayer player: {
        const ps = players
        if (chosen && ps.indexOf(chosen) >= 0) return chosen
        for (const p of ps) if (p.isPlaying) return p
        return ps.length > 0 ? ps[0] : null
    }

    readonly property string title: player ? (player.trackTitle || "") : ""
    readonly property string artist: player ? (player.trackArtist || "") : ""
    readonly property string album: player ? (player.trackAlbum || "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property bool playing: player ? player.isPlaying : false

    function select(p) { chosen = p }

    function fmtTime(s) {
        s = Math.max(0, Math.floor(s))
        const m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // MPRIS doesn't push position updates; poll while something plays.
    Timer {
        interval: 1000; repeat: true
        running: root.player !== null && root.playing
        onTriggered: root.player.positionChanged()
    }
}

import QtQuick
import QtQuick.Controls
import Quickshell.Services.Mpris
import qs.services

Column {
    id: root
    property MprisPlayer player: null
    width: parent.width; spacing: 8
    Slider { visible: root.player?.canSeek ?? false; width: parent.width; from: 0; to: Math.max(1, root.player?.length || 0); value: root.player?.position || 0; onMoved: if (root.player) root.player.position = value }
    SHint { visible: root.player?.positionSupported ?? false; text: Media.fmtTime(root.player?.position || 0) + " / " + Media.fmtTime(root.player?.length || 0) }
    Slider { visible: root.player?.volumeSupported ?? false; width: parent.width; from: 0; to: 1; value: root.player?.volume || 0; onMoved: if (root.player) root.player.volume = value }
    Flow { width: parent.width; spacing: 6
        SAction { visible: root.player?.shuffleSupported ?? false; text: "Shuffle"; selected: root.player?.shuffle ?? false; onClicked: root.player.shuffle = !root.player.shuffle }
        SAction { visible: root.player?.loopSupported ?? false; text: "Repeat: " + ["off", "track", "playlist"][root.player?.loopState || 0]; onClicked: root.player.loopState = ((root.player.loopState || 0) + 1) % 3 }
        SAction { text: "Open player"; onClicked: if (root.player) root.player.raise() }
    }
}

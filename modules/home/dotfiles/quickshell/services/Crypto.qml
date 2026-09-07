pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// SOL/USD spot price from Coinbase, refreshed every minute.
Singleton {
    id: root
    property string pair: "SOL-USD"
    property string price: "…"

    Process {
        id: proc
        command: ["curl", "-sf", "--max-time", "10", "https://api.coinbase.com/v2/prices/" + root.pair + "/spot"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = parseFloat(JSON.parse(text).data.amount)
                    root.price = v.toFixed(3)
                } catch (e) { /* keep last value */ }
            }
        }
    }

    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: proc.running = true
    }
}

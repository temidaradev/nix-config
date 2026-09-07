import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.services

// Launcher with providers, Noctalia-style:
//   plain text   apps            /win   open windows       /wall  wallpapers
//   =expr        calculator      /clip  clipboard history  /session  power actions
//   :command     run in a shell  /calc  calculator
PanelWindow {
    id: win
    visible: Launcher.open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.keyboardFocus: Launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string query: ""
    property int current: 0
    property string calcResult: ""

    // ---- provider detection ----
    readonly property string mode: {
        const q = query
        if (q.startsWith("=")) return "calc"
        if (q.startsWith(":")) return "run"
        if (q.startsWith("/")) {
            const w = q.slice(1).split(" ")[0]
            if (["win", "wall", "clip", "session", "calc"].indexOf(w) >= 0) return w
            return "providers"
        }
        return "apps"
    }
    readonly property string arg: mode === "calc" && query.startsWith("=") ? query.slice(1).trim()
                                : mode === "run" ? query.slice(1).trim()
                                : query.startsWith("/") ? query.slice(1).split(" ").slice(1).join(" ").trim() : query.trim()
    readonly property string argLower: arg.toLowerCase()
    function has(s) { return (s || "").toLowerCase().includes(argLower) }

    Process {
        id: qalc
        command: ["qalc", "-t", win.arg]
        stdout: StdioCollector { onStreamFinished: win.calcResult = text.trim() }
    }
    Timer { id: calcDebounce; interval: 120; onTriggered: if (win.mode === "calc" && win.arg !== "") qalc.running = true }

    // ---- results: [{icon (image path) | glyph | image, title, sub, run()}] ----
    readonly property var providers: [
        { key: "win", glyph: "󰖯", title: "/win", sub: "Open windows" },
        { key: "wall", glyph: "󰸉", title: "/wall", sub: "Wallpapers" },
        { key: "clip", glyph: "󰅍", title: "/clip", sub: "Clipboard history" },
        { key: "session", glyph: "⏻", title: "/session", sub: "Lock, suspend, log out, reboot, shut down" },
        { key: "calc", glyph: "󰃬", title: "/calc  or  =", sub: "Calculator (qalc)" },
        { key: "run", glyph: "󰆍", title: ":", sub: "Run a shell command" }
    ]
    readonly property var results: {
        switch (mode) {
        case "apps": {
            const all = Apps.all.filter(e => !e.noDisplay)
            all.sort((a, b) => a.name.localeCompare(b.name))
            const q = argLower
            const score = e => {
                const n = e.name.toLowerCase()
                if (q === "") return 0
                if (n.startsWith(q)) return 0
                if (n.includes(q)) return 1
                if ((e.genericName || "").toLowerCase().includes(q)) return 2
                if ((e.comment || "").toLowerCase().includes(q)) return 3
                if ((e.keywords || []).some(k => k.toLowerCase().includes(q))) return 4
                return -1
            }
            return all.map(e => ({ e, s: score(e) })).filter(x => x.s >= 0).sort((a, b) => a.s - b.s)
                .map(x => ({ icon: Quickshell.iconPath(x.e.icon, "application-x-executable"), title: x.e.name, sub: x.e.genericName || x.e.comment || "", run: () => x.e.execute() }))
        }
        case "providers":
            return providers.filter(p => query.length <= 1 || p.title.includes(query.slice(0, 5))).map(p => ({ glyph: p.glyph, title: p.title, sub: p.sub, keep: true, run: () => { search.text = p.key === "calc" ? "=" : p.key === "run" ? ":" : "/" + p.key + " " } }))
        case "win":
            return Niri.windows.filter(w => has(w.title) || has(w.app_id)).map(w => ({
                icon: Apps.icon(w.app_id), title: w.title || w.app_id, sub: (Apps.entry(w.app_id)?.name ?? w.app_id) + "  ·  workspace " + (Niri.workspaces.find(s => s.id === w.workspace_id)?.idx ?? "?"),
                run: () => Niri.focusWindow(w.id) }))
        case "wall":
            return Wallpaper.available.filter(p => has(p.split("/").pop())).map(p => ({
                image: p, title: p.split("/").pop(), sub: p === Wallpaper.current ? "current" : p.replace(/^\/home\/[^/]+/, "~"), run: () => Wallpaper.set(p) }))
        case "clip":
            return Clipboard.items.filter(c => c.image ? has("image") : has(c.text)).map(c => ({
                glyph: c.image ? "󰋩" : "󰅍", title: c.image ? "Image" : c.text, sub: "", run: () => Clipboard.copy(c) }))
        case "session":
            return [
                { glyph: "󰌾", title: "Lock", run: () => Lock.lock() },
                { glyph: "󰤄", title: "Suspend", run: () => Quickshell.execDetached(["sh", "-c", "qs ipc call lock lock; systemctl suspend"]) },
                { glyph: "󰍃", title: "Log out", run: () => Quickshell.execDetached(["niri", "msg", "action", "quit", "--skip-confirmation"]) },
                { glyph: "󰜉", title: "Reboot", run: () => Quickshell.execDetached(["systemctl", "reboot"]) },
                { glyph: "⏻", title: "Shut down", run: () => Quickshell.execDetached(["systemctl", "poweroff"]) }
            ].filter(a => has(a.title)).map(a => ({ glyph: a.glyph, title: a.title, sub: "", run: a.run }))
        case "calc":
            return [{ glyph: "󰃬", title: arg === "" ? "Type an expression" : (calcResult || "…"), sub: arg === "" ? "e.g. =2^10, =5 km in mi, =100 usd to eur" : "Enter copies the result",
                      run: () => { if (calcResult !== "") Quickshell.execDetached(["sh", "-c", "printf %s " + JSON.stringify(calcResult) + " | wl-copy"]) } }]
        case "run":
            return [{ glyph: "󰆍", title: arg === "" ? "Type a command" : arg, sub: "Enter runs it in a shell", run: () => { if (arg !== "") Quickshell.execDetached(["sh", "-c", arg]) } }]
        }
        return []
    }

    onVisibleChanged: if (visible) { current = 0; calcResult = ""; search.text = ""; search.forceActiveFocus() }
    onQueryChanged: { current = 0; if (mode === "calc") calcDebounce.restart(); else calcResult = "" }
    function submit() {
        const r = results[current]
        if (!r) return
        r.run()
        if (!r.keep) Launcher.hide()
    }

    MouseArea { anchors.fill: parent; onClicked: Launcher.hide() }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: 600; height: 640
        radius: 6
        color: Theme.panelBg
        border.color: Theme.cardBorder; border.width: 1
        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Rectangle {   // search box
                width: parent.width; height: 36
                radius: Theme.radius
                color: Theme.bg2
                border.color: search.activeFocus ? Theme.accent : "transparent"; border.width: 1
                Row {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 8
                    Text { text: win.mode === "apps" ? "" : win.mode === "calc" ? "󰃬" : win.mode === "run" ? "󰆍" : win.mode === "win" ? "󰖯" : win.mode === "wall" ? "󰸉" : win.mode === "clip" ? "󰅍" : win.mode === "session" ? "⏻" : "󰘧"; color: Theme.accent; font.family: Theme.font; font.pointSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    TextInput {
                        id: search
                        width: parent.width - 30
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.fg
                        font.family: Theme.font; font.pointSize: Theme.fontSize
                        clip: true
                        onTextChanged: win.query = text
                        Text {
                            visible: search.text === ""
                            text: "Search apps  ·  / for providers  ·  = calculates  ·  : runs"; color: Theme.fgDim
                            font.family: Theme.font; font.pointSize: Theme.fontSize
                        }
                        Keys.onEscapePressed: { if (search.text !== "") search.text = ""; else Launcher.hide() }
                        Keys.onDownPressed: { win.current = Math.min(win.current + 1, win.results.length - 1); list.positionViewAtIndex(win.current, ListView.Contain) }
                        Keys.onUpPressed: { win.current = Math.max(win.current - 1, 0); list.positionViewAtIndex(win.current, ListView.Contain) }
                        Keys.onReturnPressed: win.submit()
                        Keys.onEnterPressed: win.submit()
                        Keys.onTabPressed: win.current = (win.current + 1) % Math.max(1, win.results.length)
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - 36 - 44 - 16
                clip: true
                model: win.results
                currentIndex: win.current
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                reuseItems: true
                cacheBuffer: 400
                flickDeceleration: 6000
                maximumFlickVelocity: 6000

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width; height: modelData.image ? 64 : 42
                    radius: Theme.radius
                    color: index === win.current ? "#403daee9" : (hover.containsMouse ? "#1affffff" : "transparent")
                    Row {
                        anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                        spacing: 10
                        Item {
                            width: modelData.image ? 90 : 28; height: parent.height
                            IconImage { visible: !!modelData.icon; anchors.centerIn: parent; implicitSize: 26; asynchronous: true; source: modelData.icon || "" }
                            Text { visible: !!modelData.glyph; anchors.centerIn: parent; text: modelData.glyph || ""; color: Theme.accent; font.family: Theme.font; font.pointSize: 16 }
                            Rectangle { visible: !!modelData.image; anchors.centerIn: parent; width: 88; height: 50; radius: 3; color: Theme.bg3; clip: true
                                Image { anchors.fill: parent; source: modelData.image ? "file://" + modelData.image : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true; sourceSize: Qt.size(176, 100) } }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (modelData.image ? 100 : 38)
                            Text { width: parent.width; elide: Text.ElideRight; text: modelData.title; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.fontSize }
                            Text { width: parent.width; elide: Text.ElideRight; visible: text !== ""; text: modelData.sub; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
                        }
                    }
                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: win.current = index
                        onClicked: { win.current = index; win.submit() }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#22ffffff" }

            Row {   // footer
                width: parent.width; height: 36
                spacing: 6
                layoutDirection: Qt.RightToLeft
                component SessionButton: BarButton {
                    property string glyph
                    padding: 10; implicitHeight: 32
                    BarText { text: glyph; font.pointSize: 13 }
                }
                SessionButton { glyph: "⏻"; onClicked: { Launcher.hide(); Launcher.toggleSession() } }
                SessionButton { glyph: "󰌾"; onClicked: { Launcher.hide(); Lock.lock() } }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.results.length + (win.mode === "apps" ? " apps" : " results") + "   ·   /win  /wall  /clip  /session  =calc  :run"
                    color: Theme.fgDim
                    font.family: Theme.font; font.pointSize: Theme.smallSize - 1
                }
            }
        }
    }
}

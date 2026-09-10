import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

PlasmoidItem {
    id: root

    width: 760
    height: 360

    preferredRepresentation: fullRepresentation

    property string fastfetchOutput: ""
    readonly property int refreshMs: (Plasmoid.configuration.refreshIntervalMs || 1000)
    readonly property int fontPx: (Plasmoid.configuration.fontPixelSize || 10)
    readonly property bool useSystemColors: (Plasmoid.configuration.useSystemColors !== false)
    readonly property bool transparentBackground: (Plasmoid.configuration.transparentBackground === true)
    readonly property real backgroundOpacity: (Plasmoid.configuration.backgroundOpacity ?? 1.0)

    readonly property color customForeground: Plasmoid.configuration.foregroundColor || Kirigami.Theme.textColor
    readonly property color customBackground: Plasmoid.configuration.backgroundColor || Kirigami.Theme.backgroundColor

    readonly property real bgAlpha: root.transparentBackground ? 0.0 : Math.max(0.0, Math.min(1.0, root.backgroundOpacity))

    function ansi16ToHex(idx) {
        var palette = [
            "#000000", "#cc0000", "#4e9a06", "#c4a000",
            "#3465a4", "#75507b", "#06989a", "#d3d7cf",
            "#555753", "#ef2929", "#8ae234", "#fce94f",
            "#729fcf", "#ad7fa8", "#34e2e2", "#eeeeec"
        ]
        if (idx < 0 || idx >= palette.length)
            return "#ffffff"
        return palette[idx]
    }

    function ansi256ToHex(n) {
        n = Math.max(0, Math.min(255, n))
        if (n < 16) return ansi16ToHex(n)
        if (n >= 232) {
            var level = 8 + (n - 232) * 10
            var hex = level.toString(16).padStart(2, '0')
            return "#" + hex + hex + hex
        }
        var idx = n - 16
        var r = Math.floor(idx / 36)
        var g = Math.floor((idx % 36) / 6)
        var b = idx % 6
        function comp(v) {
            var c = (v === 0) ? 0 : 55 + v * 40
            return c.toString(16).padStart(2, '0')
        }
        return "#" + comp(r) + comp(g) + comp(b)
    }

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;")
                .replace(/\"/g, "&quot;")
    }

    function renderAnsiToRichText(input) {
        if (!input)
            return ""

        input = input.replace(/\r\n/g, "\n")

        var rows = [[]]
        var r = 0
        var c = 0

        var curFg = null
        var curBg = null
        var curBold = false

        function ensureRow(idx) {
            while (rows.length <= idx)
                rows.push([])
        }

        function ensureCol(row, idx) {
            while (row.length <= idx)
                row.push({ ch: ' ', fg: null, bg: null, bold: false })
        }

        function writeChar(ch) {
            ensureRow(r)
            var row = rows[r]
            ensureCol(row, c)
            row[c] = { ch: ch, fg: curFg, bg: curBg, bold: curBold }
            c += 1
        }

        function moveUp(n) {
            r = Math.max(0, r - n)
        }

        function moveDown(n) {
            r = Math.max(0, r + n)
            ensureRow(r)
        }

        function moveForward(n) {
            c = Math.max(0, c + n)
        }

        function moveBack(n) {
            c = Math.max(0, c - n)
        }

        function setCol1(col1) {
            c = Math.max(0, col1 - 1)
        }

        function setPos1(row1, col1) {
            r = Math.max(0, row1 - 1)
            ensureRow(r)
            c = Math.max(0, col1 - 1)
        }

        function parseIntOrDefault(s, dflt) {
            var n = parseInt(s)
            return isNaN(n) ? dflt : n
        }

        var i = 0
        while (i < input.length) {
            var ch = input[i]

            if (ch === '\u001b' && i + 1 < input.length && input[i + 1] === '[') {
                var j = i + 2
                while (j < input.length) {
                    var code = input[j]
                    if ((code >= 'A' && code <= 'Z') || (code >= 'a' && code <= 'z'))
                        break
                    j += 1
                }

                if (j >= input.length) {
                    break
                }

                var params = input.slice(i + 2, j)
                var finalByte = input[j]

                if (params.startsWith('?'))
                    params = params.slice(1)
                var parts = params.length ? params.split(';') : []

                if (finalByte === 'm') {
                    if (parts.length === 0) parts = ["0"]
                    var p = 0
                    while (p < parts.length) {
                        var codeNum = parseIntOrDefault(parts[p], 0)

                        if (codeNum === 0) {
                            curFg = null
                            curBg = null
                            curBold = false
                            p += 1
                            continue
                        }

                        if (codeNum === 1) { curBold = true; p += 1; continue }
                        if (codeNum === 22) { curBold = false; p += 1; continue }
                        if (codeNum === 39) { curFg = null; p += 1; continue }
                        if (codeNum === 49) { curBg = null; p += 1; continue }

                        if (codeNum >= 30 && codeNum <= 37) { curFg = ansi16ToHex(codeNum - 30); p += 1; continue }
                        if (codeNum >= 90 && codeNum <= 97) { curFg = ansi16ToHex(8 + (codeNum - 90)); p += 1; continue }

                        if (codeNum >= 40 && codeNum <= 47) { curBg = ansi16ToHex(codeNum - 40); p += 1; continue }
                        if (codeNum >= 100 && codeNum <= 107) { curBg = ansi16ToHex(8 + (codeNum - 100)); p += 1; continue }

                        if ((codeNum === 38 || codeNum === 48) && p + 1 < parts.length) {
                            var isFg = (codeNum === 38)
                            var mode = parseIntOrDefault(parts[p + 1], 5)
                            if (mode === 5 && p + 2 < parts.length) {
                                var n256 = parseIntOrDefault(parts[p + 2], 0)
                                if (isFg) curFg = ansi256ToHex(n256)
                                else curBg = ansi256ToHex(n256)
                                p += 3
                                continue
                            }
                            if (mode === 2 && p + 4 < parts.length) {
                                var rr = parseIntOrDefault(parts[p + 2], 0)
                                var gg = parseIntOrDefault(parts[p + 3], 0)
                                var bb = parseIntOrDefault(parts[p + 4], 0)
                                rr = Math.max(0, Math.min(255, rr))
                                gg = Math.max(0, Math.min(255, gg))
                                bb = Math.max(0, Math.min(255, bb))
                                var hex = "#" + rr.toString(16).padStart(2, '0') + gg.toString(16).padStart(2, '0') + bb.toString(16).padStart(2, '0')
                                if (isFg) curFg = hex
                                else curBg = hex
                                p += 5
                                continue
                            }
                        }

                        p += 1
                    }
                } else if (finalByte === 'A') {
                    moveUp(parseIntOrDefault(parts[0], 1))
                } else if (finalByte === 'B') {
                    moveDown(parseIntOrDefault(parts[0], 1))
                } else if (finalByte === 'C') {
                    moveForward(parseIntOrDefault(parts[0], 1))
                } else if (finalByte === 'D') {
                    moveBack(parseIntOrDefault(parts[0], 1))
                } else if (finalByte === 'G') {
                    setCol1(parseIntOrDefault(parts[0], 1))
                } else if (finalByte === 'H' || finalByte === 'f') {
                    setPos1(parseIntOrDefault(parts[0], 1), parseIntOrDefault(parts[1], 1))
                } else if (finalByte === 'K') {
                }

                i = j + 1
                continue
            }

            if (ch === '\n') {
                r += 1
                c = 0
                ensureRow(r)
                i += 1
                continue
            }

            if (ch === '\r') {
                c = 0
                i += 1
                continue
            }

            if (ch === '\t') {
                var nextTab = (Math.floor(c / 8) + 1) * 8
                while (c < nextTab)
                    writeChar(' ')
                i += 1
                continue
            }

            if (ch < ' ' && ch !== ' ') {
                i += 1
                continue
            }

            writeChar(ch)
            i += 1
        }

        var htmlLines = rows.map(function(row) {
            var last = -1
            for (var k = row.length - 1; k >= 0; k--) {
                if (row[k].ch !== ' ') { last = k; break }
            }
            if (last < 0) return ""

            var out = ""
            var openStyle = null
            var run = ""
            function flush() {
                if (!run.length) return
                if (openStyle) {
                    out += "<span style=\"" + openStyle + "\">" + escapeHtml(run) + "</span>"
                } else {
                    out += escapeHtml(run)
                }
                run = ""
            }

            for (var i2 = 0; i2 <= last; i2++) {
                var cell = row[i2]
                var style = ""
                if (cell.fg) style += "color:" + cell.fg + ";"
                if (cell.bg) style += "background-color:" + cell.bg + ";"
                if (cell.bold) style += "font-weight:600;"
                if (!style.length) style = null

                if (style !== openStyle) {
                    flush()
                    openStyle = style
                }
                run += cell.ch
            }
            flush()
            return out
        })

        var body = htmlLines.join("\n").replace(/\n+$/g, '')
        return "<pre>" + body + "</pre>"
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        
        onNewData: function(sourceName, data) {
            var stdout = data["stdout"]
            if (stdout) {
                root.fastfetchOutput = renderAnsiToRichText(stdout)
            }
            disconnectSource(sourceName)
        }
        
        function exec(cmd) {
            connectSource(cmd)
        }
    }

    // Auto-refresh timer
    Timer {
        interval: root.refreshMs
        running: true
        repeat: true
        onTriggered: {
            executable.exec("zsh -lc 'fastfetch --pipe false'")
        }
    }

    Component.onCompleted: {
        executable.exec("zsh -lc 'fastfetch --pipe false'")
    }

    fullRepresentation: Item {
        Layout.preferredWidth: 760
        Layout.preferredHeight: 360
        Layout.minimumWidth: 700
        Layout.minimumHeight: 320

        Rectangle {
            anchors.fill: parent
            color: root.useSystemColors ? Kirigami.Theme.backgroundColor : root.customBackground
            opacity: root.bgAlpha
        }

        TextEdit {
            id: outputText
            anchors.fill: parent
            anchors.margins: 10
            text: root.fastfetchOutput
            readOnly: true
            clip: true
            font.family: "Monospace"
            font.pixelSize: root.fontPx
            color: root.useSystemColors ? Kirigami.Theme.textColor : root.customForeground
            wrapMode: TextEdit.NoWrap
            textFormat: TextEdit.RichText
            selectByMouse: false
        }
    }

    compactRepresentation: PlasmaComponents.Button {
        icon.name: "utilities-system-monitor"
        text: "fastfetch"
        onClicked: root.expanded = !root.expanded
    }
}

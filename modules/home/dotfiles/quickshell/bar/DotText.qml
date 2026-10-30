import QtQuick

Row {
    id: root
    property string text
    property real dot: 3
    property real gap: 1
    property color color: "#ffffff"
    property color offColor: "#14ffffff"
    spacing: dot + gap

    readonly property var glyphs: ({
        "0": "01110100011001110101110011000101110",
        "1": "00100011000010000100001000010001110",
        "2": "01110100010000100010001000100011111",
        "3": "11111000100010000010000011000101110",
        "4": "00010001100101010010111110001000010",
        "5": "11111100001111000001000011000101110",
        "6": "00110010001000011110100011000101110",
        "7": "11111000010001000100010000100001000",
        "8": "01110100011000101110100011000101110",
        "9": "01110100011000101111000010001001100",
        "%": "11000110010001000100010001001100011",
        "-": "00000000000000011111000000000000000",
        " ": "00000000000000000000000000000000000"
    })

    Repeater {
        model: root.text.split("")
        Grid {
            required property string modelData
            readonly property string bits: root.glyphs[modelData] ?? root.glyphs[" "]
            columns: 5
            spacing: root.gap
            Repeater {
                model: 35
                Rectangle {
                    required property int index
                    width: root.dot; height: root.dot; radius: root.dot / 2
                    color: parent.bits[index] === "1" ? root.color : root.offColor
                }
            }
        }
    }
}

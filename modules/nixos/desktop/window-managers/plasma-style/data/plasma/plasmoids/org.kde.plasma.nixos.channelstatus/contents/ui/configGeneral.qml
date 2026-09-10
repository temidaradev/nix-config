import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root
    
    property alias cfg_channelVersion: channelVersionField.text
    property alias cfg_updateInterval: updateIntervalSpinBox.value
    property string cfg_language
    
    Kirigami.FormLayout {
        
        QQC2.ComboBox {
            id: languageComboBox
            Kirigami.FormData.label: "Sprache / Language:"
            
            model: [
                { text: "Automatisch / Automatic", value: "auto" },
                { text: "Deutsch", value: "de" },
                { text: "English", value: "en" }
            ]
            
            textRole: "text"
            valueRole: "value"
            
            currentIndex: {
                var lang = cfg_language || "auto";
                for (var i = 0; i < model.length; i++) {
                    if (model[i].value === lang) return i;
                }
                return 0;
            }
            
            onActivated: {
                cfg_language = model[currentIndex].value;
            }
            
            Component.onCompleted: {
                cfg_language = cfg_language || "auto";
            }
            
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: "Wähle die Anzeigesprache für das Plasmoid\nSelect the display language for the plasmoid"
        }
        
        Item {
            Kirigami.FormData.isSection: true
            height: Kirigami.Units.largeSpacing
        }
        
        QQC2.TextField {
            id: channelVersionField
            Kirigami.FormData.label: "NixOS Channel Version:"
            placeholderText: "25.11"
            
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: "Die Version des NixOS Channels (z.B. 25.11, 24.05, unstable)\nThe version of the NixOS channel (e.g. 25.11, 24.05, unstable)"
        }
        
        QQC2.Label {
            text: "Beispiele / Examples: 25.11, 25.05, unstable, unstable-small"
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            color: Kirigami.Theme.disabledTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        
        Item {
            Kirigami.FormData.isSection: true
            height: Kirigami.Units.largeSpacing
        }
        
        QQC2.SpinBox {
            id: updateIntervalSpinBox
            Kirigami.FormData.label: "Aktualisierungs-Intervall / Update Interval (min):"
            from: 5
            to: 1440
            stepSize: 5
            
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: "Wie oft soll der Status automatisch aktualisiert werden? (5-1440 Minuten)\nHow often should the status be automatically updated? (5-1440 minutes)"
        }
        
        Item {
            Kirigami.FormData.isSection: true
            height: Kirigami.Units.largeSpacing
        }
        
        QQC2.Label {
            Kirigami.FormData.isSection: true
            text: "Hinweise / Notes:"
            font.bold: true
        }
        
        QQC2.Label {
            text: "• Die Channel-Version muss exakt übereinstimmen (ohne 'nixos-' Präfix)\n  The channel version must match exactly (without 'nixos-' prefix)"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
}

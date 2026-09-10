import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "../code/logic.js" as Logic

PlasmoidItem {
    id: root
    
    property var channelStatus: ({ 
        lastUpdated: "Lädt ...", 
        revision: "", 
        status: "loading", 
        channel: "",
        channelStatus: "",
        variant: ""
    })
    property var allChannelsData: []
    
    // Settings
    property string channelVersion: Plasmoid.configuration.channelVersion
    property int updateInterval: Plasmoid.configuration.updateInterval
    property string configLanguage: Plasmoid.configuration.language || "auto"
    property string currentLanguage: {
        if (configLanguage === "auto") {
            return Qt.locale().name.startsWith("de") ? "de" : "en";
        }
        return configLanguage;
    }

    function tr(de, en) {
        var text = currentLanguage === "de" ? de : en;
        // Platzhalter %1, %2, %3 etc.
        for (var i = 2; i < arguments.length; i++) {
            text = text.replace("%" + (i - 1), arguments[i]);
        }
        return text;
    }
    
    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground
    
    Component.onCompleted: {
        Logic.setTranslateFunction(root.tr);
        Logic.setRetryTimer(retryTimer);
        updateStatus();
        updateAllChannels();
    }
    
    Timer {
        id: retryTimer
        repeat: false
        running: false
    }
    
    // Settings changed
    onChannelVersionChanged: {
        console.log("Channel Version geändert auf:", channelVersion);
        updateStatus();
    }
    onUpdateIntervalChanged: {
        console.log("Update Interval geändert auf:", updateInterval);
    }
    onConfigLanguageChanged: {
        console.log("Sprache geändert auf:", configLanguage, "-> Effektiv:", currentLanguage);
        updateStatus();
        updateAllChannels();
    }
    
    compactRepresentation: Item {
        Layout.minimumWidth: compactLayout.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.minimumHeight: compactLayout.implicitHeight + Kirigami.Units.smallSpacing * 2

        TapHandler {
            onTapped: root.expanded = !root.expanded
        }

        ColumnLayout {
            id: compactLayout
            anchors.centerIn: parent
            spacing: 1

            // NixOS 25.11
            QQC2.Label {
                id: versionLabel
                Layout.alignment: Qt.AlignHCenter
                text: "NixOS " + root.channelVersion
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.textColor
            }

            // vor 17 Stunden
            QQC2.Label {
                id: statusLabel
                Layout.alignment: Qt.AlignHCenter
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                text: getCompactText()
                color: getStatusColor()
            }
        }

        function getCompactText() {
            if (root.channelStatus.status === "success") {
                return root.channelStatus.lastUpdated;
            } else if (root.channelStatus.status === "error") {
                return tr("⚠️ Fehler", "⚠️ Error");
            } else if (root.channelStatus.status === "loading") {
                return tr("⏳ Lädt ...", "⏳ Loading...");
            } else if (root.channelStatus.status === "waiting") {
                return tr("⏳ Warte ...", "⏳ Waiting...");
            } else if (root.channelStatus.status === "retrying") {
                return tr("🔄 Retry %1/%2", "🔄 Retry %1/%2", 
                        (root.channelStatus.retryCount || "?"), 
                        (root.channelStatus.maxRetries || "?"));
            } else if (root.channelStatus.status === "not_found") {
                return tr("❓ Nicht gefunden", "❓ Not found");
            } else {
                return tr("❓ Unbekannt", "❓ Unknown");
            }
        }
    }
    
    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 24
        Layout.minimumHeight: Kirigami.Units.gridUnit * 18
        Layout.preferredWidth: Kirigami.Units.gridUnit * 28
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            
            // Header mit Haupt-Channel
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                
                Kirigami.Icon {
                    source: "nix-snowflake"
                    fallback: "package"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                    color: Kirigami.Theme.highlightColor
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    
                    Kirigami.Heading {
                        text: "NixOS Channel-Status"
                        level: 2
                    }
                    
                    QQC2.Label {
                        text: "Version: " + Plasmoid.metaData.version
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.9
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
            
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Kirigami.Theme.disabledTextColor
                opacity: 0.3
            }
            
            // Haupt-Channel Status (kompakt)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 4
                color: Kirigami.Theme.backgroundColor
                border.color: getStatusColor()
                border.width: 2
                radius: Kirigami.Units.cornerRadius
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.largeSpacing
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing
                        
                        // Zeile 1: Status Indikator
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            
                            Rectangle {
                                width: Kirigami.Units.iconSizes.small
                                height: Kirigami.Units.iconSizes.small
                                radius: width / 2
                                color: getStatusColor()
                            }
                            
                            QQC2.Label {
                                text: getStatusText()
                                font.bold: true
                                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
                            }
                        }
                        
                        // Zeile 2: Last Updated (links) und Commit (rechts)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing
                            
                            // Last Updated Bereich (links, flexible Breite)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing
                                
                                QQC2.Label {
                                    text: "⏰"
                                    color: Kirigami.Theme.disabledTextColor
                                }
                                
                                QQC2.Label {
                                    text: root.channelStatus.lastUpdated
                                    color: getStatusColor()
                                    
                                    QQC2.ToolTip.visible: tooltipMouseArea.containsMouse
                                    QQC2.ToolTip.text: getAbsoluteTooltipDateTime(root.channelStatus.rawDateTime)
                                    
                                    MouseArea {
                                        id: tooltipMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                            
                            // Commit Bereich (rechts, minimale Breite)
                            RowLayout {
                                Layout.minimumWidth: implicitWidth
                                spacing: Kirigami.Units.smallSpacing
                                visible: root.channelStatus.commit !== ""
                                
                                QQC2.Label {
                                    text: "🔗"
                                    color: Kirigami.Theme.disabledTextColor
                                }
                                
                                QQC2.Label {
                                    text: root.channelStatus.commit
                                    font.family: "monospace"
                                    
                                    QQC2.ToolTip.visible: commitMouseArea.containsMouse
                                    QQC2.ToolTip.text: tr("Commit auf GitHub öffnen", "Open commit on GitHub")
                                    
                                    MouseArea {
                                        id: commitMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (root.channelStatus.fullCommit) {
                                                Qt.openUrlExternally("https://github.com/NixOS/nixpkgs/commit/" + root.channelStatus.fullCommit);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Kirigami.Heading {
                Layout.fillWidth: true
                text: tr("Alle Channels", "All channels")
                level: 3
            }
            
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                border.color: Kirigami.Theme.disabledTextColor
                border.width: 1
                radius: Kirigami.Units.cornerRadius
                
                QQC2.ScrollView {
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    
                    ListView {
                        id: channelListView
                        model: root.allChannelsData
                        spacing: 0
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: Kirigami.Units.gridUnit * 3
                            color: index % 2 === 0 ? Kirigami.Theme.backgroundColor : Qt.rgba(Kirigami.Theme.backgroundColor.r, Kirigami.Theme.backgroundColor.g, Kirigami.Theme.backgroundColor.b, 0.5)
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Kirigami.Units.smallSpacing
                                anchors.leftMargin: Kirigami.Units.largeSpacing
                                anchors.rightMargin: Kirigami.Units.largeSpacing
                                spacing: Kirigami.Units.largeSpacing
                                
                                // Channel Name
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    text: modelData.channel
                                    font.bold: modelData.channel === "nixos-" + root.channelVersion
                                    font.family: "monospace"
                                    elide: Text.ElideRight
                                }
                                
                                // Last Updated
                                QQC2.Label {
                                    Layout.minimumWidth: implicitWidth
                                    text: modelData.lastUpdated
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    color: Kirigami.Theme.disabledTextColor
                                }
                                
                                Rectangle {
                                    width: 1
                                    Layout.fillHeight: true
                                    color: Kirigami.Theme.disabledTextColor
                                    opacity: 0.3
                                }
                                
                                // Commit Hash (klickbar)
                                QQC2.Label {
                                    Layout.minimumWidth: implicitWidth
                                    Layout.maximumWidth: implicitWidth
                                    text: modelData.commit
                                    font.family: "monospace"
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    
                                    QQC2.ToolTip.visible: listItemMouseArea.containsMouse
                                    QQC2.ToolTip.text: modelData.fullCommit ? 
                                            "Commit auf GitHub öffnen: " + modelData.fullCommit : 
                                            "Kein Commit verfügbar"
                                    
                                    MouseArea {
                                        id: listItemMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: modelData.fullCommit ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (modelData.fullCommit) {
                                                Qt.openUrlExternally("https://github.com/NixOS/nixpkgs/commit/" + modelData.fullCommit);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        QQC2.Label {
                            anchors.centerIn: parent
                            visible: channelListView.count === 0
                            text: tr("Lade Channel-Daten ...", "Loading channel data...")
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }
                }
            }
            
            // Action Buttons
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                
                QQC2.Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: tr("Aktualisieren", "Refresh")
                    icon.name: "view-refresh"
                    onClicked: {
                        updateStatus();
                        updateAllChannels();
                    }
                }
                
                QQC2.Button {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: "Nix Channel Status"
                    icon.name: "internet-web-browser"
                    onClicked: {
                        Qt.openUrlExternally("https://status.nixos.org/");
                    }
                }
            }
            
            // Footer
            QQC2.Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                text: tr("Nächste Aktualisierung in %1 Minuten", "Next update in %1 minutes", root.updateInterval)
                horizontalAlignment: Text.AlignHCenter
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: Kirigami.Theme.disabledTextColor
                font.italic: true
            }
        }
    }
    
    Timer {
        interval: root.updateInterval * 60 * 1000
        running: true
        repeat: true
        onTriggered: {
            updateStatus();
            updateAllChannels();
        }
    }
    
    function updateStatus() {
        channelStatus = { lastUpdated: "Lädt...", commit: "", status: "loading", channel: "nixos-" + channelVersion };
        
        Logic.fetchChannelStatus(channelVersion, function(status) {
            root.channelStatus = status;
        });
    }
    
    function updateAllChannels() {
        Logic.fetchAllChannels(function(channels) {
            root.allChannelsData = channels;
        });
    }

    function getAbsoluteTooltipDateTime(isoString) {
        if (!isoString) return tr("Keine Daten verfügbar", "No data available");
        
        var date = new Date(isoString);
        return Qt.formatDate(date, "dd.MM.yyyy") + " " + Qt.formatTime(date, "hh:mm:ss") + " UTC";
    }

    function getStatusColor() {
        if (root.channelStatus.status === "success") {
            if (isOlderThan48Hours(root.channelStatus.rawDateTime)) {
                return "#ff9500";
            }
            return Kirigami.Theme.positiveTextColor;
        } else if (root.channelStatus.status === "error" || root.channelStatus.status === "not_found") {
            return Kirigami.Theme.negativeTextColor;
        } else if (root.channelStatus.status === "loading" || root.channelStatus.status === "waiting" || root.channelStatus.status === "retrying") {
            return Kirigami.Theme.highlightColor;
        }
        return Kirigami.Theme.textColor;
    }
    
    function isOlderThan48Hours(isoString) {
        if (!isoString) return false;
        var date = new Date(isoString);
        if (isNaN(date)) return false;
        var diffHours = (Date.now() - date.getTime()) / (1000 * 60 * 60);
        return diffHours >= 48;
    }
    
    function getStatusText() {
        if (root.channelStatus.status === "success") {
            return tr("✓ Channel Status für NixOS %1", "✓ Channel status for NixOS %1", root.channelVersion);
        } else if (root.channelStatus.status === "error") {
            return tr("⚠️ Fehler beim Laden", "⚠️ Error loading");
        } else if (root.channelStatus.status === "not_found") {
            return tr("❓ Channel nicht gefunden", "❓ Channel not found");
        } else if (root.channelStatus.status === "loading") {
            return tr("⏳ Lädt ...", "⏳ Loading...");
        } else if (root.channelStatus.status === "waiting") {
            return tr("⏳ Warte auf Verbindung ...", "⏳ Waiting for connection...");
        } else if (root.channelStatus.status === "retrying") {
            return tr("🔄 Verbindungsversuch %1/%2", "🔄 Connection attempt %1/%2", 
                    (root.channelStatus.retryCount || "?"), 
                    (root.channelStatus.maxRetries || "?"));
        }
        return tr("❓ Unbekannter Status", "❓ Unknown status");
    }
}

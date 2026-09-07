pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The shell is the notification daemon. Popups are shown for a few seconds;
// everything stays in history until dismissed from the control center.
Singleton {
    id: root
    property bool dnd: false
    property var popups: []                                   // Notification[] currently on screen
    readonly property var history: server.trackedNotifications.values
    readonly property int count: history.length

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true
            n.closed.connect(() => { root.gone[n.id] = true; root.hidePopup(n) })
            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return
            root.popups = [n].concat(root.popups).slice(0, Settings.s.notifications.maxPopups)
            const ms = n.urgency === NotificationUrgency.Critical ? 0 : (n.expireTimeout > 0 ? n.expireTimeout : Settings.s.notifications.timeoutMs)
            if (ms > 0) timerComp.createObject(root, { n: n, interval: ms })
        }
    }

    component PopupTimer: Timer {
        property var n
        running: true
        onTriggered: { root.hidePopup(n); destroy() }
    }
    Component { id: timerComp; PopupTimer {} }

    property var gone: ({})                                  // ids already closed by the app
    function hidePopup(n) { popups = popups.filter(p => p !== n) }
    function dismiss(n) { hidePopup(n); if (!gone[n.id]) { gone[n.id] = true; n.dismiss() } }
    function clearAll() { for (const n of history.slice()) dismiss(n); popups = [] }
    function activate(n) {
        const a = n.actions.find(x => x.identifier === "default") || n.actions[0]
        if (a) a.invoke()
        dismiss(n)
    }
}

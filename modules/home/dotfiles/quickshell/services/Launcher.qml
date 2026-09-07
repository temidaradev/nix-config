pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Popup state for every bar popup. Only one is open at a time.
// niri binds use: qs ipc call launcher|control|media toggle
Singleton {
    id: root
    property bool open: false            // app drawer
    property bool controlOpen: false
    property bool mediaOpen: false
    property bool dashOpen: false
    property real dashAnchorX: 0
    property bool wallpaperOpen: false
    property bool sidebarOpen: false
    property bool diskOpen: false
    property bool notifOpen: false
    property bool tempOpen: false
    property real notifAnchorX: 0
    property real tempAnchorX: 0
    property real diskAnchorX: 0
    property var trayItem: null          // SystemTrayItem whose menu is open
    property real mediaAnchorX: 0
    property real trayAnchorX: 0

    function closeAll() { open = false; controlOpen = false; mediaOpen = false; dashOpen = false; wallpaperOpen = false; sidebarOpen = false; diskOpen = false; notifOpen = false; tempOpen = false; trayItem = null }
    function toggle() { const o = !open; closeAll(); open = o }
    function show() { closeAll(); open = true }
    function hide() { open = false }
    function toggleControl() { const o = !controlOpen; closeAll(); controlOpen = o }
    function hideControl() { controlOpen = false }
    function toggleMedia(x) { toggleDash(x) }
    function toggleDash(x) { const o = !dashOpen; closeAll(); dashOpen = o; dashAnchorX = x }
    function toggleSidebar() { const o = !sidebarOpen; closeAll(); sidebarOpen = o }
    function toggleNotifs(x) { const o = !notifOpen; closeAll(); notifOpen = o; notifAnchorX = x }
    function toggleTemps(x) { const o = !tempOpen; closeAll(); tempOpen = o; tempAnchorX = x }
    function toggleDisks(x) { const o = !diskOpen; closeAll(); diskOpen = o; diskAnchorX = x }
    function toggleWallpaper() { const o = !wallpaperOpen; closeAll(); wallpaperOpen = o }
    function openTrayMenu(item, x) { const same = trayItem === item; closeAll(); if (!same) { trayItem = item; trayAnchorX = x } }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.hide() }
    }
    IpcHandler { target: "media";   function toggle(): void { root.toggleMedia(root.mediaAnchorX) } }
    IpcHandler {
        target: "control"
        function toggle(): void { root.toggleControl() }
        function hide(): void { root.hideControl() }
    }
    IpcHandler { target: "notifications"; function toggle(): void { root.toggleNotifs(root.notifAnchorX) } }
    IpcHandler { target: "sidebar"; function toggle(): void { root.toggleSidebar() } }
    IpcHandler { target: "dashboard"; function toggle(): void { root.toggleDash(root.dashAnchorX) } }
}

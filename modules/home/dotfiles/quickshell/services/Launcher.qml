pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

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
    property string sidebarTab: "home"
    property bool diskOpen: false
    property bool notifOpen: false
    property bool tempOpen: false
    property bool sessionOpen: false
    property real notifAnchorX: 0
    property real tempAnchorX: 0
    property real diskAnchorX: 0
    property var trayItem: null          // SystemTrayItem whose menu is open
    property real mediaAnchorX: 0
    property real trayAnchorX: 0
    property string menu: ""
    property real menuAnchorX: 0
    signal locate(string name)

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Niri.focusedOutput) ?? Quickshell.screens[0] ?? null
    property var pointerScreen: null
    property var screen: focusedScreen
    property bool _keyboard: false

    function closeAll() {
        open = false; controlOpen = false; mediaOpen = false; dashOpen = false; wallpaperOpen = false; sidebarOpen = false
        diskOpen = false; notifOpen = false; tempOpen = false; sessionOpen = false; trayItem = null; menu = ""
        screen = !_keyboard && pointerScreen ? pointerScreen : focusedScreen
        _keyboard = false
    }
    function fromKeyboard() { _keyboard = true; return root }

    function toggle() { const o = !open; closeAll(); open = o }
    function show() { closeAll(); open = true }
    function hide() { open = false }
    function toggleControl() { const o = !controlOpen; closeAll(); controlOpen = o }
    function hideControl() { controlOpen = false }
    function toggleMedia(x) { toggleDash(x) }
    function toggleDash(x) { const o = !dashOpen; closeAll(); dashOpen = o; dashAnchorX = x }
    function toggleSidebar() { const o = !sidebarOpen; closeAll(); sidebarOpen = o }
    function openSidebar(tab) { closeAll(); sidebarTab = tab; sidebarOpen = true }
    function toggleNotifs(x) { const o = !notifOpen; closeAll(); notifOpen = o; notifAnchorX = x }
    function toggleTemps(x) { const o = !tempOpen; closeAll(); tempOpen = o; tempAnchorX = x }
    function toggleSession() { const o = !sessionOpen; closeAll(); sessionOpen = o }
    function toggleDisks(x) { const o = !diskOpen; closeAll(); diskOpen = o; diskAnchorX = x }
    function toggleWallpaper() { const o = !wallpaperOpen; closeAll(); wallpaperOpen = o }
    function toggleMenu(name, x) { const o = menu !== name; closeAll(); if (o) { menu = name; menuAnchorX = x } }
    function openTrayMenu(item, x) { const same = trayItem === item; closeAll(); if (!same) { trayItem = item; trayAnchorX = x } }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.fromKeyboard().toggle() }
        function show(): void { root.fromKeyboard().show() }
        function hide(): void { root.hide() }
    }
    IpcHandler { target: "media"; function toggle(): void { root.fromKeyboard().toggleMedia(root.focusedScreen ? root.focusedScreen.width / 2 : 0) } }
    IpcHandler {
        target: "control"
        function toggle(): void { root.fromKeyboard().toggleControl() }
        function hide(): void { root.hideControl() }
    }
    IpcHandler { target: "notifications"; function toggle(): void { root.fromKeyboard().toggleNotifs(root.notifAnchorX) } }
    IpcHandler { target: "session"; function toggle(): void { root.fromKeyboard().toggleSession() } }
    IpcHandler {
        target: "sidebar"
        function toggle(): void { root.fromKeyboard().toggleSidebar() }
        function open(tab: string): void { root.fromKeyboard().openSidebar(tab) }
    }
    IpcHandler { target: "menu"; function toggle(name: string): void { root.fromKeyboard().toggleMenu(name, root.focusedScreen ? root.focusedScreen.width / 2 : 0); if (root.menu === name) root.locate(name) } }
    IpcHandler { target: "dashboard"; function toggle(): void { root.fromKeyboard().toggleDash(root.focusedScreen ? root.focusedScreen.width / 2 : 0) } }
}

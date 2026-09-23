//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.bar
import qs.desktop
import qs.services

ShellRoot {
    // singletons that must exist even before a window references them
    Component.onCompleted: { Settings.s; Notifs.count; Wallpaper.current; Devices.all; Battery.present; Brightness.present; Lock.locked; Idle.away; ScreenTime.version }

    LockScreen {}

    Variants {
        model: Quickshell.screens
        Scope {
            required property ShellScreen modelData
            Bar { screen: modelData }
            Desktop { screen: modelData }
            Backdrop { screen: modelData }
        }
    }

    NotificationPopups { screen: Launcher.focusedScreen }
    Osd { screen: Launcher.focusedScreen }

    LazyLoader { active: Launcher.open; AppDrawer { screen: Launcher.screen } }
    LazyLoader { active: Launcher.controlOpen; ControlCenter { screen: Launcher.screen } }
    LazyLoader { active: Launcher.dashOpen; Dashboard { screen: Launcher.screen } }
    LazyLoader { active: Launcher.diskOpen; DiskPopup { screen: Launcher.screen } }
    LazyLoader { active: Launcher.notifOpen; NotificationPanel { screen: Launcher.screen } }
    LazyLoader { active: Launcher.tempOpen; TempPopup { screen: Launcher.screen } }
    LazyLoader { active: Launcher.sidebarOpen; Sidebar { screen: Launcher.screen } }
    LazyLoader { active: Launcher.sessionOpen; SessionMenu { screen: Launcher.screen } }
    LazyLoader { active: Launcher.trayItem !== null; TrayMenu { screen: Launcher.screen } }
    LazyLoader { active: Launcher.wallpaperOpen; WallpaperPicker { screen: Launcher.screen } }
    LazyLoader { active: Launcher.menu === "volume"; VolumePopup { screen: Launcher.screen } }
    LazyLoader { active: Launcher.menu === "bluetooth"; BluetoothPopup { screen: Launcher.screen } }
    LazyLoader { active: Launcher.menu === "battery"; BatteryPopup { screen: Launcher.screen } }
    LazyLoader { active: Launcher.menu === "devices"; DevicesPopup { screen: Launcher.screen } }
    LazyLoader { active: Launcher.menu === "cpu"; CpuPopup { screen: Launcher.screen } }
    LazyLoader { active: Launcher.menu === "memory"; MemoryPopup { screen: Launcher.screen } }
    LazyLoader { active: Launcher.menu === "network"; NetworkPopup { screen: Launcher.screen } }
    LazyLoader { active: Launcher.menu === "layout"; LayoutPopup { screen: Launcher.screen } }
    LazyLoader { active: Launcher.menu === "window"; WindowPopup { screen: Launcher.screen } }
}

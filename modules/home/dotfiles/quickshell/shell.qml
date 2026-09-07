//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.bar
import qs.desktop
import qs.services

ShellRoot {
    // singletons that must exist even before a window references them
    Component.onCompleted: { Settings.s; Notifs.count; Wallpaper.current; Devices.all }

    Variants {
        model: Quickshell.screens
        Scope {
            required property ShellScreen modelData
            Bar { screen: modelData }
            Desktop { screen: modelData }
            Backdrop { screen: modelData }
            AppDrawer { screen: modelData }
            ControlCenter { screen: modelData }
            Dashboard { screen: modelData }
            DiskPopup { screen: modelData }
            NotificationPanel { screen: modelData }
            TempPopup { screen: modelData }
            Sidebar { screen: modelData }
            SettingsWindow { screen: modelData }
            TrayMenu { screen: modelData }
            WallpaperPicker { screen: modelData }
            NotificationPopups { screen: modelData }
            Osd { screen: modelData }
        }
    }
}

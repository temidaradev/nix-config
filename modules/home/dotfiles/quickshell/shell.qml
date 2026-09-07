//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.bar
import qs.desktop
import qs.services

ShellRoot {
    // singletons that must exist even before a window references them
    Component.onCompleted: { Notifs.count; Wallpaper.current }

    Variants {
        model: Quickshell.screens
        Scope {
            required property ShellScreen modelData
            Bar { screen: modelData }
            Desktop { screen: modelData }
            Backdrop { screen: modelData }
            AppDrawer { screen: modelData }
            ControlCenter { screen: modelData }
            MediaPopup { screen: modelData }
            Calendar { screen: modelData }
            TrayMenu { screen: modelData }
            WallpaperPicker { screen: modelData }
            NotificationPopups { screen: modelData }
            Osd { screen: modelData }
        }
    }
}

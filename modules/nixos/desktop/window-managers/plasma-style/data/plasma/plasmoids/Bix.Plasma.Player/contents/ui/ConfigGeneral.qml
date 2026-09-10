/***************************************************************************
 *   Copyright (C) 2014 by Eike Hein <hein@kde.org>                        *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

//import QtQuick 2.15
//import QtQuick.Controls 2.15
//import QtQuick.Dialogs 1.2
//import QtQuick.Layouts 1.0
//import org.kde.plasma.core 2.0 as PlasmaCore
//import org.kde.plasma.components 2.0 as PlasmaComponents
//import org.kde.kquickcontrolsaddons 2.0 as KQuickAddons
//import org.kde.draganddrop 2.0 as DragDrop
//import org.kde.kirigami 2.4 as Kirigami

import QtQuick
import QtQuick.Dialogs
import QtQuick.Controls
import org.kde.kirigami as Kirigami



Item {
    id: root


    property url cfg_musicDirectory
    property bool cfg_continuousScan:continuousScan.checked


    FolderDialog {
        id: folderDialog
        title: i18n("Select Music Directory")
        currentFolder: cfg_musicDirectory
        onAccepted: {
            cfg_musicDirectory = folderDialog.currentFolder
            directory.text = cfg_musicDirectory
        }
    }

    ScrollView {
        id: scrollView
        anchors.fill: parent
        clip: true // asegura que el contenido no se salga

        Kirigami.FormLayout {
            width: scrollView.width


            Item {
                Kirigami.FormData.isSection: true
            }

            Kirigami.ActionTextField {
                id: directory
                Kirigami.FormData.label: i18n("Music Directory")
                text: folderDialog.currentFolder
                readOnly: true
                //Layout.fillWidth: true

                rightActions: Kirigami.Action {
                    icon.name: "folder"
                    onTriggered: folderDialog.open()
                }
            }

            Switch {
                id: continuousScan
                Kirigami.FormData.label: i18n("Continuous Scan")
            }
        }
    }

}

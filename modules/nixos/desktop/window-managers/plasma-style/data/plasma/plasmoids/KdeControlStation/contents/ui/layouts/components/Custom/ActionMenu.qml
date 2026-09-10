import QtQml
import QtQuick.Controls
import QtQuick
import org.kde.iconthemes as KIconThemes
import org.kde.plasma.components as PlasmaComponents


ContextMenuTemplate {
    id: contextMenu

    signal saveConfig

    property alias model: instantiator.model
    
    Instantiator {
        id: instantiator
        delegate: Loader {
            id: menuItemLoader
            asynchronous: true
            required property int index
            required property var model

            sourceComponent:    model.checkable ? checkableItem : 
                                model.valueType === "icon" ? iconSelectorItem :
                                model.valueType === "separator" ? menuSeparator :
                                model.valueType === "save_action" ? save : textInputItem
            onLoaded: {
                if (model.valueType !== "separator") {
                    menuItemLoader.item.model = menuItemLoader.model
                    menuItemLoader.item.index = menuItemLoader.index
                }
            }
        }
    
        onObjectAdded: (index, object) => contextMenu.insertItem(index, object.item)
        onObjectRemoved: (index, object) => contextMenu.removeItem(object)
    }

    Component {
        id:menuSeparator
        MenuSeparator {}
    }

    Component {
        id: save
        ContextMenuItem {
            property int index
            property var model
            checkable: model.checkable
            text: model.name
            onClicked: {
                contextMenu.saveConfig();
                masterWidgetsModel.modelUpdated();
            }
        }
    }

    Component {
        id: checkableItem
        ContextMenuItem {
            property int index
            property var model
            checkable: model.checkable
            checked: model.value
            text: model.name
            onClicked: {
                var initialValue = loader.modelProps[model.changes]
                masterWidgetsModel.changeProperty(loader.itemIndex, model.changes, model.valueType, initialValue, !initialValue, index)
            }
        }
    }

    Component {
        id: textInputItem
        ContextMenuItem {
            property int index
            property var model

            property var initialValue: loader.modelProps[model.changes]
            property var newValue: textField.text

            contentItem: PlasmaComponents.TextField {
                id: textField
                anchors.fill: parent
                placeholderText: model.name
                text: initialValue
                onAccepted: _saveConfig()
            }
            
            Connections {
                target: contextMenu
                function onSaveConfig() {
                    _saveConfig(true);
                }
            }

            function _saveConfig (queued = false) {
                masterWidgetsModel.changeProperty(loader.itemIndex, model.changes, model.valueType, initialValue, newValue, index, queued)
            } 
        }
    }

    Component {
        id: iconSelectorItem
        ContextMenuItem {
            property int index
            property var model

            leftPadding: 0
            rightPadding: 0

            property var _icon: loader.modelProps[model.changes]

            height: 50
            width:50
            contentItem: PlasmaComponents.Button {
                id: iconButton

                icon.name: _icon

                onPressed: iconDialog.open()

                KIconThemes.IconDialog {
                    id: iconDialog
                    
                    property var target: null

                    onIconNameChanged: iconName => {
                        iconButton.icon.name = iconName;
                        masterWidgetsModel.changeProperty(loader.itemIndex, model.changes, model.valueType, _icon, iconName, index);
                        //contextMenu.saveConfig();
                    }
                }
            }
        }
    }
}
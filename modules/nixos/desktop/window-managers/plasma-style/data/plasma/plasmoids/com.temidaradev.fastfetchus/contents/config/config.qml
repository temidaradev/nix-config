import QtQuick
import org.kde.plasma.configuration as PlasmaConfig

PlasmaConfig.ConfigModel {
	PlasmaConfig.ConfigCategory {
		name: "General"
		icon: "configure"
		source: "../ui/configGeneral.qml"
	}
}


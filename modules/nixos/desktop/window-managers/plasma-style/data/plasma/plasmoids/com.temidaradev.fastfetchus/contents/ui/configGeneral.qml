import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Kirigami.FormLayout {
	id: page

	property alias cfg_useSystemColors: useSystemColors.checked
	property alias cfg_foregroundColor: foregroundColorField.text
	property alias cfg_backgroundColor: backgroundColorField.text
	property alias cfg_transparentBackground: transparentBackground.checked
	property alias cfg_backgroundOpacity: backgroundOpacity.value
	property alias cfg_fontPixelSize: fontSize.value
	property alias cfg_refreshIntervalMs: refreshInterval.value

	PlasmaComponents.CheckBox {
		id: useSystemColors
		text: "Use system colors"
		Kirigami.FormData.label: "Theme:"
	}

	PlasmaComponents.TextField {
		id: foregroundColorField
		Kirigami.FormData.label: "Foreground (#RRGGBB):"
		enabled: !useSystemColors.checked
		placeholderText: "#E6E6E6"
	}

	PlasmaComponents.TextField {
		id: backgroundColorField
		Kirigami.FormData.label: "Background (#RRGGBB):"
		enabled: !useSystemColors.checked
		placeholderText: "#1E1E1E"
	}

	PlasmaComponents.CheckBox {
		id: transparentBackground
		text: "Transparent background"
		Kirigami.FormData.label: "Background:"
	}

	PlasmaComponents.Slider {
		id: backgroundOpacity
		Kirigami.FormData.label: "Opacity:"
		from: 0.0
		to: 1.0
		stepSize: 0.05
		enabled: !transparentBackground.checked
	}

	PlasmaComponents.SpinBox {
		id: fontSize
		Kirigami.FormData.label: "Font size (px):"
		from: 7
		to: 16
	}

	PlasmaComponents.SpinBox {
		id: refreshInterval
		Kirigami.FormData.label: "Refresh (ms):"
		from: 250
		to: 10000
		stepSize: 250
	}
}


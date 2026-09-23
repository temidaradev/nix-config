import QtQuick
import qs

Row {
    property string k
    property string v
    width: parent.width; spacing: 10
    Text { width: 110; text: parent.k; elide: Text.ElideRight; color: Theme.fgDim; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
    Text { width: parent.width - 120; text: parent.v; wrapMode: Text.Wrap; color: Theme.fg; font.family: Theme.font; font.pointSize: Theme.smallSize - 1 }
}

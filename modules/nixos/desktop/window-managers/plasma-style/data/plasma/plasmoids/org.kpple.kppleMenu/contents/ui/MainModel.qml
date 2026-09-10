/*
 *  SPDX-FileCopyrightText: zayronxio
 *  SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import org.kde.plasma.plasma5support 2.0 as P5Support
import org.kde.ksysguard.sensors as Sensors


Item {
    signal ready

    signal readySimpleModel

    property var values: []
    property string plasmaV: ""
    property string qtV: ""
    property string osN: ""

    property bool proceExe: false
    property bool soExe: false
    property bool fullRamExe: false
    property bool qtVExe: false
    property bool plasmaExe: false
    property var itemsInModel: mainModel.count

    property int retrys: 0

    property alias infoModel: mainModel

    ListModel {
        id: mainModel
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: {
            var exitCode = data["exit code"]
            var exitStatus = data["exit status"]
            var stdout = data["stdout"]
            var stderr = data["stderr"]
            exited(sourceName, exitCode, exitStatus, stdout, stderr)
            disconnectSource(sourceName)
        }

        function exec(cmd) {
            if (cmd) {
                connectSource(cmd)
            }
        }

        signal exited(string cmd, int exitCode, int exitStatus, string stdout, string stderr)
    }

    Connections {
        target: executable
        onExited: {
            if (!proceExe) {
                if (stdout.trim() !== "") {
                    values.push(stdout.trim());
                } else {
                    values.push("searching");
                }
                proceExe = true;
                executable.exec(commandMap[1].command); // Ejecuta el siguiente comando
            } else if (!soExe) {
                if (stdout.trim() !== "") {
                    values.push(stdout.trim());
                } else {
                    values.push("searching");
                }
                soExe = true;
                executable.exec(commandMap[2].command); // Ejecuta el último comando
            } else if (!fullRamExe) {
                if (stdout.trim() !== "") {
                    values.push(stdout.trim());
                } else {
                    values.push("searching");
                }
                fullRamExe = true;
                executable.exec(commandMap[3].command);
            } else if (!qtVExe) {
                if (stdout.trim() !== "") {
                    values.push(stdout.trim());
                } else {
                    values.push("searching");
                }
                qtVExe = true;
                ready()
            }
        }
    }

    // Define los nombres y comandos para cada entrada
    property var commandMap: {
        0: { name: i18n("Processor"), command: "grep 'model name' /proc/cpuinfo | uniq | awk -F': ' '{print $2}'" },
        1: { name: i18n("SO"), command: "lsb_release -d | sed 's/Description://g; s/^[ \t]*//'" },
        2: { name: i18n("RAM"), command: "(free -h --si | awk '/Mem:/ {print $2}' | sed 's/G//g')" },
        3: { name: i18n("Qt Version"), command: "grep 'qtVersion' $HOME/.config/QtProject.conf | sed 's/qtVersion=//g'"}
    }

    onReady: {
        for (let key in commandMap) {
            let entry = commandMap[key];
            var name = entry.name
            var value = values[key]
            console.log(value)
            mainModel.append({
                name: name,
                value: name === "RAM" ? value + " GB" : value
            });
            if ( key === "3") {
                console.log("este si esta iniciando")
                readySimpleModel()
            }

        }

    }

    onReadySimpleModel: {
        if (plasmaExe) {
            mainModel.append({
                name: i18n("Plasma"),
                value: plasmaV
            });
        } else {
            retry.start()
        }
    }

    onItemsInModelChanged: {
        if (itemsInModel === 5 && qtV !== "" && mainModel.get(3).value === "searching") {
            mainModel.get(3).value = qtV
            //mainModel.set(3, {"value":qtV})
        }
        if (itemsInModel === 5 && osN !== "" && mainModel.get(1).value === "searching") {
            mainModel.get(1).value = osN
            mainModel.set(3, {"value":qtV})
        }
    }

    Timer {
        id: retry
        interval: 800
        repeat: false
        running: false
        onTriggered: {
            if (plasmaExe) {
                mainModel.append({
                    name: i18n("Plasma"),
                    value: plasmaV
                });
            } else {
                retrys = +1
                if (retrys < 5) {
                    retry.start()
                }
            }
        }
    }

    Sensors.SensorDataModel {
        id: plasmaVersionModel
        sensors: ["os/plasma/plasmaVersion"]
        enabled: true

        onDataChanged: {
            console.log("esto si se esta ejecutando?")
            const value = data(index(0, 0), Sensors.SensorDataModel.Value);
            console.log("esto si se esta ejecutando?", value)
            if (value !== undefined && value !== null) {
                plasmaV = value
                plasmaExe = true
            }
        }
    }

    Sensors.SensorDataModel {
        id: qtVersionModel
        sensors: ["os/plasma/qtVersion"]
        enabled: true

        onDataChanged: {
            const value = data(index(0, 0), Sensors.SensorDataModel.Value);
            if (value !== undefined && value !== null) {
                qtV = value
                //plasmaExe = true
            }
        }
    }

    Sensors.SensorDataModel {
        id: osModel
        sensors: ["os/system/name"]
        enabled: true

        onDataChanged: {
            const value = data(index(0, 0), Sensors.SensorDataModel.Value);
            if (value !== undefined && value !== null) {
                osN = value
                //plasmaExe = true
            }
        }
    }


    Component.onCompleted: {
        executable.exec(commandMap[0].command);
    }
}

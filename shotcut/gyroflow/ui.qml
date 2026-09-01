/*
 * Shotcut frontend for the Gyroflow frei0r plugin.
 * Derived from Gyroflow's Kdenlive metadata and the Shotcut forum prototype.
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Shotcut.Controls as Shotcut
import org.shotcut.qml as Shotcut

Item {
    id: root

    property string defaultProjectPath: ""
    property real defaultSmoothness: 0.5
    property bool defaultOverview: false
    property real defaultTimestampScale: 1.0
    property bool blockUpdate: true

    function inferredProjectPath() {
        var resource = producer.resource || "";
        var query = resource.indexOf("?");
        if (query >= 0)
            resource = resource.substring(0, query);
        var slash = Math.max(resource.lastIndexOf("/"), resource.lastIndexOf("\\"));
        var dot = resource.lastIndexOf(".");
        if (dot > slash)
            resource = resource.substring(0, dot);
        return resource + ".gyroflow";
    }

    function setControls() {
        blockUpdate = true;
        projectFile.url = filter.get("Project");
        smoothness.value = filter.getDouble("Smoothness");
        overview.checked = filter.get("Overview") === "1";
        var scale = filter.getDouble("TimestampScale");
        timestampScale.value = scale > 0 ? scale : defaultTimestampScale;
        blockUpdate = false;
    }

    width: 360
    height: 250

    Component.onCompleted: {
        defaultProjectPath = inferredProjectPath();
        if (filter.isNew) {
            filter.set("Project", defaultProjectPath);
            filter.set("Smoothness", defaultSmoothness);
            filter.set("Overview", defaultOverview ? 1 : 0);
            filter.set("TimestampScale", defaultTimestampScale);
        }
        setControls();
    }

    Shotcut.File {
        id: projectFile

        onUrlChanged: {
            projectLabel.text = fileName || qsTr("No project selected");
            projectTip.text = filePath || qsTr("Select a .gyroflow project file");
            projectLabel.color = fileName.length > 0 && exists() ? activePalette.text : "red";
            if (!blockUpdate)
                filter.set("Project", filePath);
        }
    }

    Shotcut.FileDialog {
        id: projectDialog
        title: qsTr("Select Gyroflow project file")
        nameFilters: [qsTr("Gyroflow project (*.gyroflow)"), qsTr("All files (*)")]
        onAccepted: projectFile.url = selectedFile
    }

    GridLayout {
        columns: 3
        anchors.fill: parent
        anchors.margins: 8

        Shotcut.Button {
            text: qsTr("Open project")
            onClicked: {
                settings.openPath = producer.resource;
                projectDialog.open();
            }
        }

        Label {
            id: projectLabel
            Layout.fillWidth: true
            elide: Text.ElideMiddle
            Shotcut.HoverTip { id: projectTip }
        }

        Shotcut.UndoButton {
            onClicked: projectFile.url = defaultProjectPath
        }

        Label {
            text: qsTr("Smoothness")
            Layout.alignment: Qt.AlignRight
        }

        Shotcut.SliderSpinner {
            id: smoothness
            Layout.fillWidth: true
            minimumValue: 0
            maximumValue: 1
            stepSize: 0.01
            decimals: 2
            onValueChanged: {
                if (!blockUpdate)
                    filter.set("Smoothness", value);
            }
        }

        Shotcut.UndoButton {
            onClicked: smoothness.value = defaultSmoothness
        }

        Label {
            text: qsTr("Overview")
            Layout.alignment: Qt.AlignRight
            Shotcut.HoverTip {
                text: qsTr("Show the complete source area around the stabilized frame.")
            }
        }

        CheckBox {
            id: overview
            leftPadding: 0
            onClicked: filter.set("Overview", checked ? 1 : 0)
        }

        Shotcut.UndoButton {
            onClicked: {
                overview.checked = defaultOverview;
                filter.set("Overview", defaultOverview ? 1 : 0);
            }
        }

        Label {
            text: qsTr("Time scale")
            Layout.alignment: Qt.AlignRight
            Shotcut.HoverTip {
                text: qsTr("Scale Gyroflow timestamps for footage whose playback speed has changed.")
            }
        }

        Shotcut.SliderSpinner {
            id: timestampScale
            Layout.fillWidth: true
            minimumValue: 0.01
            maximumValue: 10
            stepSize: 0.01
            decimals: 2
            suffix: "x"
            onValueChanged: {
                if (!blockUpdate)
                    filter.set("TimestampScale", value);
            }
        }

        Shotcut.UndoButton {
            onClicked: timestampScale.value = defaultTimestampScale
        }

        Shotcut.TipBox {
            Layout.columnSpan: 3
            Layout.fillWidth: true
            text: qsTr("First save a project containing gyro data from Gyroflow. Shotcut currently restarts frei0r time after changing a clip's In point, so trimming or splitting can desynchronize stabilization. Use an untrimmed clip or a stabilized intermediate.")
        }

        Item { Layout.fillHeight: true }
    }

    Connections {
        target: filter
        function onChanged() { setControls(); }
        function onPropertyChanged(name) { setControls(); }
    }
}

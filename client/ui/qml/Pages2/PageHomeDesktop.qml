import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    // macOS system palette accents (dark appearance)
    readonly property color macGreen: "#32D74B"
    readonly property color macRed: "#FF453A"
    readonly property color sidebarColor: AmneziaStyle.color.onyxBlack
    readonly property color contentColor: AmneziaStyle.color.midnightBlack
    readonly property color cardColor: AmneziaStyle.color.translucentWhite

    property int selectedIndex: -1
    property var selectedInfo: ({})
    property var selectedContainers: []
    property bool pendingSwitch: false

    function refreshSelection() {
        var count = ServersUiController.getServersCount()
        if (count === 0) {
            selectedIndex = -1
            selectedInfo = {}
            selectedContainers = []
            return
        }
        if (selectedIndex < 0 || selectedIndex >= count) {
            selectedIndex = ServersUiController.getServerIndexById(ServersUiController.defaultServerId)
            if (selectedIndex < 0) {
                selectedIndex = 0
            }
        }
        selectedInfo = ServersUiController.getServerInfo(selectedIndex)
        selectedContainers = ServersUiController.getServerContainers(selectedIndex)
    }

    function connectToSelected() {
        if (selectedIndex < 0) {
            return
        }
        if (ConnectionController.isConnected) {
            if (selectedInfo.isDefault) {
                return
            }
            var switchIndex = selectedIndex
            showQuestionDrawer(qsTr("Switch connection?"),
                               qsTr("The current connection will be closed, then \"%1\" will be connected.").arg(selectedInfo.name),
                               qsTr("Switch"), qsTr("Cancel"),
                               function() {
                                   root.pendingSwitch = true
                                   root.selectedIndex = switchIndex
                                   ConnectionController.closeConnection()
                               },
                               function() {})
        } else {
            if (!selectedInfo.isDefault) {
                ServersUiController.setDefaultServerAtIndex(selectedIndex)
            }
            ConnectionController.openConnection()
        }
    }

    Component.onCompleted: refreshSelection()

    Connections {
        target: ServersUiController
        function onDefaultServerIdChanged() {
            root.refreshSelection()
        }
    }

    Connections {
        target: ConnectionController
        function onConnectionStateChanged() {
            if (root.pendingSwitch
                    && !ConnectionController.isConnected
                    && !ConnectionController.isConnectionInProgress) {
                root.pendingSwitch = false
                ServersUiController.setDefaultServerAtIndex(root.selectedIndex)
                ConnectionController.openConnection()
            }
        }
    }

    Connections {
        target: ImportController
        function onImportFinished() {
            root.refreshSelection()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ===================== Sidebar =====================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 224
            color: root.sidebarColor

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.topMargin: 14
                    Layout.bottomMargin: 6

                    text: qsTr("Connections")
                    color: AmneziaStyle.color.mutedGray
                    font.pixelSize: 11
                    font.weight: 600
                }

                ListView {
                    id: serversListView

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    model: ServersModel
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds

                    onCountChanged: root.refreshSelection()

                    delegate: Item {
                        width: serversListView.width
                        height: 40

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            radius: 6
                            color: index === root.selectedIndex ? AmneziaStyle.color.sheerWhite
                                                                : (rowMouseArea.containsMouse ? AmneziaStyle.color.barelyTranslucentWhite
                                                                                              : AmneziaStyle.color.transparent)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 8

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: isDefault && ConnectionController.isConnected ? root.macGreen
                                                                                     : AmneziaStyle.color.charcoalGray
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: name
                                    color: AmneziaStyle.color.paleGray
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: hostName
                                    color: AmneziaStyle.color.mutedGray
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        MouseArea {
                            id: rowMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.selectedIndex = index
                                root.refreshSelection()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: AmneziaStyle.color.translucentWhite
                }

                Item {
                    Layout.fillWidth: true
                    height: 40

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        spacing: 6

                        Text {
                            text: "+"
                            color: AmneziaStyle.color.mutedGray
                            font.pixelSize: 18
                        }

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Add connection")
                            color: AmneziaStyle.color.mutedGray
                            font.pixelSize: 13
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addMenu.popup()
                    }

                    Menu {
                        id: addMenu

                        MenuItem {
                            text: qsTr("Config file from disk…")
                            onTriggered: {
                                var fileName = SystemController.getFileName(qsTr("Open config file"),
                                                                            qsTr("All files (*)"))
                                if (fileName !== "") {
                                    if (ImportController.extractConfigFromFile(fileName)) {
                                        PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
                                    }
                                }
                            }
                        }

                        MenuItem {
                            text: qsTr("vpn:// key or subscription link…")
                            onTriggered: {
                                PageController.goToPage(PageEnum.PageSetupWizardTextKey)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            width: 1
            color: AmneziaStyle.color.translucentWhite
        }

        // ===================== Detail pane =====================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: root.contentColor

            Text {
                anchors.centerIn: parent
                visible: root.selectedIndex < 0
                text: qsTr("Add a connection to get started")
                color: AmneziaStyle.color.mutedGray
                font.pixelSize: 15
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16
                visible: root.selectedIndex >= 0

                // Header
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.selectedInfo.name !== undefined ? root.selectedInfo.name : ""
                        color: AmneziaStyle.color.paleGray
                        font.pixelSize: 22
                        font.weight: 700
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        spacing: 6

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: root.selectedInfo.isDefault && ConnectionController.isConnected ? root.macGreen
                                                                                                   : AmneziaStyle.color.charcoalGray
                        }

                        Text {
                            text: root.selectedInfo.isDefault ? ConnectionController.connectionStateText
                                                              : qsTr("Not connected")
                            color: AmneziaStyle.color.mutedGray
                            font.pixelSize: 13
                        }
                    }
                }

                // Info card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: infoColumn.implicitHeight + 24
                    radius: 10
                    color: root.cardColor

                    ColumnLayout {
                        id: infoColumn

                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.preferredWidth: 120
                                text: qsTr("Server")
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 13
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.selectedInfo.hostName !== undefined ? root.selectedInfo.hostName : ""
                                color: AmneziaStyle.color.paleGray
                                font.pixelSize: 13
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: AmneziaStyle.color.translucentWhite
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.preferredWidth: 120
                                Layout.alignment: Qt.AlignTop
                                text: qsTr("Protocol")
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 13
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: root.selectedContainers

                                    delegate: Rectangle {
                                        required property var modelData

                                        width: protocolChipText.implicitWidth + 20
                                        height: 24
                                        radius: 12
                                        color: modelData.isDefault ? AmneziaStyle.color.softGoldenApricot
                                                                   : AmneziaStyle.color.translucentWhite
                                        border.width: modelData.isDefault ? 1 : 0
                                        border.color: AmneziaStyle.color.goldenApricot

                                        Text {
                                            id: protocolChipText
                                            anchors.centerIn: parent
                                            text: modelData.name
                                            color: AmneziaStyle.color.paleGray
                                            font.pixelSize: 12
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                ServersUiController.setDefaultContainerAtIndex(root.selectedIndex,
                                                                                               modelData.containerIndex)
                                                root.refreshSelection()
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.selectedContainers.length === 0
                                    text: root.selectedInfo.defaultContainerName !== undefined ? root.selectedInfo.defaultContainerName : ""
                                    color: AmneziaStyle.color.paleGray
                                    font.pixelSize: 13
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: AmneziaStyle.color.translucentWhite
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.preferredWidth: 120
                                text: qsTr("Port")
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 13
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    for (var i = 0; i < root.selectedContainers.length; ++i) {
                                        if (root.selectedContainers[i].isDefault) {
                                            var proto = root.selectedContainers[i].transportProto
                                            return root.selectedContainers[i].port
                                                    + (proto !== "" ? " · " + proto.toUpperCase() : "")
                                        }
                                    }
                                    return "—"
                                }
                                color: AmneziaStyle.color.paleGray
                                font.pixelSize: 13
                            }
                        }
                    }
                }

                // Action buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    BasicButtonType {
                        Layout.preferredWidth: 160

                        text: ConnectionController.isConnectionInProgress ? ConnectionController.connectionStateText
                                                                          : qsTr("Connect")
                        enabled: !(ConnectionController.isConnected && root.selectedInfo.isDefault)
                                 && !ConnectionController.isConnectionInProgress

                        defaultColor: AmneziaStyle.color.goldenApricot
                        hoveredColor: Qt.lighter(AmneziaStyle.color.goldenApricot, 1.1)
                        pressedColor: Qt.darker(AmneziaStyle.color.goldenApricot, 1.1)

                        clickedFunc: function() {
                            root.connectToSelected()
                        }
                    }

                    BasicButtonType {
                        Layout.preferredWidth: 160

                        visible: ConnectionController.isConnected || ConnectionController.isConnectionInProgress
                        text: qsTr("Disconnect")

                        defaultColor: AmneziaStyle.color.transparent
                        hoveredColor: AmneziaStyle.color.translucentWhite
                        pressedColor: AmneziaStyle.color.sheerWhite
                        textColor: root.macRed
                        borderWidth: 1
                        borderColor: AmneziaStyle.color.charcoalGray

                        clickedFunc: function() {
                            ConnectionController.closeConnection()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    BasicButtonType {
                        Layout.preferredWidth: 200

                        text: DiagnosticsController.isCheckInProgress ? qsTr("Checking…") : qsTr("Check connection")
                        enabled: !DiagnosticsController.isCheckInProgress && root.selectedIndex >= 0

                        defaultColor: AmneziaStyle.color.transparent
                        hoveredColor: AmneziaStyle.color.translucentWhite
                        pressedColor: AmneziaStyle.color.sheerWhite
                        textColor: AmneziaStyle.color.paleGray
                        borderWidth: 1
                        borderColor: AmneziaStyle.color.charcoalGray

                        clickedFunc: function() {
                            var port = ""
                            var proto = ""
                            for (var i = 0; i < root.selectedContainers.length; ++i) {
                                if (root.selectedContainers[i].isDefault) {
                                    port = root.selectedContainers[i].port
                                    proto = root.selectedContainers[i].transportProto
                                }
                            }
                            DiagnosticsController.startCheck(root.selectedInfo.hostName, port, proto,
                                                             ConnectionController.isConnected)
                        }
                    }
                }

                // Check log
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: AmneziaStyle.color.barelyTranslucentWhite

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Check log")
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 11
                                font.weight: 600
                            }

                            Text {
                                text: qsTr("Copy")
                                color: copyMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                                   : AmneziaStyle.color.mutedGray
                                font.pixelSize: 11

                                MouseArea {
                                    id: copyMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        GC.copyToClipBoard(checkLogArea.text)
                                        PageController.showNotificationMessage(qsTr("Log copied"))
                                    }
                                }
                            }

                            Text {
                                Layout.leftMargin: 12
                                text: qsTr("Clear")
                                color: clearMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                                    : AmneziaStyle.color.mutedGray
                                font.pixelSize: 11

                                MouseArea {
                                    id: clearMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: checkLogArea.text = ""
                                }
                            }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            TextArea {
                                id: checkLogArea

                                readOnly: true
                                wrapMode: TextEdit.Wrap
                                color: AmneziaStyle.color.lightGray
                                font.family: "Menlo"
                                font.pixelSize: 11
                                selectByMouse: true
                                background: Rectangle { color: AmneziaStyle.color.transparent }

                                Connections {
                                    target: DiagnosticsController
                                    function onLogAppended(line) {
                                        checkLogArea.append(line)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

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
    property bool isRenaming: false
    property int importGeneration: 0

    // per-server diagnostics logs
    property var checkLogs: ({})
    property string checkingServerId: ""

    function currentServerId() {
        return selectedInfo.serverId !== undefined ? selectedInfo.serverId : ""
    }

    function appendCheckLog(serverId, line) {
        var logs = checkLogs
        logs[serverId] = (logs[serverId] !== undefined ? logs[serverId] : "") + line + "\n"
        checkLogs = logs
        if (serverId === currentServerId()) {
            checkLogArea.text = logs[serverId]
        }
    }

    function refreshSelection() {
        isRenaming = false
        var count = ServersUiController.getServersCount()
        if (count === 0) {
            selectedIndex = -1
            selectedInfo = {}
            selectedContainers = []
            checkLogArea.text = ""
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
        checkLogArea.text = checkLogs[currentServerId()] !== undefined ? checkLogs[currentServerId()] : ""
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

    function runCheck() {
        if (selectedIndex < 0 || DiagnosticsController.isCheckInProgress) {
            return
        }
        var port = ""
        var proto = ""
        for (var i = 0; i < selectedContainers.length; ++i) {
            if (selectedContainers[i].isDefault) {
                port = selectedContainers[i].port
                proto = selectedContainers[i].transportProto
            }
        }
        checkingServerId = currentServerId()
        DiagnosticsController.startCheck(selectedInfo.hostName, port, proto, ConnectionController.isConnected)
    }

    function importFromText(key) {
        if (key === "") {
            return
        }
        if (ImportController.isSubscriptionLink(key)) {
            PageController.showBusyIndicator(true)
            var imported = ImportController.importSubscription(key)
            PageController.showBusyIndicator(false)
            if (imported) {
                addConnectionModal.close()
                PageController.showNotificationMessage(qsTr("Subscription imported"))
            }
        } else if (ImportController.extractConfigFromData(key)) {
            ImportController.importConfig()
            addConnectionModal.close()
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
            root.importGeneration += 1
            root.refreshSelection()
        }
    }

    Connections {
        target: DiagnosticsController
        function onLogAppended(line) {
            root.appendCheckLog(root.checkingServerId, line)
        }
    }

    // small bordered button used in the title row
    component SmallButton: Rectangle {
        id: smallButtonRoot

        property string text
        property var clickedFunc
        property bool isEnabled: true

        width: smallButtonText.implicitWidth + 24
        height: 32
        radius: 16
        color: smallButtonMouseArea.containsMouse && isEnabled ? AmneziaStyle.color.translucentWhite
                                                               : AmneziaStyle.color.transparent
        border.width: 1
        border.color: AmneziaStyle.color.charcoalGray
        opacity: isEnabled ? 1.0 : 0.4

        Text {
            id: smallButtonText
            anchors.centerIn: parent
            text: smallButtonRoot.text
            color: AmneziaStyle.color.paleGray
            font.pixelSize: 12
        }

        MouseArea {
            id: smallButtonMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: smallButtonRoot.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (smallButtonRoot.isEnabled && smallButtonRoot.clickedFunc) {
                    smallButtonRoot.clickedFunc()
                }
            }
        }
    }

    // sidebar footer action row
    component SidebarAction: Item {
        id: sidebarActionRoot

        property string icon
        property string text
        property var clickedFunc

        Layout.fillWidth: true
        height: 34

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            radius: 6
            color: sidebarActionMouseArea.containsMouse ? AmneziaStyle.color.barelyTranslucentWhite
                                                        : AmneziaStyle.color.transparent
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8

            Text {
                text: sidebarActionRoot.icon
                color: AmneziaStyle.color.mutedGray
                font.pixelSize: 14
            }

            Text {
                Layout.fillWidth: true
                text: sidebarActionRoot.text
                color: AmneziaStyle.color.mutedGray
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: sidebarActionMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (sidebarActionRoot.clickedFunc) {
                    sidebarActionRoot.clickedFunc()
                }
            }
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

                SidebarAction {
                    icon: "+"
                    text: qsTr("Add connection")
                    clickedFunc: function() { addConnectionModal.open() }
                }

                SidebarAction {
                    icon: "↻"
                    text: qsTr("Update from vpn.devkz.ru")
                    visible: (root.importGeneration, serversListView.count, ImportController.hasSubscriptions())
                    clickedFunc: function() {
                        PageController.showBusyIndicator(true)
                        var updated = ImportController.refreshSubscriptions()
                        PageController.showBusyIndicator(false)
                        if (updated) {
                            PageController.showNotificationMessage(qsTr("Profiles updated"))
                        }
                    }
                }

                SidebarAction {
                    icon: "⚙"
                    text: qsTr("Settings")
                    clickedFunc: function() { PageController.goToPage(PageEnum.PageSettings) }
                }

                Item { height: 8 }
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

                // Title row: name + rename, check button, connect switch
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                visible: !root.isRenaming
                                text: root.selectedInfo.name !== undefined ? root.selectedInfo.name : ""
                                color: AmneziaStyle.color.paleGray
                                font.pixelSize: 22
                                font.weight: 700
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: !root.isRenaming
                                text: "✎"
                                color: renameMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                                     : AmneziaStyle.color.mutedGray
                                font.pixelSize: 16

                                MouseArea {
                                    id: renameMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        renameField.text = root.selectedInfo.name
                                        root.isRenaming = true
                                        renameField.forceActiveFocus()
                                    }
                                }
                            }

                            TextField {
                                id: renameField

                                Layout.preferredWidth: 280
                                visible: root.isRenaming
                                color: AmneziaStyle.color.paleGray
                                font.pixelSize: 18
                                background: Rectangle {
                                    color: AmneziaStyle.color.translucentWhite
                                    radius: 6
                                    border.width: 1
                                    border.color: AmneziaStyle.color.goldenApricot
                                }
                                onAccepted: {
                                    if (text.trim() !== "") {
                                        ServersUiController.editServerName(root.selectedInfo.serverId, text.trim())
                                    }
                                    root.refreshSelection()
                                }
                                Keys.onEscapePressed: root.isRenaming = false
                            }

                            Item { Layout.fillWidth: true }
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
                                text: {
                                    if (root.selectedInfo.isDefault === true) {
                                        if (ConnectionController.isConnected || ConnectionController.isConnectionInProgress) {
                                            return ConnectionController.connectionStateText
                                        }
                                    }
                                    return qsTr("Not connected")
                                }
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 13
                            }
                        }
                    }

                    SmallButton {
                        text: DiagnosticsController.isCheckInProgress ? qsTr("Checking…") : qsTr("Check")
                        isEnabled: !DiagnosticsController.isCheckInProgress
                        clickedFunc: function() { root.runCheck() }
                    }

                    SwitcherType {
                        id: connectionSwitch

                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 32

                        text: ""
                        checked: ConnectionController.isConnected && root.selectedInfo.isDefault === true
                        enabled: !ConnectionController.isConnectionInProgress && root.selectedIndex >= 0

                        onToggled: {
                            var wantOn = checked
                            checked = Qt.binding(function() {
                                return ConnectionController.isConnected && root.selectedInfo.isDefault === true
                            })
                            if (wantOn) {
                                root.connectToSelected()
                            } else {
                                ConnectionController.closeConnection()
                            }
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

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: AmneziaStyle.color.translucentWhite
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            Text {
                                text: qsTr("Connection settings…")
                                color: serverSettingsMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                                             : AmneziaStyle.color.mutedGray
                                font.pixelSize: 13

                                MouseArea {
                                    id: serverSettingsMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ServersUiController.processedServerId = root.selectedInfo.serverId
                                        PageController.goToPage(PageEnum.PageSettingsServerInfo)
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: qsTr("Delete connection")
                                color: deleteMouseArea.containsMouse ? root.macRed : AmneziaStyle.color.mutedGray
                                font.pixelSize: 13

                                MouseArea {
                                    id: deleteMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var serverId = root.selectedInfo.serverId
                                        showQuestionDrawer(qsTr("Delete \"%1\"?").arg(root.selectedInfo.name),
                                                           qsTr("The connection profile will be removed from this device."),
                                                           qsTr("Delete"), qsTr("Cancel"),
                                                           function() {
                                                               ServersUiController.removeServer(serverId)
                                                               root.selectedIndex = -1
                                                               root.refreshSelection()
                                                           },
                                                           function() {})
                                    }
                                }
                            }
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
                                    onClicked: {
                                        var logs = root.checkLogs
                                        logs[root.currentServerId()] = ""
                                        root.checkLogs = logs
                                        checkLogArea.text = ""
                                    }
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
                            }
                        }
                    }
                }
            }
        }
    }

    // ===================== Add connection modal =====================
    Popup {
        id: addConnectionModal

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 460
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: keyField.textField.text = ""

        Overlay.modal: Rectangle {
            color: AmneziaStyle.color.translucentMidnightBlack
        }

        background: Rectangle {
            color: AmneziaStyle.color.onyxBlack
            radius: 12
            border.width: 1
            border.color: AmneziaStyle.color.sheerWhite
        }

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                Layout.fillWidth: true
                text: qsTr("Add connection")
                color: AmneziaStyle.color.paleGray
                font.pixelSize: 17
                font.weight: 700
            }

            BasicButtonType {
                Layout.fillWidth: true

                text: qsTr("Choose config file…")

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                textColor: AmneziaStyle.color.paleGray
                borderWidth: 1
                borderColor: AmneziaStyle.color.charcoalGray

                clickedFunc: function() {
                    var fileName = SystemController.getFileName(qsTr("Open config file"), qsTr("All files (*)"))
                    if (fileName !== "") {
                        if (ImportController.extractConfigFromFile(fileName)) {
                            ImportController.importConfig()
                            addConnectionModal.close()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle { Layout.fillWidth: true; height: 1; color: AmneziaStyle.color.translucentWhite }
                Text { text: qsTr("or"); color: AmneziaStyle.color.mutedGray; font.pixelSize: 11 }
                Rectangle { Layout.fillWidth: true; height: 1; color: AmneziaStyle.color.translucentWhite }
            }

            TextFieldWithHeaderType {
                id: keyField

                Layout.fillWidth: true

                headerText: qsTr("vpn:// key, config text or subscription link")
                textField.placeholderText: "vpn:// | [Interface]… | https://vpn.devkz.ru/api/sub/…"
                buttonText: qsTr("Paste")

                clickedFunc: function() {
                    textField.text = ""
                    textField.paste()
                }
            }

            BasicButtonType {
                Layout.fillWidth: true

                text: qsTr("Import")

                defaultColor: AmneziaStyle.color.goldenApricot
                hoveredColor: Qt.lighter(AmneziaStyle.color.goldenApricot, 1.1)
                pressedColor: Qt.darker(AmneziaStyle.color.goldenApricot, 1.1)

                clickedFunc: function() {
                    root.importFromText(keyField.textField.text)
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Load available profiles from vpn.devkz.ru")
                color: devkzMouseArea.containsMouse ? AmneziaStyle.color.goldenApricot
                                                    : AmneziaStyle.color.mutedGray
                font.pixelSize: 12

                MouseArea {
                    id: devkzMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (ImportController.hasSubscriptions()) {
                            PageController.showBusyIndicator(true)
                            var updated = ImportController.refreshSubscriptions()
                            PageController.showBusyIndicator(false)
                            if (updated) {
                                addConnectionModal.close()
                                PageController.showNotificationMessage(qsTr("Profiles updated"))
                            }
                        } else {
                            keyField.textField.text = "https://vpn.devkz.ru/api/sub/"
                            keyField.textField.forceActiveFocus()
                            keyField.textField.cursorPosition = keyField.textField.text.length
                        }
                    }
                }
            }
        }
    }
}

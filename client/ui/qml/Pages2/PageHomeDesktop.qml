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
    readonly property color macAmber: "#FFD60A"
    readonly property color sidebarColor: AmneziaStyle.color.onyxBlack
    readonly property color contentColor: AmneziaStyle.color.midnightBlack
    readonly property color cardColor: AmneziaStyle.color.translucentWhite

    property int selectedIndex: -1
    property var selectedInfo: ({})
    property var selectedContainers: []
    property bool pendingSwitch: false
    property bool isRenaming: false
    property int importGeneration: 0
    property string lastLoggedState: ""
    property var subscriptionStatuses: ({})

    // bottom panel tab: 0 = log, 1 = traffic graph
    property int bottomTab: 0

    // rolling traffic-speed history for the live graph (per-second deltas)
    property int speedHistorySize: 60
    property var rxHistory: []
    property var txHistory: []
    property real lastRxSpeed: 0
    property real lastTxSpeed: 0

    function pushSpeedSample(rx, tx) {
        var rh = rxHistory.slice(); var th = txHistory.slice()
        rh.push(rx); th.push(tx)
        while (rh.length > speedHistorySize) { rh.shift(); th.shift() }
        rxHistory = rh; txHistory = th
        lastRxSpeed = rx; lastTxSpeed = tx
    }

    function resetSpeedHistory() {
        rxHistory = []; txHistory = []
        lastRxSpeed = 0; lastTxSpeed = 0
    }

    // bytes/s → human string (auto KB/s or Mbps)
    function speedText(bytesPerSec) {
        if (bytesPerSec >= 125000) { // ~1 Mbit/s
            return (bytesPerSec * 8 / 1e6).toFixed(1) + " Mbps"
        }
        return Math.round(bytesPerSec / 1024) + " KB/s"
    }

    // per-server diagnostics logs
    property var checkLogs: ({})
    property string checkingServerId: ""

    function currentServerId() {
        return selectedInfo.serverId !== undefined ? selectedInfo.serverId : ""
    }

    // subscription health → "ok" | "new" (loaded, never connected yet) |
    // "offline" (was reachable, now timed out) | "unknown" (no status)
    function statusKind(serverId) {
        var status = root.subscriptionStatuses[serverId]
        if (status === undefined) {
            return "unknown"
        }
        if (status.alive) {
            return "ok"
        }
        return status.reason === "no_handshake_yet" ? "new" : "offline"
    }

    function statusDotColor(serverId) {
        switch (statusKind(serverId)) {
        case "offline": return root.macRed
        case "new":     return root.macAmber
        default:        return AmneziaStyle.color.charcoalGray
        }
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
            confirmDialog.ask(qsTr("Switch connection?"),
                              qsTr("The current connection will be closed, then \"%1\" will be connected.").arg(selectedInfo.name),
                              qsTr("Switch"), false,
                              function() {
                                  root.pendingSwitch = true
                                  root.selectedIndex = switchIndex
                                  ConnectionController.closeConnection()
                              })
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
            var state
            if (ConnectionController.isConnected) {
                state = qsTr("Connected")
            } else if (ConnectionController.isConnectionInProgress) {
                state = ConnectionController.connectionStateText
            } else {
                state = qsTr("Disconnected")
            }
            if (state !== root.lastLoggedState) {
                root.lastLoggedState = state
                root.appendCheckLog(ServersUiController.defaultServerId,
                                    Qt.formatTime(new Date(), "hh:mm:ss") + "  " + state)
            }

            if (!ConnectionController.isConnected) {
                root.resetSpeedHistory()
            }

            if (root.pendingSwitch
                    && !ConnectionController.isConnected
                    && !ConnectionController.isConnectionInProgress) {
                root.pendingSwitch = false
                ServersUiController.setDefaultServerAtIndex(root.selectedIndex)
                ConnectionController.openConnection()
            }
        }

        function onBytesChanged(receivedBytes, sentBytes) {
            // deltas arrive roughly once per second → treat as bytes/s
            root.pushSpeedSample(receivedBytes, sentBytes)
        }

        function onConnectionErrorOccurred(errorCode) {
            root.appendCheckLog(ServersUiController.defaultServerId,
                                Qt.formatTime(new Date(), "hh:mm:ss") + "  " + qsTr("Connection error (code %1)").arg(errorCode))
            ImportController.sendSubscriptionFeedback(ServersUiController.defaultServerId, false, "connect")
        }
    }

    Connections {
        target: ImportController
        function onImportFinished() {
            root.importGeneration += 1
            root.refreshSelection()
            ImportController.requestSubscriptionStatuses()
        }
        function onSubscriptionStatusesUpdated(statuses) {
            root.subscriptionStatuses = statuses
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: ImportController.requestSubscriptionStatuses()
    }

    // background profile auto-update; the panel answers 304 while nothing changed
    Timer {
        interval: 600000
        repeat: true
        running: true
        onTriggered: ImportController.backgroundRefreshSubscriptions()
    }

    Connections {
        target: DiagnosticsController
        function onCheckCompleted(ok, failedStage) {
            if (!ok && root.checkingServerId !== "") {
                ImportController.sendSubscriptionFeedback(root.checkingServerId, false, failedStage)
            }
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
        property bool destructive: false

        width: smallButtonText.implicitWidth + 24
        height: 32
        radius: 16
        color: smallButtonMouseArea.containsMouse && isEnabled ? AmneziaStyle.color.translucentWhite
                                                               : AmneziaStyle.color.transparent
        border.width: 1
        border.color: destructive ? Qt.alpha(root.macRed, 0.6) : AmneziaStyle.color.charcoalGray
        opacity: isEnabled ? 1.0 : 0.4

        Text {
            id: smallButtonText
            anchors.centerIn: parent
            text: smallButtonRoot.text
            color: smallButtonRoot.destructive ? root.macRed : AmneziaStyle.color.paleGray
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

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 14
                    Layout.bottomMargin: 10
                    spacing: 8

                    Image {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        source: "qrc:/images/devkz-emblem.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "DEVKZ VPN"
                        color: AmneziaStyle.color.paleGray
                        font.pixelSize: 14
                        font.weight: 700
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
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

                        // true while this profile holds the active VPN connection
                        property bool isActiveConnection: isDefault && ConnectionController.isConnected

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            radius: 6
                            color: {
                                if (index === root.selectedIndex) {
                                    return AmneziaStyle.color.sheerWhite
                                }
                                if (isActiveConnection) {
                                    return Qt.alpha(root.macGreen, 0.10)
                                }
                                return rowMouseArea.containsMouse ? AmneziaStyle.color.barelyTranslucentWhite
                                                                  : AmneziaStyle.color.transparent
                            }

                            // green accent bar marking the active connection
                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: parent.height - 12
                                radius: 1.5
                                visible: isActiveConnection
                                color: root.macGreen
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 8

                            // health dot: red = offline, amber = loaded-but-unused,
                            // grey = ok/unknown. "connected" is the chip, not a colour.
                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: root.statusDotColor(serverId)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: name
                                    color: AmneziaStyle.color.paleGray
                                    font.pixelSize: 13
                                    font.weight: isActiveConnection ? 700 : 400
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: {
                                        var kind = root.statusKind(serverId)
                                        if (kind === "offline") {
                                            return hostName + " · " + qsTr("offline")
                                        }
                                        if (kind === "new") {
                                            return hostName + " · " + qsTr("not used yet")
                                        }
                                        return hostName
                                    }
                                    color: {
                                        var kind = root.statusKind(serverId)
                                        if (kind === "offline") {
                                            return Qt.alpha(root.macRed, 0.8)
                                        }
                                        if (kind === "new") {
                                            return Qt.alpha(root.macAmber, 0.9)
                                        }
                                        return AmneziaStyle.color.mutedGray
                                    }
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }

                            // green "Connected" chip — the unambiguous active-connection marker
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                visible: isActiveConnection
                                implicitWidth: connectedChipText.implicitWidth + 16
                                implicitHeight: 18
                                radius: 9
                                color: Qt.alpha(root.macGreen, 0.18)
                                border.width: 1
                                border.color: Qt.alpha(root.macGreen, 0.5)

                                Text {
                                    id: connectedChipText
                                    anchors.centerIn: parent
                                    text: qsTr("ON")
                                    color: root.macGreen
                                    font.pixelSize: 10
                                    font.weight: 700
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
                    text: qsTr("Load from vpn.devkz.ru")
                    clickedFunc: function() {
                        if (ImportController.hasSubscriptions()) {
                            PageController.showBusyIndicator(true)
                            var updated = ImportController.refreshSubscriptions()
                            PageController.showBusyIndicator(false)
                            if (updated) {
                                PageController.showNotificationMessage(qsTr("Profiles updated"))
                            }
                        } else {
                            addConnectionModal.open()
                            keyField.text = "https://vpn.devkz.ru/api/sub/"
                            keyField.forceActiveFocus()
                            keyField.cursorPosition = keyField.text.length
                        }
                    }
                }

                SidebarAction {
                    icon: "⚙"
                    text: qsTr("Settings")
                    clickedFunc: function() { settingsModal.open() }
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

                    // Cancel an in-progress connection attempt (so you can switch servers)
                    SmallButton {
                        visible: ConnectionController.isConnectionInProgress
                        text: qsTr("Cancel")
                        destructive: true
                        clickedFunc: function() { ConnectionController.closeConnection() }
                    }

                    SmallButton {
                        visible: !ConnectionController.isConnectionInProgress
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
                            visible: root.subscriptionStatuses[root.currentServerId()] !== undefined
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.subscriptionStatuses[root.currentServerId()] !== undefined

                            Text {
                                Layout.preferredWidth: 120
                                text: qsTr("Availability")
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 13
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    var status = root.subscriptionStatuses[root.currentServerId()]
                                    if (status === undefined) {
                                        return ""
                                    }
                                    if (status.alive) {
                                        return status.handshakeSecondsAgo >= 0
                                                ? qsTr("Online — handshake %1 s ago").arg(status.handshakeSecondsAgo)
                                                : qsTr("Online")
                                    }
                                    return status.reason === "no_handshake_yet"
                                            ? qsTr("Not used yet — connect once to activate")
                                            : qsTr("Offline — handshake timeout")
                                }
                                color: {
                                    var kind = root.statusKind(root.currentServerId())
                                    if (kind === "offline") {
                                        return root.macRed
                                    }
                                    if (kind === "new") {
                                        return root.macAmber
                                    }
                                    return AmneziaStyle.color.paleGray
                                }
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
                                text: qsTr("Connection details…")
                                color: serverSettingsMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                                             : AmneziaStyle.color.mutedGray
                                font.pixelSize: 13

                                MouseArea {
                                    id: serverSettingsMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var containerIndex = -1
                                        for (var i = 0; i < root.selectedContainers.length; ++i) {
                                            if (root.selectedContainers[i].isDefault) {
                                                containerIndex = root.selectedContainers[i].containerIndex
                                            }
                                        }
                                        if (containerIndex < 0 && root.selectedContainers.length > 0) {
                                            containerIndex = root.selectedContainers[0].containerIndex
                                        }
                                        connectionDetailsModal.show(root.selectedInfo.name,
                                                                    ServersUiController.getContainerDetails(root.selectedIndex, containerIndex))
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
                                        confirmDialog.ask(qsTr("Delete \"%1\"?").arg(root.selectedInfo.name),
                                                          qsTr("The connection profile will be removed from this device."),
                                                          qsTr("Delete"), true,
                                                          function() {
                                                              ServersUiController.removeServer(serverId)
                                                              root.selectedIndex = -1
                                                              root.refreshSelection()
                                                          })
                                    }
                                }
                            }
                        }
                    }
                }

                // Bottom panel: tabs for Log / Traffic
                Rectangle {
                    id: bottomPanel
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    color: AmneziaStyle.color.barelyTranslucentWhite

                    // traffic tab only makes sense for the live connection
                    readonly property bool trafficAvailable: root.selectedInfo.isDefault === true && ConnectionController.isConnected

                    // fall back to the log tab if traffic becomes unavailable
                    onTrafficAvailableChanged: if (!trafficAvailable && root.bottomTab === 1) root.bottomTab = 0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // tab bar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            component TabButton: Text {
                                property bool active: false
                                property var clickedFunc
                                color: active ? AmneziaStyle.color.paleGray
                                              : (tabBtnMouse.containsMouse ? AmneziaStyle.color.paleGray
                                                                          : AmneziaStyle.color.mutedGray)
                                font.pixelSize: 12
                                font.weight: active ? 700 : 400

                                Rectangle {
                                    anchors.top: parent.bottom
                                    anchors.topMargin: 4
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 2
                                    radius: 1
                                    visible: parent.active
                                    color: AmneziaStyle.color.goldenApricot
                                }

                                MouseArea {
                                    id: tabBtnMouse
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (parent.clickedFunc) parent.clickedFunc()
                                }
                            }

                            TabButton {
                                text: qsTr("Log")
                                active: root.bottomTab === 0
                                clickedFunc: function() { root.bottomTab = 0 }
                            }

                            TabButton {
                                visible: bottomPanel.trafficAvailable
                                text: qsTr("Traffic")
                                active: root.bottomTab === 1
                                clickedFunc: function() { root.bottomTab = 1 }
                            }

                            Item { Layout.fillWidth: true }

                            // current speeds (traffic tab) or copy/clear (log tab)
                            Text {
                                visible: root.bottomTab === 1
                                text: "↓ " + root.speedText(root.lastRxSpeed) + "   ↑ " + root.speedText(root.lastTxSpeed)
                                color: AmneziaStyle.color.lightGray
                                font.pixelSize: 12
                                font.weight: 600
                            }

                            Text {
                                visible: root.bottomTab === 0
                                text: qsTr("Copy")
                                color: copyMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                                   : AmneziaStyle.color.mutedGray
                                font.pixelSize: 11

                                MouseArea {
                                    id: copyMouseArea
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        GC.copyToClipBoard(checkLogArea.text)
                                        PageController.showNotificationMessage(qsTr("Log copied"))
                                    }
                                }
                            }

                            Text {
                                visible: root.bottomTab === 0
                                Layout.leftMargin: 12
                                text: qsTr("Clear")
                                color: clearMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                                    : AmneziaStyle.color.mutedGray
                                font.pixelSize: 11

                                MouseArea {
                                    id: clearMouseArea
                                    anchors.fill: parent
                                    anchors.margins: -4
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

                        // tab content
                        StackLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            currentIndex: root.bottomTab

                            // [0] connection log
                            ScrollView {
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

                            // [1] traffic graph
                            Canvas {
                                id: trafficCanvas

                                property var rx: root.rxHistory
                                onRxChanged: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var w = width, h = height
                                    var n = root.speedHistorySize
                                    var rxArr = root.rxHistory, txArr = root.txHistory
                                    if (rxArr.length < 2) {
                                        return
                                    }
                                    var peak = 1
                                    for (var i = 0; i < rxArr.length; ++i) {
                                        peak = Math.max(peak, rxArr[i], txArr[i])
                                    }
                                    peak *= 1.2

                                    function plot(arr, stroke, fill) {
                                        var step = w / (n - 1)
                                        var x0 = w - (arr.length - 1) * step
                                        ctx.beginPath()
                                        for (var i = 0; i < arr.length; ++i) {
                                            var x = x0 + i * step
                                            var y = h - (arr[i] / peak) * (h - 4) - 2
                                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                                        }
                                        ctx.strokeStyle = stroke
                                        ctx.lineWidth = 1.5
                                        ctx.stroke()
                                        ctx.lineTo(x0 + (arr.length - 1) * step, h)
                                        ctx.lineTo(x0, h)
                                        ctx.closePath()
                                        ctx.fillStyle = fill
                                        ctx.fill()
                                    }

                                    plot(txArr, "#0A84FF", "rgba(10,132,255,0.10)")
                                    plot(rxArr, root.macGreen, "rgba(50,215,75,0.12)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    DesktopSettingsModal {
        id: settingsModal
    }

    DesktopConfirmDialog {
        id: confirmDialog
    }

    DesktopConnectionDetailsModal {
        id: connectionDetailsModal
    }

    // ===================== Add connection modal =====================
    Popup {
        id: addConnectionModal

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 420
        padding: 20
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        onOpened: keyField.text = ""

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
            spacing: 12

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Add connection")
                    color: AmneziaStyle.color.paleGray
                    font.pixelSize: 15
                    font.weight: 700
                }

                Text {
                    text: "✕"
                    color: closeModalMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                             : AmneziaStyle.color.mutedGray
                    font.pixelSize: 13

                    MouseArea {
                        id: closeModalMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addConnectionModal.close()
                    }
                }
            }

            // file picker row
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 8
                color: fileRowMouseArea.containsMouse ? AmneziaStyle.color.sheerWhite
                                                      : AmneziaStyle.color.translucentWhite

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    Text {
                        text: "⌘"
                        visible: false
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Choose config file…")
                        color: AmneziaStyle.color.paleGray
                        font.pixelSize: 13
                    }

                    Text {
                        text: "›"
                        color: AmneziaStyle.color.mutedGray
                        font.pixelSize: 13
                    }
                }

                MouseArea {
                    id: fileRowMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var fileName = SystemController.getFileName(qsTr("Open config file"), qsTr("All files (*)"))
                        if (fileName !== "") {
                            if (ImportController.extractConfigFromFile(fileName)) {
                                ImportController.importConfig()
                                addConnectionModal.close()
                            }
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

            Text {
                text: qsTr("vpn:// key, config text or subscription link")
                color: AmneziaStyle.color.mutedGray
                font.pixelSize: 11
                font.weight: 600
            }

            // paste field with inline button
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 8
                color: AmneziaStyle.color.translucentWhite
                border.width: keyField.activeFocus ? 1 : 0
                border.color: AmneziaStyle.color.goldenApricot

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 8
                    spacing: 8

                    TextInput {
                        id: keyField

                        Layout.fillWidth: true
                        color: AmneziaStyle.color.paleGray
                        font.pixelSize: 13
                        clip: true
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: keyField.text === "" && !keyField.activeFocus
                            text: "vpn://…  ·  [Interface]…  ·  https://…"
                            color: AmneziaStyle.color.mutedGray
                            font.pixelSize: 13
                        }

                        Keys.onReturnPressed: root.importFromText(keyField.text)
                    }

                    Text {
                        text: qsTr("Paste")
                        color: pasteMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                            : AmneziaStyle.color.mutedGray
                        font.pixelSize: 12

                        MouseArea {
                            id: pasteMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                keyField.text = ""
                                keyField.paste()
                            }
                        }
                    }
                }
            }

            // import button
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 8
                color: importMouseArea.containsMouse ? Qt.lighter(AmneziaStyle.color.goldenApricot, 1.08)
                                                     : AmneziaStyle.color.goldenApricot
                opacity: keyField.text.trim() !== "" ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Import")
                    color: AmneziaStyle.color.midnightBlack
                    font.pixelSize: 13
                    font.weight: 700
                }

                MouseArea {
                    id: importMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: keyField.text.trim() !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (keyField.text.trim() !== "") {
                            root.importFromText(keyField.text.trim())
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
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
                            keyField.text = "https://vpn.devkz.ru/api/sub/"
                            keyField.forceActiveFocus()
                            keyField.cursorPosition = keyField.text.length
                        }
                    }
                }
            }
        }
    }
}

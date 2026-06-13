import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

import "../Controls2"

Popup {
    id: root

    readonly property color macRed: "#FF453A"
    readonly property color macGreen2: "#32D74B"

    property int currentSection: 0
    property bool amneziaDnsEnabled: false
    property var healthData: ({})

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 700
    height: 540
    padding: 0
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    onOpened: {
        amneziaDnsEnabled = SettingsController.isAmneziaDnsEnabled()
        primaryDnsField.text = SettingsController.primaryDns
        secondaryDnsField.text = SettingsController.secondaryDns
        ImportController.requestSubscriptionHealth()
    }

    Connections {
        target: ImportController
        function onSubscriptionHealthUpdated(health) {
            root.healthData = health
        }
    }

    Overlay.modal: Rectangle {
        color: AmneziaStyle.color.translucentMidnightBlack
    }

    background: Rectangle {
        color: AmneziaStyle.color.onyxBlack
        radius: 12
        border.width: 1
        border.color: AmneziaStyle.color.sheerWhite
    }

    // ---------- reusable pieces ----------

    component CardDivider: Rectangle {
        Layout.fillWidth: true
        height: 1
        color: AmneziaStyle.color.translucentWhite
    }

    component SettingsCard: Rectangle {
        default property alias content: cardColumn.children

        Layout.fillWidth: true
        implicitHeight: cardColumn.implicitHeight + 24
        radius: 10
        color: AmneziaStyle.color.translucentWhite

        ColumnLayout {
            id: cardColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
        }
    }

    component SwitchRow: RowLayout {
        id: switchRow

        property string label
        property string sub: ""
        property bool checked: false
        property bool rowEnabled: true
        property var onToggle

        Layout.fillWidth: true
        spacing: 12
        opacity: rowEnabled ? 1.0 : 0.4

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: switchRow.label
                color: AmneziaStyle.color.paleGray
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }

            Text {
                Layout.fillWidth: true
                visible: switchRow.sub !== ""
                text: switchRow.sub
                color: AmneziaStyle.color.mutedGray
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        SwitcherType {
            Layout.preferredWidth: 52
            Layout.preferredHeight: 32
            text: ""
            enabled: switchRow.rowEnabled
            checked: switchRow.checked
            onToggled: {
                if (switchRow.onToggle) {
                    switchRow.onToggle(checked)
                }
            }
        }
    }

    component MiniButton: Rectangle {
        id: miniButton

        property string text
        property bool destructive: false
        property var clickedFunc

        implicitWidth: miniButtonText.implicitWidth + 24
        implicitHeight: 30
        radius: 15
        color: miniButtonMouseArea.containsMouse ? AmneziaStyle.color.translucentWhite
                                                 : AmneziaStyle.color.transparent
        border.width: 1
        border.color: AmneziaStyle.color.charcoalGray

        Text {
            id: miniButtonText
            anchors.centerIn: parent
            text: miniButton.text
            color: miniButton.destructive ? root.macRed : AmneziaStyle.color.paleGray
            font.pixelSize: 12
        }

        MouseArea {
            id: miniButtonMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (miniButton.clickedFunc) {
                    miniButton.clickedFunc()
                }
            }
        }
    }

    component LinkRow: RowLayout {
        id: linkRow

        property string label
        property string url

        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: linkRow.label
            color: linkRowMouseArea.containsMouse ? AmneziaStyle.color.goldenApricot
                                                  : AmneziaStyle.color.paleGray
            font.pixelSize: 13

            MouseArea {
                id: linkRowMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(linkRow.url)
            }
        }

        Text {
            text: "↗"
            color: AmneziaStyle.color.mutedGray
            font.pixelSize: 12
        }
    }

    component SectionTitle: Text {
        Layout.fillWidth: true
        color: AmneziaStyle.color.mutedGray
        font.pixelSize: 11
        font.weight: 600
    }

    component ModeOption: Item {
        id: modeOption

        property string label
        property bool selected: false
        property var onPick

        Layout.fillWidth: true
        implicitHeight: 24

        RowLayout {
            anchors.fill: parent
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: modeOption.label
                color: modeOptionMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                         : (modeOption.selected ? AmneziaStyle.color.paleGray
                                                                                : AmneziaStyle.color.mutedGray)
                font.pixelSize: 12
                elide: Text.ElideRight
            }

            Text {
                text: "✓"
                visible: modeOption.selected
                color: AmneziaStyle.color.goldenApricot
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: modeOptionMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (modeOption.onPick) {
                    modeOption.onPick()
                }
            }
        }
    }

    component RemovableListRow: Item {
        id: removableRow

        property string label
        property var onRemove

        width: ListView.view ? ListView.view.width : 0
        height: 26

        Text {
            anchors.left: parent.left
            anchors.right: removeMark.left
            anchors.verticalCenter: parent.verticalCenter
            text: removableRow.label
            color: AmneziaStyle.color.paleGray
            font.pixelSize: 12
            elide: Text.ElideMiddle
        }

        Text {
            id: removeMark
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "✕"
            visible: removableRowMouseArea.containsMouse
            color: root.macRed
            font.pixelSize: 11
        }

        MouseArea {
            id: removableRowMouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (removableRow.onRemove) {
                    removableRow.onRemove()
                }
            }
        }
    }

    component DnsField: Rectangle {
        property alias text: dnsInput.text
        property var onCommit

        Layout.preferredWidth: 160
        height: 30
        radius: 8
        color: AmneziaStyle.color.translucentWhite
        border.width: dnsInput.activeFocus ? 1 : 0
        border.color: AmneziaStyle.color.goldenApricot

        TextInput {
            id: dnsInput
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: AmneziaStyle.color.paleGray
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            onEditingFinished: {
                if (parent.onCommit) {
                    parent.onCommit(text.trim())
                }
            }
        }
    }

    // ---------- layout ----------

    DesktopConfirmDialog {
        id: settingsConfirmDialog
    }

    contentItem: RowLayout {
        spacing: 0

        // section rail
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 210
            color: AmneziaStyle.color.transparent

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 14
                anchors.bottomMargin: 14
                spacing: 2

                Text {
                    Layout.leftMargin: 16
                    Layout.bottomMargin: 8
                    text: qsTr("Settings")
                    color: AmneziaStyle.color.paleGray
                    font.pixelSize: 15
                    font.weight: 700
                }

                Repeater {
                    model: [qsTr("General"), qsTr("Connection"), qsTr("Split tunneling"), qsTr("Logging"), qsTr("Backup"), "vpn.devkz.ru", qsTr("About")]

                    delegate: Item {
                        required property int index
                        required property string modelData

                        Layout.fillWidth: true
                        height: 32

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            radius: 6
                            color: index === root.currentSection ? AmneziaStyle.color.sheerWhite
                                                                 : (railMouseArea.containsMouse ? AmneziaStyle.color.barelyTranslucentWhite
                                                                                                : AmneziaStyle.color.transparent)
                        }

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 12
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            color: AmneziaStyle.color.paleGray
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: railMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.currentSection = index
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        Rectangle {
            Layout.fillHeight: true
            width: 1
            color: AmneziaStyle.color.translucentWhite
        }

        // content
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 14
                anchors.rightMargin: 16
                z: 2
                text: "✕"
                color: closeMouseArea.containsMouse ? AmneziaStyle.color.paleGray
                                                    : AmneziaStyle.color.mutedGray
                font.pixelSize: 13

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }

            StackLayout {
                anchors.fill: parent
                anchors.margins: 20
                anchors.topMargin: 16
                currentIndex: root.currentSection

                // ============ General ============
                ColumnLayout {
                    spacing: 12

                    SectionTitle { text: qsTr("GENERAL") }

                    SettingsCard {
                        SwitchRow {
                            label: qsTr("Launch at login")
                            checked: SettingsController.autoStartEnabled
                            onToggle: function(value) { SettingsController.toggleAutoStart(value) }
                        }

                        CardDivider {}

                        SwitchRow {
                            label: qsTr("Start minimized")
                            sub: qsTr("Works together with launch at login")
                            rowEnabled: SettingsController.autoStartEnabled
                            checked: SettingsController.autoStartEnabled && SettingsController.startMinimized
                            onToggle: function(value) { SettingsController.toggleStartMinimized(value) }
                        }
                    }

                    SettingsCard {
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Language")
                                color: AmneziaStyle.color.paleGray
                                font.pixelSize: 13
                            }

                            ComboBox {
                                id: languageCombo

                                Layout.preferredWidth: 190
                                Layout.preferredHeight: 30

                                model: LanguageModel
                                textRole: "languageName"
                                currentIndex: LanguageUiController.currentLanguageIndex
                                onActivated: function(index) { LanguageUiController.changeLanguage(index) }

                                background: Rectangle {
                                    radius: 8
                                    color: AmneziaStyle.color.translucentWhite
                                }

                                contentItem: Text {
                                    leftPadding: 10
                                    rightPadding: 24
                                    verticalAlignment: Text.AlignVCenter
                                    text: languageCombo.displayText
                                    color: AmneziaStyle.color.paleGray
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }

                                indicator: Text {
                                    x: languageCombo.width - width - 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "⌄"
                                    color: AmneziaStyle.color.mutedGray
                                    font.pixelSize: 12
                                }

                                delegate: ItemDelegate {
                                    id: languageDelegate

                                    required property int index
                                    required property string languageName

                                    width: languageCombo.width
                                    height: 28
                                    highlighted: languageCombo.highlightedIndex === index

                                    contentItem: Text {
                                        leftPadding: 6
                                        verticalAlignment: Text.AlignVCenter
                                        text: languageDelegate.languageName
                                        color: AmneziaStyle.color.paleGray
                                        font.pixelSize: 13
                                    }

                                    background: Rectangle {
                                        radius: 6
                                        color: languageDelegate.highlighted ? AmneziaStyle.color.sheerWhite
                                                                            : AmneziaStyle.color.transparent
                                    }
                                }

                                popup: Popup {
                                    y: languageCombo.height + 4
                                    width: languageCombo.width
                                    padding: 4

                                    background: Rectangle {
                                        color: AmneziaStyle.color.onyxBlack
                                        radius: 8
                                        border.width: 1
                                        border.color: AmneziaStyle.color.sheerWhite
                                    }

                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: Math.min(contentHeight, 240)
                                        model: languageCombo.popup.visible ? languageCombo.delegateModel : null
                                        currentIndex: languageCombo.highlightedIndex

                                        ScrollBar.vertical: ScrollBar {}
                                    }
                                }
                            }
                        }
                    }

                    SettingsCard {
                        RowLayout {
                            Layout.fillWidth: true

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    text: qsTr("Reset all settings")
                                    color: AmneziaStyle.color.paleGray
                                    font.pixelSize: 13
                                }

                                Text {
                                    text: qsTr("Removes all servers and resets the application")
                                    color: AmneziaStyle.color.mutedGray
                                    font.pixelSize: 11
                                }
                            }

                            MiniButton {
                                text: qsTr("Reset…")
                                destructive: true
                                clickedFunc: function() {
                                    settingsConfirmDialog.ask(qsTr("Reset all settings?"),
                                                              qsTr("All servers and application settings will be removed."),
                                                              qsTr("Reset"), true,
                                                              function() { SettingsController.clearSettings() })
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // ============ Connection ============
                ColumnLayout {
                    spacing: 12

                    SectionTitle { text: qsTr("CONNECTION") }

                    SettingsCard {
                        SwitchRow {
                            label: qsTr("Use AmneziaDNS")
                            sub: qsTr("When the server has the DNS service installed")
                            checked: root.amneziaDnsEnabled
                            onToggle: function(value) {
                                SettingsController.toggleAmneziaDns(value)
                                root.amneziaDnsEnabled = value
                            }
                        }
                    }

                    SettingsCard {
                        SwitchRow {
                            label: qsTr("Kill switch")
                            sub: qsTr("Block internet if the VPN connection drops")
                            checked: SettingsController.isKillSwitchEnabled
                            onToggle: function(value) { SettingsController.isKillSwitchEnabled = value }
                        }

                        CardDivider {}

                        SwitchRow {
                            label: qsTr("Strict kill switch")
                            sub: qsTr("Block internet even when the VPN is disconnected manually")
                            rowEnabled: SettingsController.isKillSwitchEnabled
                            checked: SettingsController.strictKillSwitchEnabled
                            onToggle: function(value) { SettingsController.strictKillSwitchEnabled = value }
                        }
                    }

                    SettingsCard {
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Primary DNS")
                                color: AmneziaStyle.color.paleGray
                                font.pixelSize: 13
                            }

                            DnsField {
                                id: primaryDnsField
                                onCommit: function(value) { SettingsController.primaryDns = value }
                            }
                        }

                        CardDivider {}

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Secondary DNS")
                                color: AmneziaStyle.color.paleGray
                                font.pixelSize: 13
                            }

                            DnsField {
                                id: secondaryDnsField
                                onCommit: function(value) { SettingsController.secondaryDns = value }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // ============ Split tunneling ============
                ColumnLayout {
                    spacing: 10

                    SectionTitle { text: qsTr("SPLIT TUNNELING") }

                    Text {
                        Layout.fillWidth: true
                        visible: ConnectionController.isConnected
                        text: qsTr("Disconnect the VPN to change split tunneling settings")
                        color: AmneziaStyle.color.goldenApricot
                        font.pixelSize: 11
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10
                        enabled: !ConnectionController.isConnected
                        opacity: enabled ? 1.0 : 0.5

                        SettingsCard {
                            SwitchRow {
                                label: qsTr("Site-based split tunneling")
                                checked: IpSplitTunnelingController.isSplitTunnelingEnabled
                                onToggle: function(value) { IpSplitTunnelingController.toggleSplitTunneling(value) }
                            }

                            CardDivider {}

                            ModeOption {
                                label: qsTr("Only sites from the list go through the VPN")
                                selected: IpSplitTunnelingController.routeMode === 1
                                onPick: function() { IpSplitTunnelingController.routeMode = 1 }
                            }

                            ModeOption {
                                label: qsTr("All sites except the list go through the VPN")
                                selected: IpSplitTunnelingController.routeMode === 2
                                onPick: function() { IpSplitTunnelingController.routeMode = 2 }
                            }

                            CardDivider {}

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                DnsField {
                                    id: siteField
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: -1
                                }

                                MiniButton {
                                    text: qsTr("Add")
                                    clickedFunc: function() {
                                        if (siteField.text.trim() !== "") {
                                            IpSplitTunnelingController.addSite(siteField.text.trim())
                                            siteField.text = ""
                                        }
                                    }
                                }
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 84
                                clip: true
                                model: IpSplitTunnelingModel
                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: ScrollBar {}

                                delegate: RemovableListRow {
                                    label: url
                                    onRemove: function() { IpSplitTunnelingController.removeSite(index) }
                                }
                            }
                        }

                        SettingsCard {
                            SwitchRow {
                                label: qsTr("App-based split tunneling")
                                checked: AppSplitTunnelingController.isSplitTunnelingEnabled
                                onToggle: function(value) { AppSplitTunnelingController.toggleSplitTunneling(value) }
                            }

                            CardDivider {}

                            ModeOption {
                                label: qsTr("Only apps from the list go through the VPN")
                                selected: AppSplitTunnelingController.routeMode === 1
                                onPick: function() { AppSplitTunnelingController.routeMode = 1 }
                            }

                            ModeOption {
                                label: qsTr("All apps except the list go through the VPN")
                                selected: AppSplitTunnelingController.routeMode === 2
                                onPick: function() { AppSplitTunnelingController.routeMode = 2 }
                            }

                            CardDivider {}

                            RowLayout {
                                Layout.fillWidth: true

                                MiniButton {
                                    text: qsTr("Add application…")
                                    clickedFunc: function() {
                                        var fileName = SystemController.getFileName(qsTr("Open executable file"),
                                                                                    qsTr("Applications (*)"))
                                        if (fileName !== "") {
                                            AppSplitTunnelingController.addApp(fileName)
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                clip: true
                                model: AppSplitTunnelingModel
                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: ScrollBar {}

                                delegate: RemovableListRow {
                                    label: appPath
                                    onRemove: function() { AppSplitTunnelingController.removeApp(index) }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }
                    }
                }

                // ============ Logging ============
                ColumnLayout {
                    spacing: 12

                    SectionTitle { text: qsTr("LOGGING") }

                    SettingsCard {
                        SwitchRow {
                            label: qsTr("Enable logs")
                            sub: qsTr("Save app and service logs for troubleshooting")
                            checked: SettingsController.isLoggingEnabled
                            onToggle: function(value) { SettingsController.isLoggingEnabled = value }
                        }
                    }

                    SettingsCard {
                        Text {
                            text: qsTr("Client logs")
                            color: AmneziaStyle.color.mutedGray
                            font.pixelSize: 11
                            font.weight: 600
                        }

                        RowLayout {
                            spacing: 8

                            MiniButton {
                                text: qsTr("Open folder")
                                clickedFunc: function() { SettingsController.openLogsFolder() }
                            }

                            MiniButton {
                                text: qsTr("Export…")
                                clickedFunc: function() {
                                    var fileName = SystemController.getFileName(qsTr("Save"), qsTr("Logs (*.log)"),
                                                                                "AmneziaVPN.log", true, ".log")
                                    if (fileName !== "") {
                                        SettingsController.exportLogsFile(fileName)
                                    }
                                }
                            }

                            MiniButton {
                                text: qsTr("Clear")
                                destructive: true
                                clickedFunc: function() {
                                    SettingsController.clearLogs()
                                    PageController.showNotificationMessage(qsTr("Logs cleared"))
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        CardDivider {}

                        Text {
                            text: qsTr("Service logs")
                            color: AmneziaStyle.color.mutedGray
                            font.pixelSize: 11
                            font.weight: 600
                        }

                        RowLayout {
                            spacing: 8

                            MiniButton {
                                text: qsTr("Open folder")
                                clickedFunc: function() { SettingsController.openServiceLogsFolder() }
                            }

                            MiniButton {
                                text: qsTr("Export…")
                                clickedFunc: function() {
                                    var fileName = SystemController.getFileName(qsTr("Save"), qsTr("Logs (*.log)"),
                                                                                "AmneziaVPN-service.log", true, ".log")
                                    if (fileName !== "") {
                                        SettingsController.exportServiceLogsFile(fileName)
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // ============ Backup ============
                ColumnLayout {
                    spacing: 12

                    SectionTitle { text: qsTr("BACKUP") }

                    SettingsCard {
                        Text {
                            Layout.fillWidth: true
                            text: qsTr("Save all connection profiles and application settings to a file, or restore them from a previously made backup.")
                            color: AmneziaStyle.color.mutedGray
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            spacing: 8

                            MiniButton {
                                text: qsTr("Make backup…")
                                clickedFunc: function() {
                                    var fileName = SystemController.getFileName(qsTr("Save"), qsTr("Backup files (*.backup)"),
                                                                                "AmneziaVPN.backup", true, ".backup")
                                    if (fileName !== "") {
                                        PageController.showBusyIndicator(true)
                                        SettingsController.backupAppConfig(fileName)
                                        PageController.showBusyIndicator(false)
                                        PageController.showNotificationMessage(qsTr("Backup created"))
                                    }
                                }
                            }

                            MiniButton {
                                text: qsTr("Restore…")
                                clickedFunc: function() {
                                    var fileName = SystemController.getFileName(qsTr("Open"), qsTr("Backup files (*.backup)"))
                                    if (fileName !== "") {
                                        PageController.showBusyIndicator(true)
                                        SettingsController.restoreAppConfig(fileName)
                                        PageController.showBusyIndicator(false)
                                        root.close()
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                // ============ vpn.devkz.ru health ============
                ScrollView {
                    id: healthScroll

                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: healthScroll.availableWidth
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true

                            SectionTitle {
                                Layout.fillWidth: true
                                text: "VPN.DEVKZ.RU"
                            }

                            MiniButton {
                                text: qsTr("Refresh")
                                clickedFunc: function() { ImportController.requestSubscriptionHealth() }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.healthData.status === undefined
                            text: ImportController.hasSubscriptions()
                                  ? qsTr("Panel is unreachable or still loading…")
                                  : qsTr("Add a vpn.devkz.ru subscription to see panel diagnostics")
                            color: AmneziaStyle.color.mutedGray
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }

                        SettingsCard {
                            visible: root.healthData.status !== undefined

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("Panel status")
                                    color: AmneziaStyle.color.paleGray
                                    font.pixelSize: 13
                                }

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: root.healthData.status === "healthy" ? root.macGreen2 : "#FFD60A"
                                }

                                Text {
                                    text: root.healthData.status !== undefined ? root.healthData.status : ""
                                    color: AmneziaStyle.color.paleGray
                                    font.pixelSize: 13
                                }
                            }

                            CardDivider {}

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("MSK hub · active exit")
                                    color: AmneziaStyle.color.mutedGray
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: {
                                        if (root.healthData.msk === undefined) {
                                            return ""
                                        }
                                        var exit = root.healthData.msk.active_exit
                                        return root.healthData.msk.addr + " → " + (exit ? exit : qsTr("RU (local)"))
                                    }
                                    color: AmneziaStyle.color.paleGray
                                    font.pixelSize: 12
                                }
                            }

                            CardDivider {}

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("Checked")
                                    color: AmneziaStyle.color.mutedGray
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: {
                                        if (root.healthData.checked_at === undefined) {
                                            return ""
                                        }
                                        var secs = Math.max(0, Math.round((new Date() - new Date(root.healthData.checked_at)) / 1000))
                                        if (secs < 60) {
                                            return qsTr("%1 s ago").arg(secs)
                                        }
                                        return qsTr("%1 min ago").arg(Math.round(secs / 60))
                                    }
                                    color: AmneziaStyle.color.mutedGray
                                    font.pixelSize: 12
                                }
                            }
                        }

                        SettingsCard {
                            visible: root.healthData.exits !== undefined && root.healthData.exits.length > 0

                            Text {
                                text: qsTr("Exits")
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 11
                                font.weight: 600
                            }

                            Repeater {
                                model: root.healthData.exits !== undefined ? root.healthData.exits : []

                                delegate: RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelData.alive ? root.macGreen2 : root.macRed
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label + "  ·  " + modelData.addr
                                        color: AmneziaStyle.color.paleGray
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: modelData.role !== undefined && modelData.role !== ""
                                        text: modelData.role !== undefined ? modelData.role.replace("_", "-") : ""
                                        color: AmneziaStyle.color.mutedGray
                                        font.pixelSize: 11
                                    }

                                    Text {
                                        visible: modelData.active === true
                                        text: qsTr("active")
                                        color: AmneziaStyle.color.goldenApricot
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }

                        SettingsCard {
                            visible: root.healthData.gateways !== undefined && root.healthData.gateways.length > 0

                            Text {
                                text: qsTr("Gateways")
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 11
                                font.weight: 600
                            }

                            Repeater {
                                model: root.healthData.gateways !== undefined ? root.healthData.gateways : []

                                delegate: RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelData.alive ? root.macGreen2 : root.macRed
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label + "  ·  " + modelData.addr + ":" + modelData.port
                                        color: AmneziaStyle.color.paleGray
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: qsTr("s2s %1 s · %2 clients")
                                              .arg(modelData.s2s_handshake_seconds_ago !== null ? modelData.s2s_handshake_seconds_ago : "—")
                                              .arg(modelData.clients_count)
                                        color: AmneziaStyle.color.mutedGray
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }

                        SettingsCard {
                            visible: root.healthData.your_profiles !== undefined && root.healthData.your_profiles.length > 0

                            Text {
                                text: qsTr("Your profiles")
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 11
                                font.weight: 600
                            }

                            Repeater {
                                model: root.healthData.your_profiles !== undefined ? root.healthData.your_profiles : []

                                delegate: RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: modelData.connected ? root.macGreen2 : AmneziaStyle.color.charcoalGray
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name + "  ·  " + modelData.via_label
                                            color: AmneziaStyle.color.paleGray
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: (modelData.connected
                                                   ? qsTr("connected · handshake %1 s ago").arg(modelData.last_handshake_seconds_ago)
                                                   : qsTr("not connected"))
                                                  + (modelData.transfer !== undefined && modelData.transfer !== null
                                                     && modelData.transfer !== ""
                                                     ? "  ·  " + modelData.transfer : "")
                                            color: AmneziaStyle.color.mutedGray
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: modelData.endpoint_ip !== undefined && modelData.endpoint_ip !== null
                                            text: qsTr("from %1  ·  %2").arg(modelData.endpoint_ip !== null ? modelData.endpoint_ip : "")
                                                                        .arg(modelData.address)
                                            color: AmneziaStyle.color.mutedGray
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        SettingsCard {
                            visible: root.healthData.route_presets !== undefined && root.healthData.route_presets.length > 0

                            Text {
                                text: qsTr("Route presets")
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 11
                                font.weight: 600
                            }

                            Repeater {
                                model: root.healthData.route_presets !== undefined ? root.healthData.route_presets : []

                                delegate: RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.label + "  →  " + modelData.exit
                                        color: modelData.enabled ? AmneziaStyle.color.paleGray
                                                                 : AmneziaStyle.color.mutedGray
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.enabled ? "✓" : "—"
                                        color: modelData.enabled ? AmneziaStyle.color.goldenApricot
                                                                 : AmneziaStyle.color.mutedGray
                                        font.pixelSize: 12
                                    }
                                }
                            }
                        }

                        SettingsCard {
                            visible: root.healthData.issues !== undefined && root.healthData.issues.length > 0

                            Text {
                                text: qsTr("Issues")
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 11
                                font.weight: 600
                            }

                            Repeater {
                                model: root.healthData.issues !== undefined ? root.healthData.issues : []

                                delegate: RowLayout {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: modelData.severity === "warn" ? "⚠" : "ℹ"
                                        color: modelData.severity === "warn" ? "#FFD60A" : AmneziaStyle.color.mutedGray
                                        font.pixelSize: 12
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.msg
                                        color: AmneziaStyle.color.paleGray
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }
                        }

                        Item { Layout.preferredHeight: 4 }
                    }
                }

                // ============ About ============
                ColumnLayout {
                    spacing: 12

                    SectionTitle { text: qsTr("ABOUT") }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 12

                        Image {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            source: "qrc:/images/devkz-emblem.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                text: "DEVKZ VPN"
                                color: AmneziaStyle.color.paleGray
                                font.pixelSize: 17
                                font.weight: 700
                            }

                            Text {
                                text: "vpn.devkz.ru"
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 12
                            }
                        }
                    }

                    SettingsCard {
                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Version")
                                color: AmneziaStyle.color.paleGray
                                font.pixelSize: 13
                            }

                            Text {
                                text: SettingsController.getAppVersion()
                                color: AmneziaStyle.color.mutedGray
                                font.pixelSize: 13
                            }
                        }

                        CardDivider {}

                        Text {
                            Layout.fillWidth: true
                            text: qsTr("DEVKZ VPN — by the devkz team and Claude AI, built on a fork of the open-source AmneziaVPN client (GPL-3.0), with a desktop redesign and vpn.devkz.ru integration.")
                            color: AmneziaStyle.color.mutedGray
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }
                    }

                    SettingsCard {
                        LinkRow {
                            label: qsTr("vpn.devkz.ru")
                            url: "https://vpn.devkz.ru"
                        }

                        CardDivider {}

                        LinkRow {
                            label: qsTr("Fork on GitHub")
                            url: "https://github.com/kzhebenev/amnezia-client"
                        }

                        CardDivider {}

                        LinkRow {
                            label: qsTr("AmneziaVPN website")
                            url: LanguageUiController.getCurrentSiteUrl()
                        }

                        CardDivider {}

                        LinkRow {
                            label: qsTr("AmneziaVPN on GitHub")
                            url: "https://github.com/amnezia-vpn/amnezia-client"
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}

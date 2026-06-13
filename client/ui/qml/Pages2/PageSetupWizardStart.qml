import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Config"
import "../Controls2/TextTypes"
import "../Components"

PageType {
    id: root
    enableTimer: (SettingsController.isOnTv()) ? false : true

    function importFromText(key) {
        if (key === "") {
            return
        }
        if (ImportController.isSubscriptionLink(key)) {
            PageController.showBusyIndicator(true)
            var imported = ImportController.importSubscription(key)
            PageController.showBusyIndicator(false)
            if (imported) {
                PageController.showNotificationMessage(qsTr("Subscription imported"))
            }
        } else if (ImportController.extractConfigFromData(key)) {
            ImportController.importConfig()
        }
    }

    Connections {
        target: ImportController
        function onImportFinished() {
            PageController.goToPageHome()
        }
        function onImportErrorOccurred(error, goToPageHome) {
            if (goToPageHome) {
                PageController.goToPageHome()
            }
        }
    }

    // ---------- desktop: redesigned start screen ----------
    Item {
        anchors.fill: parent
        visible: GC.isDesktop()

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 420)
            spacing: 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Welcome")
                color: AmneziaStyle.color.paleGray
                font.pixelSize: 28
                font.weight: 700
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 6
                Layout.bottomMargin: 28
                text: qsTr("Add your first connection to get started")
                color: AmneziaStyle.color.mutedGray
                font.pixelSize: 14
            }

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                text: qsTr("Subscription token, vpn:// key or config text")
                color: AmneziaStyle.color.mutedGray
                font.pixelSize: 11
                font.weight: 600
            }

            // paste field with inline button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
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
                        verticalAlignment: TextInput.AlignVCenter

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: keyField.text === "" && !keyField.activeFocus
                            text: "token  ·  vpn://…  ·  https://vpn.devkz.ru/api/sub/…"
                            color: AmneziaStyle.color.mutedGray
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        Keys.onReturnPressed: root.importFromText(keyField.text.trim())
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
                Layout.topMargin: 10
                Layout.preferredHeight: 44
                radius: 8
                color: importMouseArea.containsMouse ? Qt.lighter(AmneziaStyle.color.goldenApricot, 1.08)
                                                     : AmneziaStyle.color.goldenApricot
                opacity: keyField.text.trim() !== "" ? 1.0 : 0.4

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Import")
                    color: AmneziaStyle.color.midnightBlack
                    font.pixelSize: 14
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

            // divider
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 20
                Layout.bottomMargin: 20
                spacing: 8

                Rectangle { Layout.fillWidth: true; height: 1; color: AmneziaStyle.color.translucentWhite }
                Text { text: qsTr("or"); color: AmneziaStyle.color.mutedGray; font.pixelSize: 11 }
                Rectangle { Layout.fillWidth: true; height: 1; color: AmneziaStyle.color.translucentWhite }
            }

            // file picker
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: 8
                color: fileRowMouseArea.containsMouse ? AmneziaStyle.color.sheerWhite
                                                      : AmneziaStyle.color.translucentWhite

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Choose config file…")
                        color: AmneziaStyle.color.paleGray
                        font.pixelSize: 13
                    }

                    Text {
                        text: "›"
                        color: AmneziaStyle.color.mutedGray
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    id: fileRowMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var nameFilter = "Config files (*.vpn *.ovpn *.conf *.json)"
                        var fileName = SystemController.getFileName(qsTr("Open config file"), nameFilter)
                        if (fileName !== "") {
                            if (ImportController.extractConfigFromFile(fileName)) {
                                ImportController.importConfig()
                            }
                        }
                    }
                }
            }

            // other options -> legacy source picker (self-hosted, QR, backup…)
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 24
                text: qsTr("Other connection options")
                color: otherMouseArea.containsMouse ? AmneziaStyle.color.goldenApricot
                                                    : AmneziaStyle.color.mutedGray
                font.pixelSize: 13

                MouseArea {
                    id: otherMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PageController.goToPage(PageEnum.PageSetupWizardConfigSource)
                }
            }
        }
    }

    // ---------- mobile / TV: original logo + button ----------
    ColumnLayout {
        id: content

        anchors.fill: parent
        spacing: 0
        visible: !GC.isDesktop()

        Image {
            id: image
            source: "qrc:/images/amneziaBigLogo.png"

            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.topMargin: 32 + PageController.safeAreaTopMargin
            Layout.preferredWidth: 360
            Layout.preferredHeight: 287
        }

        BasicButtonType {
            id: startButton
            Layout.fillWidth: true
            Layout.bottomMargin: 48 + PageController.safeAreaBottomMargin
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.alignment: Qt.AlignBottom

            text: qsTr("Let's get started")

            clickedFunc: function() {
                PageController.goToPage(PageEnum.PageSetupWizardConfigSource)
            }
        }
    }

    Timer {
        interval: 250
        running: SettingsController.isOnTv()
        repeat: true
        onTriggered: {
            startButton.forceActiveFocus()
            if (startButton.activeFocus) {
                running = false
            }
        }
    }

    onVisibleChanged: {
        if (visible && SettingsController.isOnTv()) {
            startButton.forceActiveFocus()
        }
    }
}

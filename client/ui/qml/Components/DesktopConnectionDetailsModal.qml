import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

import "../Config"

Popup {
    id: root

    property string serverName: ""
    property var details: ({})

    function show(name, detailsMap) {
        serverName = name
        details = detailsMap
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 480
    padding: 20
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle {
        color: AmneziaStyle.color.translucentMidnightBlack
    }

    background: Rectangle {
        color: AmneziaStyle.color.onyxBlack
        radius: 12
        border.width: 1
        border.color: AmneziaStyle.color.sheerWhite
    }

    component DetailRow: RowLayout {
        property string label
        property string value
        property bool copyable: false

        Layout.fillWidth: true
        spacing: 8
        visible: value !== ""

        Text {
            Layout.preferredWidth: 130
            Layout.alignment: Qt.AlignTop
            text: label
            color: AmneziaStyle.color.mutedGray
            font.pixelSize: 12
        }

        Text {
            Layout.fillWidth: true
            text: value
            color: AmneziaStyle.color.paleGray
            font.pixelSize: 12
            wrapMode: Text.WrapAnywhere
            textFormat: Text.PlainText
        }

        Text {
            visible: copyable
            text: copyMouseArea.containsMouse ? qsTr("copy") : "⧉"
            color: copyMouseArea.containsMouse ? AmneziaStyle.color.paleGray : AmneziaStyle.color.mutedGray
            font.pixelSize: 11

            MouseArea {
                id: copyMouseArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    GC.copyToClipBoard(value)
                    PageController.showNotificationMessage(qsTr("Copied"))
                }
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: qsTr("Connection details")
                    color: AmneziaStyle.color.paleGray
                    font.pixelSize: 15
                    font.weight: 700
                }

                Text {
                    text: root.serverName + (root.details.protocolName !== undefined ? "  ·  " + root.details.protocolName : "")
                    color: AmneziaStyle.color.mutedGray
                    font.pixelSize: 12
                }
            }

            Text {
                text: "✕"
                color: closeMouseArea.containsMouse ? AmneziaStyle.color.paleGray : AmneziaStyle.color.mutedGray
                font.pixelSize: 13

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: detailsColumn.implicitHeight + 24
            radius: 10
            color: AmneziaStyle.color.translucentWhite

            ColumnLayout {
                id: detailsColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                DetailRow {
                    label: qsTr("Endpoint")
                    value: (root.details.hostName !== undefined ? root.details.hostName : "")
                           + (root.details.port !== undefined && root.details.port !== "" ? ":" + root.details.port : "")
                           + (root.details.transportProto !== undefined && root.details.transportProto !== ""
                              ? " · " + root.details.transportProto.toUpperCase() : "")
                    copyable: true
                }

                DetailRow {
                    label: qsTr("Client address")
                    value: root.details.clientIp !== undefined ? root.details.clientIp : ""
                }

                DetailRow {
                    label: qsTr("Allowed IPs")
                    value: root.details.allowedIps !== undefined ? root.details.allowedIps : ""
                }

                DetailRow {
                    label: qsTr("MTU")
                    value: root.details.mtu !== undefined ? root.details.mtu : ""
                }

                DetailRow {
                    label: qsTr("Keepalive")
                    value: root.details.persistentKeepAlive !== undefined && root.details.persistentKeepAlive !== ""
                           ? root.details.persistentKeepAlive + " s" : ""
                }

                DetailRow {
                    label: qsTr("Server public key")
                    value: root.details.serverPubKey !== undefined ? root.details.serverPubKey : ""
                    copyable: true
                }

                DetailRow {
                    label: qsTr("Obfuscation")
                    value: root.details.awgSummary !== undefined ? root.details.awgSummary : ""
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: qsTr("These parameters come from the server and are managed by your VPN provider.")
            color: AmneziaStyle.color.mutedGray
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }
}

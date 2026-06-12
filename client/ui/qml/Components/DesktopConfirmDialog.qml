import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Style 1.0

Popup {
    id: root

    readonly property color macRed: "#FF453A"

    property string titleText
    property string messageText
    property string confirmText: qsTr("OK")
    property string cancelText: qsTr("Cancel")
    property bool destructive: false
    property var onConfirm

    function ask(title, message, confirm, isDestructive, confirmFunc) {
        titleText = title
        messageText = message
        confirmText = confirm
        destructive = isDestructive === true
        onConfirm = confirmFunc
        open()
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 380
    padding: 20
    modal: true
    closePolicy: Popup.CloseOnEscape

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
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: root.titleText
            color: AmneziaStyle.color.paleGray
            font.pixelSize: 15
            font.weight: 700
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            visible: root.messageText !== ""
            text: root.messageText
            color: AmneziaStyle.color.mutedGray
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 8

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitWidth: cancelLabel.implicitWidth + 32
                implicitHeight: 32
                radius: 8
                color: cancelMouseArea.containsMouse ? AmneziaStyle.color.translucentWhite
                                                     : AmneziaStyle.color.transparent
                border.width: 1
                border.color: AmneziaStyle.color.charcoalGray

                Text {
                    id: cancelLabel
                    anchors.centerIn: parent
                    text: root.cancelText
                    color: AmneziaStyle.color.paleGray
                    font.pixelSize: 13
                }

                MouseArea {
                    id: cancelMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }

            Rectangle {
                implicitWidth: confirmLabel.implicitWidth + 32
                implicitHeight: 32
                radius: 8
                color: {
                    var base = root.destructive ? root.macRed : AmneziaStyle.color.goldenApricot
                    return confirmMouseArea.containsMouse ? Qt.lighter(base, 1.1) : base
                }

                Text {
                    id: confirmLabel
                    anchors.centerIn: parent
                    text: root.confirmText
                    color: root.destructive ? AmneziaStyle.color.paleGray : AmneziaStyle.color.midnightBlack
                    font.pixelSize: 13
                    font.weight: 700
                }

                MouseArea {
                    id: confirmMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.close()
                        if (root.onConfirm) {
                            root.onConfirm()
                        }
                    }
                }
            }
        }
    }
}

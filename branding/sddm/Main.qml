// S7 SkyQUBi SDDM greeter — placeholder
// Minimal Qt/QML that renders a dark background and a username+password
// prompt in the S7 sandy-sunset palette. A full animated theme is a
// future polish item.

import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    width: 1920
    height: 1080
    color: "#1a0f1c"

    Text {
        anchors.top: parent.top
        anchors.topMargin: 80
        anchors.horizontalCenter: parent.horizontalCenter
        text: "S7 SkyQUBi"
        color: "#fff8ec"
        font.family: "Cormorant Garamond"
        font.pointSize: 48
        font.italic: false
    }

    Text {
        anchors.top: parent.top
        anchors.topMargin: 160
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Sovereign Computing · Built on Trust"
        color: "#f4c97b"
        font.family: "Lora"
        font.pointSize: 14
        font.italic: true
    }

    Column {
        anchors.centerIn: parent
        spacing: 16
        width: 320

        TextBox {
            id: username
            width: parent.width
            height: 36
            text: userModel.lastUser
            color: "#301a27"
            borderColor: "#6b3f4f"
            focusColor: "#f4c97b"
            font.pointSize: 11

            KeyNavigation.tab: password
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    password.forceActiveFocus()
                    event.accepted = true
                }
            }
        }

        PasswordBox {
            id: password
            width: parent.width
            height: 36
            color: "#301a27"
            borderColor: "#6b3f4f"
            focusColor: "#f4c97b"
            font.pointSize: 11
            tooltipFG: "#faebd4"
            tooltipBG: "#261624"

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    sddm.login(username.text, password.text, sessionIndex)
                    event.accepted = true
                }
            }
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Love is the architecture."
        color: "#c9a4d1"
        font.family: "Cormorant Garamond"
        font.pointSize: 14
        font.italic: true
    }
}

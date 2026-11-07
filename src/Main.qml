import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win

    width: 620
    height: 780
    minimumWidth: 520
    minimumHeight: 620
    visible: true
    title: "Omastream"
    color: "#0e0e10"
    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    property bool helpVisible: false

    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; onActivated: win.close() }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; onActivated: backend.toggleStream() }
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; onActivated: backend.toggleCam() }
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; onActivated: backend.startTest() }

    // A stop never throws work away silently: confirm while a stream runs.
    onClosing: (close) => {
        if (backend.streaming) {
            close.accepted = false
            quitDialog.open()
        }
    }

    ColumnLayout {
        id: content

        anchors.margins: 22
        anchors.fill: parent
        spacing: 14

        // ── header ───────────────────────────────────────────────────────────
        RowLayout {
            spacing: 12

            Rectangle { // the app mark: a screen with a play, drawn, no assets
                width: 44
                height: 44
                radius: 10
                color: "#b31217"

                Rectangle {
                    x: 7
                    y: 9
                    width: 30
                    height: 17
                    radius: 4
                    color: "#ffffff"
                }
                Canvas {
                    x: 7
                    y: 9
                    width: 30
                    height: 17
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.fillStyle = "#b31217"
                        ctx.beginPath()
                        ctx.moveTo(width * 0.34, height * 0.22)
                        ctx.lineTo(width * 0.34, height * 0.78)
                        ctx.lineTo(width * 0.76, height * 0.5)
                        ctx.closePath()
                        ctx.fill()
                    }
                }
                Rectangle {
                    x: 17
                    y: 31
                    width: 13
                    height: 13
                    radius: 6.5
                    color: "#ffffff"
                    Rectangle {
                        anchors.centerIn: parent
                        width: 5
                        height: 5
                        radius: 2.5
                        color: "#b31217"
                    }
                }
            }

            ColumnLayout {
                spacing: 0

                Label {
                    text: "Omastream"
                    font.pixelSize: 22
                    font.bold: true
                    color: "#f2f2f4"
                }
                Label {
                    text: qsTr("YouTube Live from your GPU, one window")
                    font.pixelSize: 12
                    color: "#9a9aa5"
                }
            }

            Item { Layout.fillWidth: true }
        }

        // ── status + go live ──────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            radius: Math.min(14, theme.radius + 8)
            color: backend.streaming ? "#1d1214" : "#17171b"
            border.width: 1
            border.color: backend.streaming ? "#7a1d22" : "#24242a"

            RowLayout {
                anchors {
                    fill: parent
                    margins: 18
                }
                spacing: 18

                ColumnLayout {
                    spacing: 6
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 8

                        Rectangle {
                            visible: backend.streaming
                            width: 10
                            height: 10
                            radius: 5
                            color: "#ff4040"

                            SequentialAnimation on opacity {
                                running: backend.streaming
                                loops: Animation.Infinite
                                NumberAnimation { from: 1; to: 0.3; duration: 850 }
                                NumberAnimation { from: 0.3; to: 1; duration: 850 }
                            }
                        }

                        Label {
                            text: backend.statusLine
                            font.pixelSize: 20
                            font.bold: backend.streaming
                            color: backend.streaming ? "#ff8a8a" : "#c9c9d1"
                        }
                    }

                    Label {
                        text: backend.streaming && backend.mode === "stream"
                              ? qsTr("Streaming to YouTube — click stop when done")
                              : backend.streaming && backend.mode === "file"
                                ? qsTr("A local file records the screen; nothing is uploaded")
                                : qsTr("Ready to go live")
                        font.pixelSize: 12
                        color: "#9a9aa5"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Label {
                        text: backend.lastError
                        font.pixelSize: 12
                        color: "#ff6b6b"
                        wrapMode: Text.WordWrap
                        visible: text !== ""
                        Layout.fillWidth: true
                    }
                }

                ColumnLayout {
                    spacing: 8

                    RoundButton { // Space — the one button that does the job
                        id: mainButton

                        width: 92
                        height: 92
                        padding: 0
                        Material.roundedScale: Material.NotNested
                        enabled: true
                        Material.background: backend.streaming ? "#c62828" : "#b31217"

                        contentItem: Item {
                            // play triangle while idle, stop square while live
                            Canvas {
                                visible: !backend.streaming
                                anchors.centerIn: parent
                                width: 34
                                height: 38
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.fillStyle = "#ffffff"
                                    ctx.beginPath()
                                    ctx.moveTo(0, 0)
                                    ctx.lineTo(0, height)
                                    ctx.lineTo(width, height / 2)
                                    ctx.closePath()
                                    ctx.fill()
                                }
                            }
                            Rectangle {
                                visible: backend.streaming
                                anchors.centerIn: parent
                                width: 24
                                height: 24
                                radius: 4
                                color: "#ffffff"
                            }
                        }
                        onClicked: backend.toggleStream()
                    }

                    Button {
                        id: testButton

                        Layout.alignment: Qt.AlignHCenter
                        flat: true
                        text: qsTr("Test capture")
                        onClicked: backend.startTest()
                    }
                }
            }
        }

        // ── camera bubble ─────────────────────────────────────────────────────
        RowLayout {
            spacing: 14

            Switch {
                text: qsTr("Camera bubble")
                checked: backend.camVisible
                onToggled: backend.toggleCam()
            }

            Item { Layout.fillWidth: true }

            Repeater {
                model: [{ key: "circle", label: qsTr("Circle") }, { key: "1:1", label: qsTr("1:1") }, { key: "16:9", label: qsTr("16:9") }]

                delegate: Rectangle {
                    id: shapePill

                    required property var modelData
                    property bool selected: backend.camShape === modelData.key

                    width: shapeLabel.implicitWidth + 24
                    height: 28
                    radius: 14
                    // the selected shape wears the Omarchy accent
                    color: selected ? theme.accent : "#24242a"

                    Text {
                        id: shapeLabel

                        anchors.centerIn: parent
                        text: shapePill.modelData.label
                        color: shapePill.selected ? theme.accentForeground : "#c9c9d1"
                        font.pixelSize: 12
                        font.bold: shapePill.selected
                    }
                    TapHandler { onTapped: backend.setCamShape(shapePill.modelData.key) }
                }
            }

            Switch {
                text: qsTr("Mirror")
                checked: backend.camFlip
                onToggled: backend.setCamFlip(checked)
            }
        }

        Label {
            visible: backend.camVisible
            text: qsTr("Drag the bubble anywhere, resize with the corner grip; while a stream runs the preview pauses and shows LIVE instead.")
            font.pixelSize: 11
            color: "#9a9aa5"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            leftPadding: 0
        }

        // ── settings ──────────────────────────────────────────────────────────
        Label {
            text: qsTr("Settings")
            font.pixelSize: 14
            font.bold: true
            color: "#f2f2f4"
        }

        GridLayout {
            columns: 2
            columnSpacing: 14
            rowSpacing: 10

            Label {
                text: qsTr("YouTube stream key")
                font.pixelSize: 12
                color: "#9a9aa5"
                Layout.fillWidth: true
            }

            TextField {
                id: keyField

                Layout.fillWidth: true
                echoMode: TextField.Password
                text: backend.streamKey
                placeholderText: qsTr("Paste your stream key…")
                onEditingFinished: if (text !== backend.streamKey) backend.setSetting("STREAM_KEY", text)
            }

            Label {
                text: qsTr("System audio (desktop sound)")
                font.pixelSize: 12
                color: "#9a9aa5"
            }

            ComboBox {
                id: outputSelect

                Layout.fillWidth: true
                model: backend.systemOutputs
                textRole: "description"
                valueRole: "name"
                onActivated: (index) => {
                    const name = model[index].name
                    backend.setSetting("AUDIO_SYSTEM", name === "auto" ? "auto" : "device:" + name)
                }
            }

            Label {
                text: qsTr("Microphone")
                font.pixelSize: 12
                color: "#9a9aa5"
            }

            RowLayout {
                spacing: 8

                ComboBox {
                    id: micSelect

                    model: backend.microphones
                    textRole: "description"
                    valueRole: "name"
                    enabled: backend.micEnabled
                    Layout.fillWidth: true
                    onActivated: (index) => {
                        const name = model[index].name
                        backend.setSetting("AUDIO_MIC", name === "auto" ? "auto" : "device:" + name)
                    }
                }

                Switch {
                    checked: backend.micEnabled
                    onToggled: backend.setSetting("MIC_ENABLED", checked)
                }
            }

            Label {
                text: qsTr("Video codec")
                font.pixelSize: 12
                color: "#9a9aa5"
            }

            ComboBox {
                id: codecSelect

                Layout.fillWidth: true
                model: ["h264", "hevc"]
                currentIndex: backend.videoCodec === "hevc" ? 1 : 0
                onActivated: (index) => backend.setSetting("VIDEO_CODEC", model[index])
            }

            Label {
                text: qsTr("Bitrate (CBR)")
                font.pixelSize: 12
                color: "#9a9aa5"
            }

            ComboBox {
                id: bitrateSelect

                Layout.fillWidth: true
                // kbps — YouTube's recommendation for 1080p30 is ~4500
                model: [3000, 4500, 6000, 8000, 9000]
                currentIndex: {
                    const bits = backend.bitrate
                    for (let i = 0; i < 5; i++)
                        if (model[i] === bits)
                            return i
                    return 1
                }
                onActivated: (index) => backend.setSetting("VIDEO_BITRATE", model[index])
            }
        }

        Item { Layout.fillHeight: true; Layout.fillWidth: true }

        Label {
            text: qsTr("Space go live/stop · C camera · T test · ? shortcuts · Q quit")
            font.pixelSize: 11
            color: "#6f6f78"
        }
    }

    // ── shortcuts overlay ─────────────────────────────────────────────────────
    Rectangle {
        visible: win.helpVisible
        anchors.fill: parent
        color: "#e00e0e10"

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 380)
            height: shortcutsColumn.implicitHeight + 44
            radius: 14
            color: "#17171b"

            ColumnLayout {
                id: shortcutsColumn

                anchors.centerIn: parent
                spacing: 10

                Label {
                    text: qsTr("Keyboard shortcuts")
                    font.pixelSize: 15
                    font.bold: true
                    color: "#f2f2f4"
                }

                Label { text: qsTr("Space — go live / stop"); color: "#c9c9d1"; font.pixelSize: 13 }
                Label { text: qsTr("C — show or hide the camera bubble"); color: "#c9c9d1"; font.pixelSize: 13 }
                Label { text: qsTr("T — record an 8 s test file, no stream"); color: "#c9c9d1"; font.pixelSize: 13 }
                Label { text: qsTr("? — show or hide this overlay"); color: "#c9c9d1"; font.pixelSize: 13 }
                Label { text: qsTr("Q — quit (asks while live)"); color: "#c9c9d1"; font.pixelSize: 13 }

                Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("Close")
                    onClicked: win.helpVisible = false
                }
            }
        }
    }

    // ── quit while live ───────────────────────────────────────────────────────
    Dialog {
        id: quitDialog

        parent: win.contentItem
        anchors.centerIn: win.contentItem
        title: qsTr("Stop the stream before quitting?")
        standardButtons: Dialog.Yes | Dialog.No | Dialog.Cancel

        Label {
            text: qsTr("A stream is running. Stop it and quit, stay in the app, or cancel.")
            wrapMode: Text.WordWrap
        }
        onAccepted: {
            backend.stopStream()
            Qt.quit()
        }
        onRejected: Qt.quit()
    }

    // keeps ComboBoxes honest: re-point their selections whenever config lands
    Connections {
        target: backend
        function onConfigChanged() {
            outputSelect.currentIndex = outputIndexFor(backend.audioSystem, backend.systemOutputs)
            micSelect.currentIndex = outputIndexFor(backend.audioMic, backend.microphones)
        }
        function onAudioDevicesChanged() {
            outputSelect.currentIndex = outputIndexFor(backend.audioSystem, backend.systemOutputs)
            micSelect.currentIndex = outputIndexFor(backend.audioMic, backend.microphones)
        }
    }

    function outputIndexFor(value, list) {
        const want = value.startsWith("device:") ? value.slice(7) : (value === "auto" ? "auto" : value)
        for (let i = 0; i < list.length; i++)
            if (list[i].name === want)
                return i
        return 0
    }

    Component.onCompleted: {
        outputSelect.currentIndex = outputIndexFor(backend.audioSystem, backend.systemOutputs)
        micSelect.currentIndex = outputIndexFor(backend.audioMic, backend.microphones)
    }
}

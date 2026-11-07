import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win

    width: 360
    height: 570
    minimumWidth: 340
    minimumHeight: 520
    maximumWidth: 420
    maximumHeight: 660
    visible: true
    title: "omastream"
    color: "#13141f"

    Material.theme: Material.Dark
    Material.accent: "#5e81f4"

    property bool settingsOpen: false
    property bool keyVisible: false
    property string pendingKey: backend.streamKey

    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; onActivated: backend.toggleStream() }
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; onActivated: backend.toggleCam() }
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; onActivated: backend.startTest() }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; onActivated: win.close() }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: if (win.settingsOpen) win.settingsOpen = false }

    onClosing: (close) => {
        if (backend.streaming) {
            close.accepted = false
            quitDialog.open()
        }
    }

    // ── main content (omareel style) ──────────────────────────────────────────
    ColumnLayout {
        anchors {
            fill: parent
            margins: 16
        }
        spacing: 10

        // ── Header: App Mark + Title + Settings Gear ─────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Omastream mark (concentric live ring)
            Rectangle {
                width: 30
                height: 30
                radius: 15
                color: "#1f2234"
                border.width: 1
                border.color: "#2a2e46"

                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: backend.streaming ? "#e53935" : "#b31217"

                    SequentialAnimation on opacity {
                        running: backend.streaming
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                        NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                    }
                }
            }

            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true

                Text {
                    text: "omastream"
                    color: "#f0f1f5"
                    font.family: "JetBrains Mono, monospace"
                    font.pixelSize: 15
                    font.bold: true
                }

                Text {
                    text: qsTr("Screen streaming that looks great")
                    color: "#7e8299"
                    font.pixelSize: 11
                }
            }

            // Settings gear button
            Rectangle {
                width: 32
                height: 32
                radius: 8
                color: gearMouse.containsMouse ? "#282c42" : "#1a1d2b"
                border.width: 1
                border.color: "#25283c"

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "qrc:/icons/gear.svg"
                    sourceSize: Qt.size(24, 24)
                    fillMode: Image.PreserveAspectFit
                    opacity: gearMouse.containsMouse ? 1.0 : 0.75
                }

                MouseArea {
                    id: gearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        win.pendingKey = backend.streamKey
                        win.settingsOpen = !win.settingsOpen
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        // ── Center Hero: Big Live/Stream Button ───────────────────────────────
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            // Big concentric button
            Rectangle {
                id: mainHeroButton
                Layout.alignment: Qt.AlignHCenter
                width: 96
                height: 96
                radius: 48
                color: backend.streaming ? "#33e53935" : (heroMouse.containsMouse ? "#26b31217" : "#1ab31217")

                SequentialAnimation on scale {
                    running: backend.streaming
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.05; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.05; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                }

                // Middle solid ring
                Rectangle {
                    anchors.centerIn: parent
                    width: 72
                    height: 72
                    radius: 36
                    color: backend.streaming ? "#e53935" : (heroMouse.containsMouse ? "#c72828" : "#b31217")

                    // Inner shape: play icon when idle, stop square when live
                    Image {
                        visible: !backend.streaming
                        anchors.centerIn: parent
                        width: 26
                        height: 26
                        source: "qrc:/icons/play.svg"
                        sourceSize: Qt.size(24, 24)
                        fillMode: Image.PreserveAspectFit
                    }

                    Rectangle {
                        visible: backend.streaming
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        radius: 4
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    id: heroMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.toggleStream()
                }
            }

            // Action label
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: backend.streaming
                      ? (backend.mode === "file" ? qsTr("Recording") : qsTr("Live"))
                      : qsTr("Go live")
                color: "#f0f1f5"
                font.family: "JetBrains Mono, monospace"
                font.pixelSize: 17
                font.bold: true
            }

            // Shortcut tag
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                Text {
                    text: backend.streaming ? (backend.mode === "file" ? qsTr("Local test") : qsTr("YouTube Live")) : qsTr("YouTube Live")
                    color: "#7e8299"
                    font.pixelSize: 11
                }

                Rectangle {
                    radius: 4
                    color: "#1f2234"
                    border.width: 1
                    border.color: "#2a2e46"
                    implicitWidth: shortcutText.implicitWidth + 8
                    implicitHeight: 18

                    Text {
                        id: shortcutText
                        anchors.centerIn: parent
                        text: "Space"
                        color: "#a0a4b8"
                        font.family: "JetBrains Mono, monospace"
                        font.pixelSize: 10
                    }
                }
            }

            // Status subtitle
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: win.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: {
                    if (backend.lastError !== "")
                        return backend.lastError
                    if (backend.streaming)
                        return qsTr("LIVE · ") + backend.elapsed
                    return backend.camVisible
                        ? qsTr("Camera ready — self-view visible")
                        : qsTr("Camera ready — self-view hidden")
                }
                color: backend.lastError !== "" ? "#ff6b6b" : (backend.streaming ? "#e53935" : "#7e8299")
                font.pixelSize: 11
            }
        }

        Item { Layout.fillHeight: true }

        // ── Quick controls: Shape cycle & Mirror flip ─────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            // Camera shape cycle button
            Rectangle {
                width: 40
                height: 40
                radius: 10
                color: shapeMouse.containsMouse ? "#282c42" : "#1a1d2b"
                border.width: 1
                border.color: "#25283c"

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: "qrc:/icons/refresh.svg"
                    sourceSize: Qt.size(24, 24)
                    fillMode: Image.PreserveAspectFit
                    opacity: shapeMouse.containsMouse ? 1.0 : 0.75
                }

                MouseArea {
                    id: shapeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.cycleCamShape()
                }

                ToolTip.visible: shapeMouse.containsMouse
                ToolTip.text: qsTr("Shape: ") + backend.camShape
            }

            // Mirror flip button
            Rectangle {
                width: 40
                height: 40
                radius: 10
                color: backend.camFlip ? "#2a3048" : (flipMouse.containsMouse ? "#282c42" : "#1a1d2b")
                border.width: 1
                border.color: backend.camFlip ? "#5e81f4" : "#25283c"

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: "qrc:/icons/mirror.svg"
                    sourceSize: Qt.size(24, 24)
                    fillMode: Image.PreserveAspectFit
                    opacity: backend.camFlip ? 1.0 : 0.7
                }

                MouseArea {
                    id: flipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.setCamFlip(!backend.camFlip)
                }

                ToolTip.visible: flipMouse.containsMouse
                ToolTip.text: qsTr("Mirror camera")
            }
        }

        // ── Source Cards (omareel cards) ──────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            // Card 1: System audio
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 8
                color: "#1a1d2b"
                border.width: 1
                border.color: "#232638"

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 10

                    Image {
                        source: "qrc:/icons/speaker.svg"
                        sourceSize: Qt.size(24, 24)
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.8
                    }

                    Text {
                        text: qsTr("System audio")
                        color: "#d8dae5"
                        font.pixelSize: 13
                        Layout.fillWidth: true
                    }

                    // Active dot
                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: "#5e81f4"
                    }
                }
            }

            // Card 2: Microphone
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 8
                color: "#1a1d2b"
                border.width: 1
                border.color: "#232638"

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 10

                    Image {
                        source: "qrc:/icons/microphone.svg"
                        sourceSize: Qt.size(24, 24)
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        fillMode: Image.PreserveAspectFit
                        opacity: backend.micEnabled ? 0.9 : 0.4
                    }

                    Text {
                        text: qsTr("Microphone")
                        color: backend.micEnabled ? "#d8dae5" : "#6f738a"
                        font.pixelSize: 13
                        Layout.fillWidth: true
                    }

                    Switch {
                        id: micSwitch
                        checked: backend.micEnabled
                        onToggled: backend.setSetting("MIC_ENABLED", checked)
                    }
                }
            }

            // Card 3: Webcam
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 8
                color: "#1a1d2b"
                border.width: 1
                border.color: "#232638"

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 12
                        rightMargin: 12
                    }
                    spacing: 10

                    Image {
                        source: "qrc:/icons/camera.svg"
                        sourceSize: Qt.size(24, 24)
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        fillMode: Image.PreserveAspectFit
                        opacity: backend.camVisible ? 0.9 : 0.4
                    }

                    Text {
                        text: qsTr("Webcam")
                        color: backend.camVisible ? "#d8dae5" : "#6f738a"
                        font.pixelSize: 13
                    }

                    // Shape pill
                    Rectangle {
                        radius: 4
                        color: "#24283c"
                        implicitWidth: shapePillText.implicitWidth + 8
                        implicitHeight: 18

                        Text {
                            id: shapePillText
                            anchors.centerIn: parent
                            text: backend.camShape
                            color: "#8e93aa"
                            font.family: "JetBrains Mono, monospace"
                            font.pixelSize: 10
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Switch {
                        id: camSwitch
                        checked: backend.camVisible
                        onToggled: backend.toggleCam()
                    }
                }
            }
        }

        // ── Bottom Wide Action: Test Capture ──────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 42
            radius: 8
            color: testMouse.containsMouse ? "#23273a" : "#1a1d2b"
            border.width: 1
            border.color: "#25283c"

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                Image {
                    source: "qrc:/icons/folder.svg"
                    sourceSize: Qt.size(24, 24)
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    fillMode: Image.PreserveAspectFit
                    opacity: 0.8
                }

                Text {
                    text: qsTr("Test capture (8s)")
                    color: "#f0f1f5"
                    font.family: "JetBrains Mono, monospace"
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            MouseArea {
                id: testMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: backend.startTest()
            }
        }

        // Footer note
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Stream is broadcast to YouTube Live")
            color: "#5e6378"
            font.family: "JetBrains Mono, monospace"
            font.pixelSize: 10
        }
    }

    // ── Settings Sheet Overlay ────────────────────────────────────────────────
    Rectangle {
        id: settingsOverlay
        anchors.fill: parent
        color: "#13141f"
        visible: win.settingsOpen
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 18
            }
            spacing: 12

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: qsTr("Settings")
                    color: "#f0f1f5"
                    font.family: "JetBrains Mono, monospace"
                    font.pixelSize: 16
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMouse.containsMouse ? "#282c42" : "#1a1d2b"

                    Image {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        source: "qrc:/icons/close.svg"
                        sourceSize: Qt.size(24, 24)
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.settingsOpen = false
                    }
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ColumnLayout {
                    width: settingsOverlay.width - 36
                    spacing: 10

                    // Stream key field
                    Text {
                        text: qsTr("YouTube Stream Key")
                        color: "#a0a4b8"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 42
                        radius: 8
                        color: "#1a1d2b"
                        border.width: 1
                        border.color: keyField.activeFocus ? "#e53935" : "#25283c"

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 8
                            }
                            spacing: 6

                            TextField {
                                id: keyField
                                Layout.fillWidth: true
                                echoMode: win.keyVisible ? TextField.Normal : TextField.Password
                                text: win.pendingKey
                                placeholderText: qsTr("Paste stream key…")
                                color: "#f0f1f5"
                                font.pixelSize: 12
                                background: null
                                onTextEdited: win.pendingKey = text
                                onEditingFinished: {
                                    if (text !== backend.streamKey)
                                        backend.setSetting("STREAM_KEY", text)
                                }
                            }

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 6
                                color: eyeMouse.containsMouse ? "#282c42" : "transparent"

                                Image {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: "qrc:/icons/eye.svg"
                                    sourceSize: Qt.size(24, 24)
                                    fillMode: Image.PreserveAspectFit
                                    opacity: win.keyVisible ? 1.0 : 0.5
                                }

                                MouseArea {
                                    id: eyeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.keyVisible = !win.keyVisible
                                }
                            }
                        }
                    }

                    // Save Key button
                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: 6
                        color: saveKeyMouse.containsMouse ? "#c72828" : "#b31217"

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Save stream key")
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.bold: true
                        }

                        MouseArea {
                            id: saveKeyMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.setSetting("STREAM_KEY", keyField.text)
                                saveAnim.start()
                            }
                        }

                        SequentialAnimation on opacity {
                            id: saveAnim
                            running: false
                            NumberAnimation { from: 0.5; to: 1.0; duration: 250 }
                        }
                    }

                    // System audio select
                    Text {
                        text: qsTr("Desktop sound (System output)")
                        color: "#a0a4b8"
                        font.pixelSize: 12
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

                    // Mic select
                    Text {
                        text: qsTr("Microphone device")
                        color: "#a0a4b8"
                        font.pixelSize: 12
                    }

                    ComboBox {
                        id: micSelect
                        Layout.fillWidth: true
                        model: backend.microphones
                        textRole: "description"
                        valueRole: "name"
                        onActivated: (index) => {
                            const name = model[index].name
                            backend.setSetting("AUDIO_MIC", name === "auto" ? "auto" : "device:" + name)
                        }
                    }

                    // Codec select
                    Text {
                        text: qsTr("Video codec")
                        color: "#a0a4b8"
                        font.pixelSize: 12
                    }

                    ComboBox {
                        id: codecSelect
                        Layout.fillWidth: true
                        model: ["h264", "hevc"]
                        currentIndex: backend.videoCodec === "hevc" ? 1 : 0
                        onActivated: (index) => backend.setSetting("VIDEO_CODEC", model[index])
                    }

                    // Bitrate select
                    Text {
                        text: qsTr("Bitrate (kbps)")
                        color: "#a0a4b8"
                        font.pixelSize: 12
                    }

                    ComboBox {
                        id: bitrateSelect
                        Layout.fillWidth: true
                        model: [3000, 4500, 6000, 8000, 9000]
                        currentIndex: {
                            const b = backend.bitrate
                            for (let i = 0; i < 5; i++)
                                if (model[i] === b) return i
                            return 1
                        }
                        onActivated: (index) => backend.setSetting("VIDEO_BITRATE", model[index])
                    }

                    // CPU fallback toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: qsTr("Auto CPU fallback (if GPU fails)")
                            color: "#a0a4b8"
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }

                        Switch {
                            checked: backend.cpuFallback
                            onToggled: backend.setSetting("CPU_FALLBACK", checked)
                        }
                    }
                }
            }

            // Close settings button
            Rectangle {
                Layout.fillWidth: true
                height: 38
                radius: 8
                color: "#1a1d2b"
                border.width: 1
                border.color: "#25283c"

                Text {
                    anchors.centerIn: parent
                    text: qsTr("Done")
                    color: "#f0f1f5"
                    font.pixelSize: 13
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.settingsOpen = false
                }
            }
        }
    }

    // ── quit confirmation while live ──────────────────────────────────────────
    Dialog {
        id: quitDialog
        parent: win.contentItem
        anchors.centerIn: win.contentItem
        title: qsTr("Stop the stream before quitting?")
        standardButtons: Dialog.Yes | Dialog.No | Dialog.Cancel

        Label {
            text: qsTr("A stream is currently running. Stop it and quit?")
            wrapMode: Text.WordWrap
        }
        onAccepted: {
            backend.stopStream()
            Qt.quit()
        }
        onRejected: Qt.quit()
    }

    Connections {
        target: backend
        function onConfigChanged() {
            outputSelect.currentIndex = outputIndexFor(backend.audioSystem, backend.systemOutputs)
            micSelect.currentIndex = outputIndexFor(backend.audioMic, backend.microphones)
            if (!keyField.activeFocus && backend.streamKey !== "")
                win.pendingKey = backend.streamKey
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

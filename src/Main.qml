import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win

    width: 380
    height: 720
    minimumWidth: 380
    maximumWidth: 420
    minimumHeight: 640
    maximumHeight: 880
    flags: Qt.Dialog | Qt.WindowCloseButtonHint
    visible: true
    title: "omastream"
    color: "#13141f"

    Material.theme: Material.Dark
    Material.accent: "#5e81f4"

    property bool settingsOpen: false
    property string pendingYtKey: backend.youtubeKey
    property string pendingTwitchKey: backend.twitchKey
    property string pendingKickKey: backend.kickKey
    property string pendingKickUrl: backend.kickUrl
    property bool ytKeyVisible: false
    property bool twitchKeyVisible: false
    property bool kickKeyVisible: false

    property bool ytSaved: false
    property bool twitchSaved: false
    property bool kickSaved: false

    property bool previewExpanded: true
    property int previewTick: 0

    Timer {
        id: previewTimer
        interval: 1200
        repeat: true
        running: backend.streaming
        onTriggered: win.previewTick++
    }

    Connections {
        target: backend
        function onStateChanged() {
            win.previewTick++
        }
    }

    Timer {
        id: ytSavedTimer
        interval: 2200
        onTriggered: win.ytSaved = false
    }

    Timer {
        id: twitchSavedTimer
        interval: 2200
        onTriggered: win.twitchSaved = false
    }

    Timer {
        id: kickSavedTimer
        interval: 2200
        onTriggered: win.kickSaved = false
    }

    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; onActivated: backend.toggleStream() }
    Shortcut { sequence: "C"; context: Qt.ApplicationShortcut; onActivated: backend.toggleCam() }
    Shortcut { sequence: "P"; context: Qt.ApplicationShortcut; onActivated: backend.togglePrivacy() }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; onActivated: win.close() }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: if (win.settingsOpen) win.settingsOpen = false }

    onClosing: (close) => {
        if (backend.streaming) {
            close.accepted = false
            quitDialog.open()
        } else {
            backend.cleanupOnClose()
        }
    }

    Component.onDestruction: backend.cleanupOnClose()

    // ── main content ──────────────────────────────────────────────────────────
    ColumnLayout {
        anchors {
            fill: parent
            margins: 16
        }
        spacing: 10

        // ── Header: App Mark + Title + Studio Link + Settings Gear ────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Omastream mark (concentric live ring)
            Rectangle {
                width: 32
                height: 32
                radius: 16
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

                RowLayout {
                    spacing: 6
                    Text {
                        text: "omastream"
                        color: "#f0f1f5"
                        font.family: "JetBrains Mono, monospace"
                        font.pixelSize: 15
                        font.bold: true
                    }

                    // Status pill
                    Rectangle {
                        radius: 4
                        implicitWidth: statusPillText.implicitWidth + 8
                        implicitHeight: 18
                        color: backend.streaming ? "#33e53935" : (backend.hasStreamKey ? "#1a2a44" : "#33442211")
                        border.width: 1
                        border.color: backend.streaming ? "#e53935" : (backend.hasStreamKey ? "#2e4266" : "#886622")

                        Text {
                            id: statusPillText
                            anchors.centerIn: parent
                            text: backend.streaming ? qsTr("LIVE") : (backend.hasStreamKey ? qsTr("Ready") : qsTr("Key Needed"))
                            color: backend.streaming ? "#ff6b6b" : (backend.hasStreamKey ? "#7aa2f7" : "#ffaa44")
                            font.family: "JetBrains Mono, monospace"
                            font.pixelSize: 9
                            font.bold: true
                        }
                    }
                }

                Text {
                    text: backend.streaming ? (qsTr("Broadcasting to ") + backend.activePlatforms + " · " + backend.elapsed) : (qsTr("Broadcasting: ") + backend.activePlatforms)
                    color: backend.streaming ? "#ff6b6b" : "#7e8299"
                    font.pixelSize: 11
                }
            }

            // Creator Dashboard button
            Rectangle {
                width: 32
                height: 32
                radius: 8
                color: studioBtnMouse.containsMouse ? "#282c42" : "#1a1d2b"
                border.width: 1
                border.color: "#25283c"

                Image {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "qrc:/icons/monitor.svg"
                    sourceSize: Qt.size(24, 24)
                    fillMode: Image.PreserveAspectFit
                    opacity: studioBtnMouse.containsMouse ? 1.0 : 0.75
                }

                MouseArea {
                    id: studioBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (backend.kickEnabled && backend.kickKey !== "" && !backend.youtubeEnabled && !backend.twitchEnabled)
                            backend.openKickDashboard()
                        else if (backend.twitchEnabled && backend.twitchKey !== "" && !backend.youtubeEnabled)
                            backend.openTwitchDashboard()
                        else
                            backend.openYouTubeStudio()
                    }
                }

                ToolTip.visible: studioBtnMouse.containsMouse
                ToolTip.text: qsTr("Open Creator Dashboard")
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
                        win.pendingYtKey = backend.youtubeKey
                        win.pendingTwitchKey = backend.twitchKey
                        win.pendingKickKey = backend.kickKey
                        win.pendingKickUrl = backend.kickUrl
                        win.settingsOpen = !win.settingsOpen
                    }
                }

                ToolTip.visible: gearMouse.containsMouse
                ToolTip.text: qsTr("Settings")
            }
        }

        // ── Multi-Platform Quick Selector Bar ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // YouTube Pill
            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 6
                color: backend.youtubeEnabled ? (ytChipMouse.containsMouse ? "#2f1b1d" : "#241618") : (ytChipMouse.containsMouse ? "#222536" : "#1a1d2b")
                border.width: 1
                border.color: backend.youtubeEnabled ? (backend.youtubeKey !== "" ? "#e53935" : "#b31217") : "#25283c"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: backend.youtubeEnabled ? (backend.youtubeKey !== "" ? "#4ade80" : "#facc15") : "#5e6378"
                    }

                    Text {
                        text: "YouTube"
                        color: backend.youtubeEnabled ? "#ffffff" : "#7e8299"
                        font.family: "JetBrains Mono, monospace"
                        font.pixelSize: 11
                        font.bold: backend.youtubeEnabled
                    }
                }

                MouseArea {
                    id: ytChipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.togglePlatform("youtube")
                }

                ToolTip.visible: ytChipMouse.containsMouse
                ToolTip.text: backend.youtubeEnabled
                    ? (backend.youtubeKey !== "" ? qsTr("YouTube Live: Active") : qsTr("YouTube Live: Key needed (click settings)"))
                    : qsTr("YouTube Live: Disabled (click to enable)")
            }

            // Twitch Pill
            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 6
                color: backend.twitchEnabled ? (twitchChipMouse.containsMouse ? "#241935" : "#1b1428") : (twitchChipMouse.containsMouse ? "#222536" : "#1a1d2b")
                border.width: 1
                border.color: backend.twitchEnabled ? (backend.twitchKey !== "" ? "#9146ff" : "#6441a5") : "#25283c"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: backend.twitchEnabled ? (backend.twitchKey !== "" ? "#4ade80" : "#facc15") : "#5e6378"
                    }

                    Text {
                        text: "Twitch"
                        color: backend.twitchEnabled ? "#ffffff" : "#7e8299"
                        font.family: "JetBrains Mono, monospace"
                        font.pixelSize: 11
                        font.bold: backend.twitchEnabled
                    }
                }

                MouseArea {
                    id: twitchChipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.togglePlatform("twitch")
                }

                ToolTip.visible: twitchChipMouse.containsMouse
                ToolTip.text: backend.twitchEnabled
                    ? (backend.twitchKey !== "" ? qsTr("Twitch: Active") : qsTr("Twitch: Key needed (click settings)"))
                    : qsTr("Twitch: Disabled (click to enable)")
            }

            // Kick Pill
            Rectangle {
                Layout.fillWidth: true
                height: 28
                radius: 6
                color: backend.kickEnabled ? (kickChipMouse.containsMouse ? "#152a1b" : "#101e14") : (kickChipMouse.containsMouse ? "#222536" : "#1a1d2b")
                border.width: 1
                border.color: backend.kickEnabled ? (backend.kickKey !== "" ? "#53fc18" : "#2e8b10") : "#25283c"

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: backend.kickEnabled ? (backend.kickKey !== "" ? "#4ade80" : "#facc15") : "#5e6378"
                    }

                    Text {
                        text: "Kick"
                        color: backend.kickEnabled ? "#ffffff" : "#7e8299"
                        font.family: "JetBrains Mono, monospace"
                        font.pixelSize: 11
                        font.bold: backend.kickEnabled
                    }
                }

                MouseArea {
                    id: kickChipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.togglePlatform("kick")
                }

                ToolTip.visible: kickChipMouse.containsMouse
                ToolTip.text: backend.kickEnabled
                    ? (backend.kickKey !== "" ? qsTr("Kick: Active") : qsTr("Kick: Key needed (click settings)"))
                    : qsTr("Kick: Disabled (click to enable)")
            }
        }

        Item { Layout.fillHeight: true }

        // ── Center Hero: Big Live/Stream Button ───────────────────────────────
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            // Big concentric button
            Rectangle {
                id: mainHeroButton
                Layout.alignment: Qt.AlignHCenter
                width: 90
                height: 90
                radius: 45
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
                    width: 68
                    height: 68
                    radius: 34
                    color: backend.streaming ? "#e53935" : (heroMouse.containsMouse ? "#c72828" : "#b31217")

                    // Inner shape: play icon when idle, stop square when live
                    Image {
                        visible: !backend.streaming
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        source: "qrc:/icons/play.svg"
                        sourceSize: Qt.size(24, 24)
                        fillMode: Image.PreserveAspectFit
                    }

                    Rectangle {
                        visible: backend.streaming
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        radius: 4
                        color: "#ffffff"
                    }
                }

                MouseArea {
                    id: heroMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!backend.streaming && !backend.hasAnyPlatformConfigured) {
                            win.pendingYtKey = backend.youtubeKey
                            win.pendingTwitchKey = backend.twitchKey
                            win.pendingKickKey = backend.kickKey
                            win.pendingKickUrl = backend.kickUrl
                            win.settingsOpen = true
                        } else {
                            backend.toggleStream()
                        }
                    }
                }
            }

            // Action label
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: backend.streaming ? qsTr("Stop Stream") : qsTr("Go Live")
                color: "#f0f1f5"
                font.family: "JetBrains Mono, monospace"
                font.pixelSize: 16
                font.bold: true
            }

            // Status subtitle / error display
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
                    if (!backend.hasAnyPlatformConfigured)
                        return qsTr("Add stream keys in Settings (⚙) to stream")
                    const resLabel = (backend.streamResolution && backend.streamResolution !== "auto") ? (" · " + backend.streamResolution) : ""
                    return backend.camVisible
                        ? (qsTr("Ready · ") + backend.activePlatforms + resLabel + qsTr(" · Camera on"))
                        : (qsTr("Ready · ") + backend.activePlatforms + resLabel + qsTr(" · Press Space"))
                }
                color: backend.lastError !== "" ? "#ff6b6b" : (backend.streaming ? "#e53935" : (!backend.hasAnyPlatformConfigured ? "#e0af68" : "#7e8299"))
                font.pixelSize: 11
            }

            // Quick Test Button (when idle)
            Rectangle {
                visible: !backend.streaming
                Layout.alignment: Qt.AlignHCenter
                width: testRow.implicitWidth + 16
                height: 24
                radius: 12
                color: testMouse.containsMouse ? "#282c42" : "#1a1d2b"
                border.width: 1
                border.color: "#25283c"

                RowLayout {
                    id: testRow
                    anchors.centerIn: parent
                    spacing: 6

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: "#5e81f4"
                    }

                    Text {
                        text: qsTr("Test Stream (8s recording)")
                        color: testMouse.containsMouse ? "#ffffff" : "#8e93aa"
                        font.family: "JetBrains Mono, monospace"
                        font.pixelSize: 10
                    }
                }

                MouseArea {
                    id: testMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: backend.startTest()
                }

                ToolTip.visible: testMouse.containsMouse
                ToolTip.text: qsTr("Record an 8s local test file to check audio and video quality")
            }
        }

        Item { Layout.fillHeight: true }

        // ── Source Cards ──────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            // Card 1: System Audio
            Rectangle {
                Layout.fillWidth: true
                height: 38
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
                        Layout.preferredWidth: 15
                        Layout.preferredHeight: 15
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.85
                    }

                    Text {
                        text: qsTr("System audio")
                        color: "#d8dae5"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }

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
                height: 38
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
                        Layout.preferredWidth: 15
                        Layout.preferredHeight: 15
                        fillMode: Image.PreserveAspectFit
                        opacity: backend.micEnabled ? 0.9 : 0.4
                    }

                    Text {
                        text: qsTr("Microphone")
                        color: backend.micEnabled ? "#d8dae5" : "#6f738a"
                        font.pixelSize: 12
                        Layout.fillWidth: true
                    }

                    Switch {
                        id: micSwitch
                        checked: backend.micEnabled
                        onToggled: backend.setSetting("MIC_ENABLED", checked)
                    }
                }
            }

            // Card 3: Live Camera Studio Card
            Rectangle {
                Layout.fillWidth: true
                height: backend.camVisible ? 88 : 42
                radius: 8
                color: "#1a1d2b"
                border.width: 1
                border.color: backend.camVisible ? "#2e3450" : "#232638"

                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    spacing: 8

                    // Top row: Header & toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Image {
                            source: "qrc:/icons/camera.svg"
                            sourceSize: Qt.size(24, 24)
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            fillMode: Image.PreserveAspectFit
                            opacity: backend.camVisible ? 0.95 : 0.4
                        }

                        Text {
                            text: qsTr("Webcam Overlay")
                            color: backend.camVisible ? "#ffffff" : "#6f738a"
                            font.pixelSize: 13
                            font.bold: backend.camVisible
                        }

                        // Live on-screen indicator
                        Rectangle {
                            radius: 3
                            implicitWidth: camBadgeText.implicitWidth + 8
                            implicitHeight: 16
                            color: backend.camVisible ? "#253456" : "#202334"

                            Text {
                                id: camBadgeText
                                anchors.centerIn: parent
                                text: backend.camVisible ? qsTr("ON SCREEN") : qsTr("HIDDEN")
                                color: backend.camVisible ? "#7aa2f7" : "#5e6378"
                                font.family: "JetBrains Mono, monospace"
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Switch {
                            id: camSwitch
                            checked: backend.camVisible
                            onToggled: backend.toggleCam()
                        }
                    }

                    // Expanded controls (when overlay is visible)
                    RowLayout {
                        visible: backend.camVisible
                        Layout.fillWidth: true
                        spacing: 6

                        // Shape Selector (Circle, 1:1, 16:9)
                        Row {
                            spacing: 4

                            // Circle pill
                            Rectangle {
                                width: 26
                                height: 24
                                radius: 12
                                color: backend.camShape === "circle" ? "#384166" : (circleMouse.containsMouse ? "#282c42" : "#202334")
                                border.width: 1
                                border.color: backend.camShape === "circle" ? "#5e81f4" : "#2c3046"

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    radius: 5
                                    color: "transparent"
                                    border.width: 2
                                    border.color: backend.camShape === "circle" ? "#ffffff" : "#8e93aa"
                                }

                                MouseArea {
                                    id: circleMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.setCamShape("circle")
                                }

                                ToolTip.visible: circleMouse.containsMouse
                                ToolTip.text: qsTr("Circle")
                            }

                            // 1:1 Square pill
                            Rectangle {
                                width: 26
                                height: 24
                                radius: 4
                                color: backend.camShape === "1:1" ? "#384166" : (squareMouse.containsMouse ? "#282c42" : "#202334")
                                border.width: 1
                                border.color: backend.camShape === "1:1" ? "#5e81f4" : "#2c3046"

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 10
                                    height: 10
                                    radius: 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: backend.camShape === "1:1" ? "#ffffff" : "#8e93aa"
                                }

                                MouseArea {
                                    id: squareMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.setCamShape("1:1")
                                }

                                ToolTip.visible: squareMouse.containsMouse
                                ToolTip.text: qsTr("1:1 Square")
                            }

                            // 16:9 Wide pill
                            Rectangle {
                                width: 32
                                height: 24
                                radius: 4
                                color: backend.camShape === "16:9" ? "#384166" : (wideMouse.containsMouse ? "#282c42" : "#202334")
                                border.width: 1
                                border.color: backend.camShape === "16:9" ? "#5e81f4" : "#2c3046"

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 15
                                    height: 9
                                    radius: 2
                                    color: "transparent"
                                    border.width: 2
                                    border.color: backend.camShape === "16:9" ? "#ffffff" : "#8e93aa"
                                }

                                MouseArea {
                                    id: wideMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: backend.setCamShape("16:9")
                                }

                                ToolTip.visible: wideMouse.containsMouse
                                ToolTip.text: qsTr("16:9 Wide")
                            }
                        }

                        // Mirror Button
                        Rectangle {
                            width: 26
                            height: 24
                            radius: 4
                            color: backend.camFlip ? "#2a3048" : (mirrorBtnMouse.containsMouse ? "#282c42" : "#202334")
                            border.width: 1
                            border.color: backend.camFlip ? "#5e81f4" : "#2c3046"

                            Image {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                source: "qrc:/icons/mirror.svg"
                                sourceSize: Qt.size(24, 24)
                                fillMode: Image.PreserveAspectFit
                                opacity: backend.camFlip ? 1.0 : 0.5
                            }

                            MouseArea {
                                id: mirrorBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.setCamFlip(!backend.camFlip)
                            }

                            ToolTip.visible: mirrorBtnMouse.containsMouse
                            ToolTip.text: backend.camFlip ? qsTr("Mirror: ON") : qsTr("Mirror: OFF")
                        }

                        Rectangle {
                            width: 1
                            height: 18
                            color: "#25283c"
                        }

                        // Corner Snap Presets (TL, TR, BL, BR)
                        Row {
                            spacing: 3

                            Repeater {
                                model: [
                                    { id: "top-left", icon: "↖", tip: qsTr("Top-Left") },
                                    { id: "top-right", icon: "↗", tip: qsTr("Top-Right") },
                                    { id: "bottom-left", icon: "↙", tip: qsTr("Bottom-Left") },
                                    { id: "bottom-right", icon: "↘", tip: qsTr("Bottom-Right") }
                                ]

                                delegate: Rectangle {
                                    width: 22
                                    height: 24
                                    radius: 4
                                    color: cornerMouse.containsMouse ? "#282c42" : "#202334"
                                    border.width: 1
                                    border.color: "#2c3046"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.icon
                                        color: cornerMouse.containsMouse ? "#ffffff" : "#8e93aa"
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: cornerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.setCamCorner(modelData.id)
                                    }

                                    ToolTip.visible: cornerMouse.containsMouse
                                    ToolTip.text: modelData.tip
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // Card 4: Privacy Filter (Stream Shield / Blur)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: backend.privacyActive ? 86 : 42
                implicitHeight: Layout.preferredHeight
                radius: 8
                color: backend.privacyActive ? "#221926" : "#1a1d2b"
                border.width: 1
                border.color: backend.privacyActive ? "#f59e0b" : "#232638"

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    spacing: 8

                    // Top row: Header & toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Image {
                            source: "qrc:/icons/shield.svg"
                            sourceSize: Qt.size(24, 24)
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            fillMode: Image.PreserveAspectFit
                            opacity: backend.privacyActive ? 1.0 : 0.6
                        }

                        Text {
                            text: qsTr("Privacy Filter")
                            color: backend.privacyActive ? "#ffffff" : "#d8dae5"
                            font.pixelSize: 12
                            font.bold: backend.privacyActive
                        }

                        // Status indicator pill
                        Rectangle {
                            radius: 4
                            implicitWidth: privacyBadgeText.implicitWidth + 10
                            implicitHeight: 18
                            color: backend.privacyActive ? "#33f59e0b" : "#202334"
                            border.width: backend.privacyActive ? 1 : 0
                            border.color: "#f59e0b"

                            Text {
                                id: privacyBadgeText
                                anchors.centerIn: parent
                                text: backend.privacyActive
                                    ? (backend.privacyMode === "shield" ? qsTr("MASKED (STREAM PAUSED)")
                                      : (backend.privacyMode === "blackout" ? qsTr("MASKED (BLACKOUT)") : qsTr("MASKED (FROSTED BLUR)")))
                                    : qsTr("OFF · SCREEN VISIBLE")
                                color: backend.privacyActive ? "#f59e0b" : "#6b7280"
                                font.family: "JetBrains Mono, monospace"
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Switch {
                            id: privacySwitch
                            checked: backend.privacyActive
                            onToggled: backend.togglePrivacy()
                        }
                    }

                    // Mode Presets: Blur / Shield / Blackout
                    RowLayout {
                        visible: backend.privacyActive
                        Layout.fillWidth: true
                        spacing: 6

                        // Blur pill
                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            radius: 4
                            color: backend.privacyMode === "blur" ? "#384166" : (blurMouse.containsMouse ? "#282c42" : "#1a1e30")
                            border.width: 1
                            border.color: backend.privacyMode === "blur" ? "#5e81f4" : "#2c3046"

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Frosted Blur")
                                color: backend.privacyMode === "blur" ? "#ffffff" : "#8e93aa"
                                font.family: "JetBrains Mono, monospace"
                                font.pixelSize: 10
                                font.bold: backend.privacyMode === "blur"
                            }

                            MouseArea {
                                id: blurMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.setPrivacyMode("blur")
                            }
                        }

                        // Shield pill
                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            radius: 4
                            color: backend.privacyMode === "shield" ? "#384166" : (shieldMouse.containsMouse ? "#282c42" : "#1a1e30")
                            border.width: 1
                            border.color: backend.privacyMode === "shield" ? "#5e81f4" : "#2c3046"

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Stream Paused")
                                color: backend.privacyMode === "shield" ? "#ffffff" : "#8e93aa"
                                font.family: "JetBrains Mono, monospace"
                                font.pixelSize: 10
                                font.bold: backend.privacyMode === "shield"
                            }

                            MouseArea {
                                id: shieldMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.setPrivacyMode("shield")
                            }
                        }

                        // Blackout pill
                        Rectangle {
                            Layout.fillWidth: true
                            height: 26
                            radius: 4
                            color: backend.privacyMode === "blackout" ? "#384166" : (blackoutMouse.containsMouse ? "#282c42" : "#1a1e30")
                            border.width: 1
                            border.color: backend.privacyMode === "blackout" ? "#5e81f4" : "#2c3046"

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Blackout")
                                color: backend.privacyMode === "blackout" ? "#ffffff" : "#8e93aa"
                                font.family: "JetBrains Mono, monospace"
                                font.pixelSize: 10
                                font.bold: backend.privacyMode === "blackout"
                            }

                            MouseArea {
                                id: blackoutMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.setPrivacyMode("blackout")
                            }
                        }
                    }
                }
            }

            // Card 5: Remote Feed Preview (Confidence Monitor)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: (backend.streaming || win.previewExpanded) ? 180 : 42
                implicitHeight: Layout.preferredHeight
                radius: 8
                color: backend.privacyActive ? "#201626" : "#1a1d2b"
                border.width: 1
                border.color: backend.privacyActive ? "#f59e0b" : "#232638"

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    spacing: 8

                    // Top row: Header, status badge & collapse toggle
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Image {
                            source: "qrc:/icons/monitor.svg"
                            sourceSize: Qt.size(24, 24)
                            Layout.preferredWidth: 15
                            Layout.preferredHeight: 15
                            fillMode: Image.PreserveAspectFit
                            opacity: 0.85
                        }

                        Text {
                            text: qsTr("Remote Feed Preview")
                            color: "#d8dae5"
                            font.pixelSize: 12
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            height: 18
                            width: badgeText.implicitWidth + 12
                            radius: 9
                            color: backend.streaming ? (backend.privacyActive ? "#451a03" : "#052e16") : "#1e2235"
                            border.width: 1
                            border.color: backend.streaming ? (backend.privacyActive ? "#f59e0b" : "#10b981") : "#2b3048"

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: backend.streaming ? (backend.privacyActive ? qsTr("MASKED") : qsTr("LIVE")) : qsTr("STANDBY")
                                color: backend.streaming ? (backend.privacyActive ? "#fbbf24" : "#34d399") : "#7e839b"
                                font.family: "JetBrains Mono, monospace"
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 4
                            color: prevToggleMouse.containsMouse ? "#282c42" : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: (backend.streaming || win.previewExpanded) ? "▲" : "▼"
                                color: "#8e93aa"
                                font.pixelSize: 9
                            }

                            MouseArea {
                                id: prevToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: win.previewExpanded = !win.previewExpanded
                            }
                        }
                    }

                    // Content Box: Video Monitor Display
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 6
                        color: "#0d0f17"
                        border.width: 1
                        border.color: "#1f2233"
                        clip: true
                        visible: (backend.streaming || win.previewExpanded)

                        Image {
                            id: previewImage
                            anchors.fill: parent
                            anchors.margins: 2
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            asynchronous: true
                            source: (backend.streaming && backend.previewPath !== "")
                                    ? ("file://" + backend.previewPath + "?t=" + win.previewTick)
                                    : ""
                            visible: status === Image.Ready && backend.streaming
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: !previewImage.visible

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: backend.streaming ? qsTr("Waiting for broadcast feed…") : qsTr("Stream Confidence Monitor")
                                color: "#6b7280"
                                font.family: "JetBrains Mono, monospace"
                                font.pixelSize: 10
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: backend.streaming ? qsTr("Connecting encoder") : qsTr("Shows exactly what remote viewers see")
                                color: "#4b5563"
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            anchors {
                                top: parent.top
                                left: parent.left
                                margins: 6
                            }
                            height: 16
                            width: prevBoxBadge.implicitWidth + 10
                            radius: 3
                            color: backend.privacyActive ? "#b45309" : "#065f46"
                            opacity: 0.9
                            visible: backend.streaming && previewImage.visible

                            Text {
                                id: prevBoxBadge
                                anchors.centerIn: parent
                                text: backend.privacyActive ? qsTr("MASK APPLIED") : qsTr("BROADCASTING")
                                color: "#ffffff"
                                font.family: "JetBrains Mono, monospace"
                                font.pixelSize: 8
                                font.bold: true
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                Layout.minimumHeight: 6
            }

            // Footer note
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Space: Go Live · C: Camera · P: Privacy Filter")
                color: "#5e6378"
                font.family: "JetBrains Mono, monospace"
                font.pixelSize: 10
            }
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

            // Saved Feedback Banner
            Rectangle {
                Layout.fillWidth: true
                height: (win.ytSaved || win.twitchSaved || win.kickSaved) ? 28 : 0
                visible: height > 0
                radius: 6
                color: "#163a2a"
                border.width: 1
                border.color: "#10b981"
                clip: true

                Behavior on height {
                    NumberAnimation { duration: 150 }
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "✓"
                        color: "#10b981"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Text {
                        text: qsTr("Credentials saved successfully")
                        color: "#34d399"
                        font.pixelSize: 11
                        font.bold: true
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

                    // ── Platform 1: YouTube Live ──
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: ytCardCol.implicitHeight + 16
                        radius: 8
                        color: "#181a27"
                        border.width: 1
                        border.color: backend.youtubeEnabled ? "#4a2022" : "#232638"

                        ColumnLayout {
                            id: ytCardCol
                            anchors {
                                fill: parent
                                margins: 10
                            }
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: backend.youtubeEnabled ? (backend.youtubeKey !== "" ? "#e53935" : "#e0af68") : "#5e6378"
                                }

                                Text {
                                    text: qsTr("YouTube Live")
                                    color: "#f0f1f5"
                                    font.pixelSize: 13
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: ytStudioText.implicitWidth + 12
                                    height: 22
                                    radius: 4
                                    color: ytStudioMouse.containsMouse ? "#384166" : "#202334"
                                    border.width: 1
                                    border.color: "#2c3046"

                                    Text {
                                        id: ytStudioText
                                        anchors.centerIn: parent
                                        text: qsTr("Studio ↗")
                                        color: "#8e93aa"
                                        font.pixelSize: 10
                                    }

                                    MouseArea {
                                        id: ytStudioMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.openYouTubeStudio()
                                    }
                                }

                                Switch {
                                    checked: backend.youtubeEnabled
                                    onToggled: backend.togglePlatform("youtube")
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 38
                                radius: 6
                                color: "#13141f"
                                border.width: 1
                                border.color: ytKeyField.activeFocus ? "#e53935" : "#25283c"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    TextField {
                                        id: ytKeyField
                                        Layout.fillWidth: true
                                        echoMode: win.ytKeyVisible ? TextField.Normal : TextField.Password
                                        text: win.pendingYtKey
                                        placeholderText: qsTr("Paste YouTube stream key…")
                                        color: "#f0f1f5"
                                        font.pixelSize: 11
                                        background: null
                                        onTextEdited: {
                                            win.pendingYtKey = text
                                            win.ytSaved = false
                                        }
                                        onEditingFinished: {
                                            if (text !== backend.youtubeKey) {
                                                backend.setSetting("YOUTUBE_KEY", text)
                                                backend.setSetting("STREAM_KEY", text)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 4
                                        color: ytEyeMouse.containsMouse ? "#282c42" : "transparent"

                                        Image {
                                            anchors.centerIn: parent
                                            width: 14
                                            height: 14
                                            source: "qrc:/icons/eye.svg"
                                            sourceSize: Qt.size(24, 24)
                                            fillMode: Image.PreserveAspectFit
                                            opacity: win.ytKeyVisible ? 1.0 : 0.5
                                        }

                                        MouseArea {
                                            id: ytEyeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.ytKeyVisible = !win.ytKeyVisible
                                        }
                                    }

                                    Rectangle {
                                        width: ytSaveText.implicitWidth + 16
                                        height: 26
                                        radius: 4
                                        color: win.ytSaved ? "#10b981" : (ytSaveMouse.containsMouse ? "#c72828" : "#b31217")

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }

                                        Text {
                                            id: ytSaveText
                                            anchors.centerIn: parent
                                            text: win.ytSaved ? qsTr("Saved ✓") : qsTr("Save")
                                            color: "#ffffff"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: ytSaveMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                backend.setSetting("YOUTUBE_KEY", ytKeyField.text)
                                                backend.setSetting("STREAM_KEY", ytKeyField.text)
                                                win.ytSaved = true
                                                ytSavedTimer.restart()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Platform 2: Twitch ──
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: twitchCardCol.implicitHeight + 16
                        radius: 8
                        color: "#181a27"
                        border.width: 1
                        border.color: backend.twitchEnabled ? "#35224e" : "#232638"

                        ColumnLayout {
                            id: twitchCardCol
                            anchors {
                                fill: parent
                                margins: 10
                            }
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: backend.twitchEnabled ? (backend.twitchKey !== "" ? "#9146ff" : "#e0af68") : "#5e6378"
                                }

                                Text {
                                    text: qsTr("Twitch")
                                    color: "#f0f1f5"
                                    font.pixelSize: 13
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: twitchDashText.implicitWidth + 12
                                    height: 22
                                    radius: 4
                                    color: twitchDashMouse.containsMouse ? "#384166" : "#202334"
                                    border.width: 1
                                    border.color: "#2c3046"

                                    Text {
                                        id: twitchDashText
                                        anchors.centerIn: parent
                                        text: qsTr("Dashboard ↗")
                                        color: "#8e93aa"
                                        font.pixelSize: 10
                                    }

                                    MouseArea {
                                        id: twitchDashMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.openTwitchDashboard()
                                    }
                                }

                                Switch {
                                    checked: backend.twitchEnabled
                                    onToggled: backend.togglePlatform("twitch")
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 38
                                radius: 6
                                color: "#13141f"
                                border.width: 1
                                border.color: twitchKeyField.activeFocus ? "#9146ff" : "#25283c"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    TextField {
                                        id: twitchKeyField
                                        Layout.fillWidth: true
                                        echoMode: win.twitchKeyVisible ? TextField.Normal : TextField.Password
                                        text: win.pendingTwitchKey
                                        placeholderText: qsTr("Paste Twitch stream key (live_…)…")
                                        color: "#f0f1f5"
                                        font.pixelSize: 11
                                        background: null
                                        onTextEdited: {
                                            win.pendingTwitchKey = text
                                            win.twitchSaved = false
                                        }
                                        onEditingFinished: {
                                            if (text !== backend.twitchKey)
                                                backend.setSetting("TWITCH_KEY", text)
                                        }
                                    }

                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 4
                                        color: twitchEyeMouse.containsMouse ? "#282c42" : "transparent"

                                        Image {
                                            anchors.centerIn: parent
                                            width: 14
                                            height: 14
                                            source: "qrc:/icons/eye.svg"
                                            sourceSize: Qt.size(24, 24)
                                            fillMode: Image.PreserveAspectFit
                                            opacity: win.twitchKeyVisible ? 1.0 : 0.5
                                        }

                                        MouseArea {
                                            id: twitchEyeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.twitchKeyVisible = !win.twitchKeyVisible
                                        }
                                    }

                                    Rectangle {
                                        width: twitchSaveText.implicitWidth + 16
                                        height: 26
                                        radius: 4
                                        color: win.twitchSaved ? "#10b981" : (twitchSaveMouse.containsMouse ? "#772ce8" : "#9146ff")

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }

                                        Text {
                                            id: twitchSaveText
                                            anchors.centerIn: parent
                                            text: win.twitchSaved ? qsTr("Saved ✓") : qsTr("Save")
                                            color: "#ffffff"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: twitchSaveMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                backend.setSetting("TWITCH_KEY", twitchKeyField.text)
                                                win.twitchSaved = true
                                                twitchSavedTimer.restart()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Platform 3: Kick ──
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: kickCardCol.implicitHeight + 16
                        radius: 8
                        color: "#181a27"
                        border.width: 1
                        border.color: backend.kickEnabled ? "#1d3822" : "#232638"

                        ColumnLayout {
                            id: kickCardCol
                            anchors {
                                fill: parent
                                margins: 10
                            }
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Rectangle {
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: backend.kickEnabled ? (backend.kickKey !== "" ? "#53fc18" : "#e0af68") : "#5e6378"
                                }

                                Text {
                                    text: qsTr("Kick")
                                    color: "#f0f1f5"
                                    font.pixelSize: 13
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: kickDashText.implicitWidth + 12
                                    height: 22
                                    radius: 4
                                    color: kickDashMouse.containsMouse ? "#384166" : "#202334"
                                    border.width: 1
                                    border.color: "#2c3046"

                                    Text {
                                        id: kickDashText
                                        anchors.centerIn: parent
                                        text: qsTr("Dashboard ↗")
                                        color: "#8e93aa"
                                        font.pixelSize: 10
                                    }

                                    MouseArea {
                                        id: kickDashMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: backend.openKickDashboard()
                                    }
                                }

                                Switch {
                                    checked: backend.kickEnabled
                                    onToggled: backend.togglePlatform("kick")
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 38
                                radius: 6
                                color: "#13141f"
                                border.width: 1
                                border.color: kickKeyField.activeFocus ? "#53fc18" : "#25283c"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 6
                                    spacing: 6

                                    TextField {
                                        id: kickKeyField
                                        Layout.fillWidth: true
                                        echoMode: win.kickKeyVisible ? TextField.Normal : TextField.Password
                                        text: win.pendingKickKey
                                        placeholderText: qsTr("Paste Kick stream key (sk_…)…")
                                        color: "#f0f1f5"
                                        font.pixelSize: 11
                                        background: null
                                        onTextEdited: {
                                            win.pendingKickKey = text
                                            win.kickSaved = false
                                        }
                                        onEditingFinished: {
                                            if (text !== backend.kickKey)
                                                backend.setSetting("KICK_KEY", text)
                                        }
                                    }

                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 4
                                        color: kickEyeMouse.containsMouse ? "#282c42" : "transparent"

                                        Image {
                                            anchors.centerIn: parent
                                            width: 14
                                            height: 14
                                            source: "qrc:/icons/eye.svg"
                                            sourceSize: Qt.size(24, 24)
                                            fillMode: Image.PreserveAspectFit
                                            opacity: win.kickKeyVisible ? 1.0 : 0.5
                                        }

                                        MouseArea {
                                            id: kickEyeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: win.kickKeyVisible = !win.kickKeyVisible
                                        }
                                    }

                                    Rectangle {
                                        width: kickSaveText.implicitWidth + 16
                                        height: 26
                                        radius: 4
                                        color: win.kickSaved ? "#10b981" : (kickSaveMouse.containsMouse ? "#3eb813" : "#2d8b0e")

                                        Behavior on color {
                                            ColorAnimation { duration: 150 }
                                        }

                                        Text {
                                            id: kickSaveText
                                            anchors.centerIn: parent
                                            text: win.kickSaved ? qsTr("Saved ✓") : qsTr("Save")
                                            color: "#ffffff"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: kickSaveMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                backend.setSetting("KICK_KEY", kickKeyField.text)
                                                win.kickSaved = true
                                                kickSavedTimer.restart()
                                            }
                                        }
                                    }
                                }
                            }
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

                    // Resolution select
                    Text {
                        text: qsTr("Stream resolution limit")
                        color: "#a0a4b8"
                        font.pixelSize: 12
                    }

                    ComboBox {
                        id: resSelect
                        Layout.fillWidth: true
                        textRole: "label"
                        valueRole: "value"
                        model: [
                            { label: qsTr("Native / Auto (Display resolution)"), value: "auto" },
                            { label: qsTr("1080p Full HD (1920x1080)"), value: "1920x1080" },
                            { label: qsTr("720p HD (1280x720)"), value: "1280x720" },
                            { label: qsTr("1440p 2K QHD (2560x1440)"), value: "2560x1440" },
                            { label: qsTr("4K Ultra HD (3840x2160)"), value: "3840x2160" },
                            { label: qsTr("Custom resolution (WxH)…"), value: "custom" }
                        ]
                        onActivated: (index) => {
                            const v = model[index].value
                            if (v !== "custom") {
                                backend.setSetting("STREAM_RESOLUTION", v)
                            }
                        }
                    }

                    // Custom resolution field (when custom is selected or set)
                    Rectangle {
                        visible: resSelect.currentIndex === 5 || (backend.streamResolution !== "auto" && backend.streamResolution !== "1920x1080" && backend.streamResolution !== "1280x720" && backend.streamResolution !== "2560x1440" && backend.streamResolution !== "3840x2160" && backend.streamResolution !== "")
                        Layout.fillWidth: true
                        height: 38
                        radius: 6
                        color: "#1a1d2b"
                        border.width: 1
                        border.color: customResField.activeFocus ? "#5e81f4" : "#25283c"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 6

                            TextField {
                                id: customResField
                                Layout.fillWidth: true
                                text: backend.streamResolution === "auto" ? "" : backend.streamResolution
                                placeholderText: qsTr("Enter WxH (e.g. 1600x900 or 1920x1200)")
                                color: "#f0f1f5"
                                font.pixelSize: 12
                                background: null
                                onEditingFinished: {
                                    if (text.trim() !== "") {
                                        backend.setSetting("STREAM_RESOLUTION", text.trim())
                                    }
                                }
                            }

                            Rectangle {
                                width: customResApplyText.implicitWidth + 14
                                height: 26
                                radius: 4
                                color: customApplyMouse.containsMouse ? "#384166" : "#202334"
                                border.width: 1
                                border.color: "#2c3046"

                                Text {
                                    id: customResApplyText
                                    anchors.centerIn: parent
                                    text: qsTr("Apply")
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                    font.bold: true
                                }

                                MouseArea {
                                    id: customApplyMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (customResField.text.trim() !== "") {
                                            backend.setSetting("STREAM_RESOLUTION", customResField.text.trim())
                                        }
                                    }
                                }
                            }
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

                    // Screen Text Sharpness (enhances screen capture text clarity for low-res monitors)
                    Text {
                        text: qsTr("Screen text sharpness (monitor capture)")
                        color: "#a0a4b8"
                        font.pixelSize: 12
                    }

                    ComboBox {
                        id: screenSharpnessSelect
                        Layout.fillWidth: true
                        textRole: "label"
                        valueRole: "value"
                        model: [
                            { label: qsTr("Normal / Off (Default)"), value: "off" },
                            { label: qsTr("Crisp Text (Full contrast range & edge tuning)"), value: "crisp" },
                            { label: qsTr("High Sharpness (Clean text for 720p/900p monitors)"), value: "high" },
                            { label: qsTr("Ultra Sharp (Maximum font clarity & deblocking)"), value: "ultra" }
                        ]
                        currentIndex: {
                            const s = String(backend.screenSharpness || "off").toLowerCase()
                            if (s === "ultra" || s === "max" || s === "3") return 3
                            if (s === "high" || s === "medium" || s === "true" || s === "on" || s === "2") return 2
                            if (s === "crisp" || s === "low" || s === "1") return 1
                            return 0
                        }
                        onActivated: (index) => backend.setSetting("SCREEN_SHARPNESS", model[index].value)
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
            backend.stopAndQuit()
        }
        onRejected: backend.stopAndQuit()
    }

    Connections {
        target: backend
        function onConfigChanged() {
            outputSelect.currentIndex = outputIndexFor(backend.audioSystem, backend.systemOutputs)
            micSelect.currentIndex = outputIndexFor(backend.audioMic, backend.microphones)
            resSelect.currentIndex = resIndexFor(backend.streamResolution)
            if (!ytKeyField.activeFocus)
                win.pendingYtKey = backend.youtubeKey
            if (!twitchKeyField.activeFocus)
                win.pendingTwitchKey = backend.twitchKey
            if (!kickKeyField.activeFocus)
                win.pendingKickKey = backend.kickKey
        }
        function onAudioDevicesChanged() {
            outputSelect.currentIndex = outputIndexFor(backend.audioSystem, backend.systemOutputs)
            micSelect.currentIndex = outputIndexFor(backend.audioMic, backend.microphones)
        }
    }

    function resIndexFor(val) {
        if (!val || val === "auto" || val === "0x0") return 0
        if (val === "1920x1080" || val === "1080p") return 1
        if (val === "1280x720" || val === "720p") return 2
        if (val === "2560x1440" || val === "1440p") return 3
        if (val === "3840x2160" || val === "4k") return 4
        return 5
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
        resSelect.currentIndex = resIndexFor(backend.streamResolution)
    }
}

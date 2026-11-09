import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Omastream LIVE badge — appears on the bar only while live streaming.
//
// Left-click opens a compact popup with Stop Stream and Webcam toggle,
// middle-click directly toggles the camera bubble, right-click opens YouTube Studio.
// Synchronizes state with ~/.local/state/omastream/state.json.
BarWidget {
  id: root
  moduleName: "dhirajarya.omastream"

  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") + "/.local/state")) + "/omastream/state.json"

  property var state: ({})
  readonly property bool streaming: state.streaming === true
  readonly property bool camVisible: state && state.cam ? state.cam.visible === true : false
  readonly property bool privacyActive: state && state.privacy ? state.privacy.active === true : false
  readonly property string privacyMode: state && state.privacy && state.privacy.mode ? String(state.privacy.mode) : "blur"
  readonly property string mode: state && state.mode ? String(state.mode) : "stream"

  property string elapsed: "0:00"
  property bool popupOpen: false

  function close() {
    root.popupOpen = false
  }

  visible: streaming
  implicitHeight: barSize
  implicitWidth: streaming ? badge.width : 0

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.load(text())
    onLoadFailed: root.load("")
  }

  // Keep live bar synced with state.json heartbeat
  Timer {
    interval: root.streaming ? 250 : 500
    running: true
    repeat: true
    onTriggered: {
      stateFile.reload()
      if (root.streaming) root.updateElapsed()
    }
  }

  Timer {
    id: ticker
    interval: 1000
    repeat: true
    running: root.streaming
    triggeredOnStart: true
    onTriggered: root.updateElapsed()
  }

  function load(raw) {
    var parsed = {}
    try {
      var obj = JSON.parse(String(raw || "{}"))
      if (obj && typeof obj === "object") parsed = obj
    } catch (e) {
      parsed = {}
    }
    root.state = parsed
    if (!root.streaming) {
      root.popupOpen = false
    }
    root.updateElapsed()
  }

  function updateElapsed() {
    if (!root.streaming) {
      root.elapsed = "0:00"
      return
    }
    var start = state && state.startedAt ? Number(state.startedAt) : 0
    var s = start > 0 ? Math.max(0, Math.floor((Date.now() - start) / 1000)) : 0
    var m = Math.floor(s / 60)
    var h = Math.floor(m / 60)
    root.elapsed = h > 0
      ? (h + ":" + String(m % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0"))
      : (m + ":" + String(s % 60).padStart(2, "0"))
  }

  onStreamingChanged: {
    if (!root.streaming) {
      root.popupOpen = false
    }
    ticker.restart()
    updateElapsed()
  }

  Process {
    id: openStudio
    command: ["xdg-open", "https://studio.youtube.com"]
  }

  property real lastCmdTime: 0

  function runCmd(args) {
    var now = Date.now()
    if (args.length > 0 && args[0] !== "stop" && (now - lastCmdTime < 220)) {
      return
    }
    lastCmdTime = now

    if (root.service && typeof root.service.runCli === "function") {
      root.service.runCli(args)
      return
    }
    var shScript = 'if command -v omastream-cli >/dev/null 2>&1; then exec omastream-cli "$@"; elif [ -x "$HOME/.local/bin/omastream-cli" ]; then exec "$HOME/.local/bin/omastream-cli" "$@"; else exec /usr/bin/omastream-cli "$@"; fi'
    Quickshell.execDetached(["sh", "-c", shScript, "omastream-cli"].concat(args))
  }

  Rectangle {
    id: badge
    anchors.centerIn: parent
    width: badgeRow.implicitWidth + Style.space(10)
    height: Math.min(barSize - Style.space(8), Style.space(21))
    radius: height / 2
    color: root.privacyActive ? "#d97706" : Color.urgent

    Row {
      id: badgeRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      Rectangle {
        width: Style.space(7)
        height: width
        radius: width / 2
        color: "white"
        anchors.verticalCenter: parent.verticalCenter

        SequentialAnimation on opacity {
          running: root.streaming
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.3; duration: Style.duration(850) }
          NumberAnimation { from: 0.3; to: 1.0; duration: Style.duration(850) }
        }
      }

      Text {
        text: root.privacyActive ? "MASKED" : (root.mode === "file" ? "REC" : "LIVE")
        textFormat: Text.PlainText
        color: "white"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: root.elapsed
        textFormat: Text.PlainText
        color: "white"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        visible: !root.vertical
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.MiddleButton) {
        root.runCmd(["cam", "toggle"])
      } else if (mouse.button === Qt.RightButton) {
        openStudio.running = true
      } else {
        root.popupOpen = !root.popupOpen
      }
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, "omastream — click for controls, middle-click toggles camera")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: badge
    bar: root.bar
    owner: root
    open: root.popupOpen && root.streaming
    contentWidth: popup.fittedContentWidth(Style.space(190))
    contentHeight: popup.fittedContentHeight(popupCol.implicitHeight)

    Column {
      id: popupCol
      anchors.fill: parent
      spacing: Style.space(8)

      // ── Header: LIVE Status & Elapsed Timer ─────────────────────────
      Row {
        width: parent.width
        spacing: Style.space(8)

        Rectangle {
          width: Style.space(8)
          height: width
          radius: width / 2
          color: Color.urgent
          anchors.verticalCenter: parent.verticalCenter

          SequentialAnimation on opacity {
            running: root.streaming
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.3; duration: Style.duration(850) }
            NumberAnimation { from: 0.3; to: 1.0; duration: Style.duration(850) }
          }
        }

        Text {
          textFormat: Text.PlainText
          text: (root.mode === "file" ? "REC · " : "LIVE · ") + root.elapsed
          color: Color.urgent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // ── Divider ─────────────────────────────────────────────────────
      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(255, 255, 255, 0.08)
      }

      // ── Stop Stream Button ──────────────────────────────────────────
      Button {
        width: parent.width
        text: root.mode === "file" ? "Stop Recording" : "Stop Stream"
        iconText: "■"
        accent: Color.urgent
        bordered: true
        foreground: "white"
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: {
          root.popupOpen = false
          root.runCmd(["stop"])
        }
      }

      // ── Webcam Toggle Button ────────────────────────────────────────
      Button {
        width: parent.width
        text: root.camVisible ? "Hide Webcam" : "Show Webcam"
        bordered: true
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: {
          root.runCmd(["cam", "toggle"])
        }
      }

      // ── Privacy Filter Toggle Button ─────────────────────────────────
      Button {
        width: parent.width
        text: root.privacyActive ? "Disable Privacy Mask" : (root.privacyMode === "blur" ? "Blur Screen (Privacy)" : "Mask Screen (Privacy)")
        iconText: root.privacyActive ? "🔓" : "🛡️"
        accent: root.privacyActive ? "#d97706" : Color.accent
        bordered: true
        foreground: root.privacyActive ? "white" : Color.text
        horizontalPadding: Style.spacing.controlPaddingX
        verticalPadding: Style.spacing.controlPaddingY
        onClicked: {
          root.runCmd(["privacy", "toggle"])
        }
      }

      // ── Privacy Mode Quick Selectors ─────────────────────────────────
      Row {
        width: parent.width
        spacing: Style.space(4)

        Button {
          width: (parent.width - Style.space(8)) / 3
          text: "Blur"
          bordered: true
          accent: root.privacyMode === "blur" ? Color.accent : "transparent"
          onClicked: {
            root.runCmd(["privacy", "mode", "blur"])
          }
        }

        Button {
          width: (parent.width - Style.space(8)) / 3
          text: "Shield"
          bordered: true
          accent: root.privacyMode === "shield" ? Color.accent : "transparent"
          onClicked: {
            root.runCmd(["privacy", "mode", "shield"])
          }
        }

        Button {
          width: (parent.width - Style.space(8)) / 3
          text: "Black"
          bordered: true
          accent: root.privacyMode === "blackout" ? Color.accent : "transparent"
          onClicked: {
            root.runCmd(["privacy", "mode", "blackout"])
          }
        }
      }
    }
  }
}

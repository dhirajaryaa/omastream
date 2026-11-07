import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Omastream LIVE badge — hidden until a stream is running.
//
// Left-click opens a quick control popup (details, stop button, app/camera shortcuts),
// middle-click toggles camera bubble, right-click opens YouTube Studio.
// Reads ~/.local/state/omastream/state.json with FileView and watchChanges.
BarWidget {
  id: root
  moduleName: "dhirajarya.omastream"

  readonly property string omastreamBin: (Quickshell.env("HOME") || "/home/user") + "/.local/bin/omastream-cli"
  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") + "/.local/state")) + "/omastream/state.json"

  property var state: ({})
  readonly property bool streaming: state.streaming === true
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
    interval: 1000
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
    id: cmdProc
    onExited: {
      if (root.service && typeof root.service.reloadState === "function") {
        root.service.reloadState()
      }
    }
  }

  Process {
    id: toggleBarProc
    command: ["omarchy-toggle-bar"]
  }

  Process {
    id: openStudio
    command: ["xdg-open", "https://studio.youtube.com"]
  }

  Process {
    id: openApp
    command: ["omastream"]
  }

  function runCmd(args) {
    if (root.bar && typeof root.bar.run === "function") {
      root.bar.run([omastreamBin].concat(args).join(" "))
    } else {
      cmdProc.command = [omastreamBin].concat(args)
      cmdProc.running = true
    }
  }

  Rectangle {
    id: badge
    anchors.centerIn: parent
    width: badgeRow.implicitWidth + Style.space(10)
    height: Math.min(barSize - Style.space(8), Style.space(21))
    radius: height / 2
    color: Color.urgent

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
        text: root.mode === "file" ? "REC" : "LIVE"
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
        root.runCmd(["cam", "toggle"]) // middle-click: show/hide camera
      } else if (mouse.button === Qt.RightButton) {
        openStudio.running = true // right-click: YouTube Studio
      } else {
        root.popupOpen = !root.popupOpen // left-click: toggle popup
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
    contentWidth: popup.fittedContentWidth(Style.space(260))
    contentHeight: popup.fittedContentHeight(popupCol.implicitHeight)

    Column {
      id: popupCol
      anchors.fill: parent
      spacing: Style.space(10)

      // ── Header: LIVE Status & Title ─────────────────────────────────
      Row {
        width: parent.width
        spacing: Style.space(8)

        Rectangle {
          width: Style.space(10)
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

        Column {
          width: parent.width - Style.space(20)
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: root.mode === "file" ? "Local Test Recording" : "YouTube Live Stream"
            color: root.bar ? root.bar.foreground : "white"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            text: (root.mode === "file" ? "Recording · " : "Live · ") + root.elapsed
            color: Color.urgent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }
        }
      }

      // ── Divider ─────────────────────────────────────────────────────
      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(255, 255, 255, 0.08)
      }

      // ── Details ─────────────────────────────────────────────────────
      Column {
        width: parent.width
        spacing: Style.space(4)

        Row {
          spacing: Style.space(6)
          Text {
            text: "Destination:"
            color: Qt.darker(root.bar ? root.bar.foreground : "white", 1.8)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          Text {
            text: root.mode === "file" ? "Local test (test.flv)" : "YouTube RTMP"
            color: root.bar ? root.bar.foreground : "white"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Row {
          spacing: Style.space(6)
          Text {
            text: "Elapsed:"
            color: Qt.darker(root.bar ? root.bar.foreground : "white", 1.8)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
          Text {
            text: root.elapsed
            color: root.bar ? root.bar.foreground : "white"
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      // ── Prominent Stop Button ───────────────────────────────────────
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

      // ── Action Buttons Row ──────────────────────────────────────────
      Row {
        width: parent.width
        spacing: Style.space(6)

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "Camera"
          bordered: true
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: root.runCmd(["cam", "toggle"])
        }

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "Hide Bar"
          bordered: true
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: {
            root.popupOpen = false
            toggleBarProc.running = true
          }
        }

        Button {
          width: (parent.width - Style.space(12)) / 3
          text: "Omastream"
          bordered: true
          horizontalPadding: Style.spacing.controlPaddingX
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: {
            root.popupOpen = false
            openApp.running = true
          }
        }
      }
    }
  }
}

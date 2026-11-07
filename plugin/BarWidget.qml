import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Omastream LIVE badge — hidden until a stream is running.
//
// Left-click stops the stream, middle-click toggles the camera bubble, hover
// explains. Reads ~/.local/state/omastream/state.json (the CLI is the single
// writer) with a slow-poll fallback for missed file events.
BarWidget {
  id: root
  moduleName: "dhirajarya.omastream"

  readonly property string omastreamBin: (Quickshell.env("HOME") || "/home/user") + "/.local/bin/omastream-cli"
  readonly property string statePath: (Quickshell.env("XDG_STATE_HOME")
    || (Quickshell.env("HOME") + "/.local/state")) + "/omastream/state.json"

  property var state: ({})
  readonly property bool streaming: state.streaming === true

  property string elapsed: "0:00"

  visible: streaming
  implicitHeight: barSize
  implicitWidth: streaming ? badge.width : 0

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
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
    root.updateElapsed()
  }

  function updateElapsed() {
    var start = state && state.startedAt ? Number(state.startedAt) : 0
    var s = start > 0 ? Math.max(0, Math.floor((Date.now() - start) / 1000)) : 0
    var m = Math.floor(s / 60)
    var h = Math.floor(m / 60)
    root.elapsed = h > 0
      ? (h + ":" + String(m % 60).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0"))
      : (m + ":" + String(s % 60).padStart(2, "0"))
  }

  onStreamingChanged: {
    ticker.restart()
    updateElapsed()
  }

  Process {
    id: cmdProc
  }

  function runCmd(args) {
    cmdProc.command = [omastreamBin].concat(args)
    cmdProc.running = true
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
        text: "LIVE"
        textFormat: Text.PlainText
        color: "white"
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: root.elapsed
        textFormat: Text.PlainText
        color: "white"
        font.family: root.bar.fontFamily
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
        root.runCmd(["cam", "toggle"]) // middle-click: show/hide the camera
      } else if (mouse.button === Qt.RightButton) {
        openStudio.running = true // right-click: YouTube Live Control Room
      } else {
        root.runCmd(["stop"]) // left-click: graceful stop
      }
    }
    onEntered: root.bar.showTooltip(root, "omastream — click stops the stream, middle-click toggles the camera")
    onExited: root.bar.hideTooltip(root)
  }

  Process {
    id: openStudio
    command: ["xdg-open", "https://studio.youtube.com"]
  }
}

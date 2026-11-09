import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// The omastream privacy overlay — masks sensitive information and API keys on live streams.
//
// Displayed on the Overlay layer. Clicks pass through everywhere except the top dismiss pill
// so the developer can freely paste API keys, edit .env files, or fill credentials without
// viewers seeing any private tokens or secrets.
PanelWindow {
  id: root

  property var service: null

  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string statePath: (service && service.statePath) ? service.statePath : (stateHome + "/omastream/state.json")
  readonly property string omastreamBin: (service && service.omastreamBin) ? service.omastreamBin : ((Quickshell.env("HOME") || "/home/user") + "/.local/bin/omastream-cli")

  property var localState: ({})

  FileView {
    id: overlayStateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadState(text())
    onLoadFailed: root.loadState("")
  }

  function loadState(raw) {
    try {
      var obj = JSON.parse(String(raw || "{}"))
      if (obj && typeof obj === "object") localState = obj
    } catch (e) {
      localState = {}
    }
  }

  Timer {
    interval: 500
    running: true
    repeat: true
    onTriggered: overlayStateFile.reload()
  }

  readonly property var privacy: service && service.privacy ? service.privacy : (localState.privacy || null)
  readonly property bool privacyActive: privacy ? privacy.active === true : false
  readonly property string privacyMode: privacy && privacy.mode ? String(privacy.mode) : "blur"

  visible: privacyActive
  color: "transparent"

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  WlrLayershell.namespace: "omastream-privacy"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  // Only the top dismiss pill intercepts mouse clicks; entire remainder of screen is click-through
  mask: Region { item: dismissCard }

  Process {
    id: cmdProc
    onExited: {
      overlayStateFile.reload()
      if (root.service && typeof root.service.reloadState === "function") {
        root.service.reloadState()
      }
    }
  }

  function disablePrivacy() {
    cmdProc.command = [root.omastreamBin, "privacy", "off"]
    cmdProc.running = true
  }

  // ── Background Filter Surfaces ─────────────────────────────────────────────

  // Mode 1: Blur / Frosted Acrylic Screen Mask
  Rectangle {
    id: blurSurface
    visible: root.privacyMode === "blur"
    anchors.fill: parent
    color: "#f0080a10" // 94% opaque dark glass to obscure fine text and keys completely

    // Subtle technical grid accent pattern
    Canvas {
      anchors.fill: parent
      opacity: 0.12
      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.strokeStyle = "#5e81f4"
        ctx.lineWidth = 1
        var step = 48
        ctx.beginPath()
        for (var x = 0; x < width; x += step) {
          ctx.moveTo(x, 0)
          ctx.lineTo(x, height)
        }
        for (var y = 0; y < height; y += step) {
          ctx.moveTo(0, y)
          ctx.lineTo(width, y)
        }
        ctx.stroke()
      }
    }

    // Center HUD Card
    Rectangle {
      anchors.centerIn: parent
      width: Math.min(parent.width - 40, 480)
      height: 180
      radius: 16
      color: "#e6121422"
      border.width: 1
      border.color: "#334168"

      Column {
        anchors.centerIn: parent
        spacing: 12
        width: parent.width - 48

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 10

          Rectangle {
            width: 32
            height: 32
            radius: 16
            color: "#253456"
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.centerIn: parent
              text: "🔒"
              font.pixelSize: 16
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
              text: "PRIVACY FILTER ACTIVE"
              color: "#ffffff"
              font.family: "JetBrains Mono, monospace"
              font.pixelSize: 15
              font.bold: true
            }

            Text {
              text: "Screen contents masked · Live stream protected"
              color: "#7aa2f7"
              font.pixelSize: 12
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: "#252b42"
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Safe to configure API keys, passwords, and environment variables.\nClick-through is active for typing; click the top button to unmask."
          color: "#9aa0b8"
          font.pixelSize: 11
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }

  // Mode 2: Privacy Shield Curtain (Stream Paused / Be Right Back)
  Rectangle {
    id: shieldSurface
    visible: root.privacyMode === "shield"
    anchors.fill: parent
    color: "#0c0e18"

    Column {
      anchors.centerIn: parent
      spacing: 16
      width: Math.min(parent.width - 40, 520)

      // Outer animated pulsing ring
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 80
        height: 80
        radius: 40
        color: "#1a2540"
        border.width: 2
        border.color: "#5e81f4"

        SequentialAnimation on scale {
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 1.08; duration: 1200; easing.type: Easing.InOutQuad }
          NumberAnimation { from: 1.08; to: 1.0; duration: 1200; easing.type: Easing.InOutQuad }
        }

        Text {
          anchors.centerIn: parent
          text: "🛡️"
          font.pixelSize: 36
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "STREAM PAUSED"
        color: "#ffffff"
        font.family: "JetBrains Mono, monospace"
        font.pixelSize: 22
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Configuring sensitive credentials & API keys"
        color: "#7aa2f7"
        font.pixelSize: 13
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Stream will resume shortly • Please stand by"
        color: "#8389a4"
        font.pixelSize: 12
      }

      // Live status pill
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 140
        height: 26
        radius: 13
        color: "#1f1d32"
        border.width: 1
        border.color: "#e53935"

        Row {
          anchors.centerIn: parent
          spacing: 6

          Rectangle {
            width: 7
            height: 7
            radius: 3.5
            color: "#e53935"
            anchors.verticalCenter: parent.verticalCenter

            SequentialAnimation on opacity {
              loops: Animation.Infinite
              NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
              NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
            }
          }

          Text {
            text: "PROTECTED"
            color: "#ff6b6b"
            font.family: "JetBrains Mono, monospace"
            font.pixelSize: 10
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }

  // Mode 3: Blackout Curtain
  Rectangle {
    id: blackoutSurface
    visible: root.privacyMode === "blackout"
    anchors.fill: parent
    color: "#000000"
  }

  // ── Top Interactive Dismiss Pill ───────────────────────────────────────────
  // Positioned at top-center of the screen so developer can quickly unmask with one click
  Rectangle {
    id: dismissCard
    anchors {
      top: parent.top
      topMargin: 16
      horizontalCenter: parent.horizontalCenter
    }
    width: dismissRow.implicitWidth + 24
    height: 38
    radius: 19
    color: dismissMouse.containsMouse ? "#2f1b1d" : "#1f151b"
    border.width: 1.5
    border.color: dismissMouse.containsMouse ? "#ff5555" : "#e53935"

    Row {
      id: dismissRow
      anchors.centerIn: parent
      spacing: 10

      Rectangle {
        width: 8
        height: 8
        radius: 4
        color: "#e53935"
        anchors.verticalCenter: parent.verticalCenter

        SequentialAnimation on opacity {
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.2; duration: 600 }
          NumberAnimation { from: 0.2; to: 1.0; duration: 600 }
        }
      }

      Text {
        text: "🔒 PRIVACY FILTER ON"
        color: "#ffffff"
        font.family: "JetBrains Mono, monospace"
        font.pixelSize: 11
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        width: 1
        height: 16
        color: "#4a2528"
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: "Click to Disable / Resume Stream ✕"
        color: dismissMouse.containsMouse ? "#ff8888" : "#ffaaaa"
        font.pixelSize: 11
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: dismissMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.disablePrivacy()
    }
  }
}

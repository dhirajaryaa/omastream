import QtQuick
import Qt5Compat.GraphicalEffects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// The omastream camera bubble — a self-view built for streaming.
//
// Parked per (shape, display) as "shape@screen" fraction geometry that the CLI
// mirrors into gpu-screen-recorder's composite, so this bubble and the camera
// inside the live frame always sit at the same spot. Overlay layer, shown only
// where it is parked, click-through everywhere except its own box.
//
// Shapes: circle / 1:1 / 16:9. Drag to move, grab the bottom-right grip to
// resize (the shape ratio is kept). Persisted through `omastream cam save` —
// the CLI stays the single state writer.
//
// While gsr holds the camera for the stream the device is busy: the preview
// pauses and shows a themed LIVE placeholder until the stream ends.
PanelWindow {
  id: root

  required property var service

  // ── where is this bubble wanted ─────────────────────────────────────────────
  readonly property string screenName: screen && screen.name ? String(screen.name) : ""
  readonly property string focusScreenName: {
    var m = Hyprland.focusedMonitor
    return m && m.name ? String(m.name)
      : (Quickshell.screens.length ? String(Quickshell.screens[0].name) : "")
  }
  readonly property var cam: service.cam
  readonly property string shape: service.camShape
  readonly property string myKey: shape + "@" + screenName
  readonly property var allGeom: cam && cam.geometry ? cam.geometry : null
  readonly property bool haveShapeAnywhere: {
    if (!allGeom) return false
    for (var k in allGeom) {
      if (String(k).indexOf(shape + "@") === 0) return true
    }
    return false
  }
  readonly property bool parkedHere: !!allGeom && !!allGeom[myKey]
  readonly property bool fallbackHost: !haveShapeAnywhere && screenName === focusScreenName
  visible: service.camVisible && (parkedHere || fallbackHost)

  // ── geometry: fractions of the display, defaults mirror the CLI ─────────────
  readonly property real logicalW: screen && screen.width > 0 ? screen.width : 1920
  readonly property real logicalH: screen && screen.height > 0 ? screen.height : 1080

  readonly property var shapeGeom: parkedHere ? allGeom[myKey] : null
  readonly property var defaults: {
    if (shape === "circle") return { "x": 0.78, "y": 0.68, "size": 0.17 }
    if (shape === "1:1") return { "x": 0.75, "y": 0.62, "size": 0.20 }
    return { "x": 0.62, "y": 0.58, "size": 0.30 }
  }

  property real dragX: -1
  property real dragY: -1
  property real dragSize: -1
  property point moveOriginMouse
  property point moveOriginFrac
  property real resizeOriginSize: -1

  readonly property bool resizing: resizeArea.pressed
  readonly property bool moving: moveArea.pressed
  readonly property real sizeFrac: dragSize >= 0 ? dragSize
    : (shapeGeom ? shapeGeom.size : defaults.size)
  readonly property real xFrac: dragX >= 0 ? dragX
    : (shapeGeom ? shapeGeom.x : defaults.x)
  readonly property real yFrac: dragY >= 0 ? dragY
    : (shapeGeom ? shapeGeom.y : defaults.y)

  readonly property real fracH: shape === "16:9" ? sizeFrac * 9 / 16 : sizeFrac
  readonly property real boxWidth: Math.max(88, sizeFrac * logicalW)
  readonly property real boxHeight: Math.max(50, fracH * logicalH)
  readonly property real radius: shape === "circle"
    ? Math.min(boxWidth, boxHeight) / 2 : Style.cornerRadius

  readonly property real xPos: Math.max(0, Math.min(xFrac, 1 - sizeFrac)) * logicalW
  readonly property real yPos: Math.max(0, Math.min(yFrac, 1 - fracH)) * logicalH

  anchors { top: true; left: true }
  color: "transparent"
  implicitWidth: Math.round(boxWidth)
  implicitHeight: Math.round(boxHeight)
  margins.left: Math.round(xPos)
  margins.top: Math.round(yPos)

  WlrLayershell.namespace: "omastream-bubble"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  // Everything outside `frame` passes clicks through to the windows below.
  mask: Region { item: frame }

  // ── persistence ──────────────────────────────────────────────────────────────
  property string omastreamBin: (Quickshell.env("HOME") || "/home/user") + "/.local/bin/omastream-cli"

  Process {
    id: saveProc
    onExited: () => {
      root.dragX = -1
      root.dragY = -1
      root.dragSize = -1
      root.resizeOriginSize = -1
    }
  }

  Process { id: cmdProc }

  function runCmd(args) {
    cmdProc.command = [omastreamBin].concat(args)
    cmdProc.running = true
  }

  function saveNow() {
    saveProc.command = [omastreamBin, "cam", "save", JSON.stringify({
      shape: shape,
      screen: screenName,
      x: xFrac,
      y: yFrac,
      size: sizeFrac
    })]
    saveProc.running = true
  }

  // When no geometry exists anywhere for this shape yet, the focused display's
  // bubble seeds it: visible at the shape's defaults, then persisted so the
  // CLI and the stream agree from that point on.
  property bool seeding: false
  onVisibleChanged: {
    camera.deviceBusy = false
    Qt.callLater(root.seedIfNeeded)
  }
  onShapeChanged: {
    seeding = false
    Qt.callLater(root.seedIfNeeded)
  }

  function seedIfNeeded() {
    if (!visible || parkedHere || haveShapeAnywhere || seeding) return
    seeding = true
    saveNow()
  }

  // ── camera ────────────────────────────────────────────────────────────────────
  MediaDevices { id: mediaDevices }

  // state wins, config.env is the fallback (state may not carry it yet).
  readonly property bool flip: cam && cam.flip !== null && cam.flip !== undefined
    ? cam.flip === true : service.camConf.flip === true

  readonly property bool deviceHeldByGsr: service.gsrOwnsCamera
  onDeviceHeldByGsrChanged: if (!deviceHeldByGsr) camera.deviceBusy = false

  Camera {
    id: camera
    cameraDevice: root.pickDevice()
    active: root.visible && !root.deviceHeldByGsr && !deviceBusy
    property bool deviceBusy: false
    onCameraErrorOccurred: (error) => { deviceBusy = true }
  }

  function pickDevice() {
    var want = cam ? String(cam.device || "") : ""
    var inputs = mediaDevices.videoInputs
    if (want !== "" && inputs.length > 0) {
      var base = want.split("/").pop()
      for (var i = 0; i < inputs.length; i++) {
        var dev = inputs[i]
        if (String(dev.id || "").indexOf(base) >= 0 || String(dev.description || "") === want)
          return dev
      }
    }
    return inputs.length > 0 ? inputs[0] : null
  }

  CaptureSession {
    camera: camera
    videoOutput: videoOut
  }

  readonly property bool videoShowing: camera.active && !camera.deviceBusy
    && !deviceHeldByGsr && camera.cameraDevice !== null

  // ── the bubble ───────────────────────────────────────────────────────────────
  Rectangle {
    id: frame
    anchors.fill: parent
    radius: root.radius
    color: Color.background
    border.width: root.resizing || root.moving ? 2 : Style.normalBorderWidth
    border.color: root.hots ? Color.urgent : Style.normalBorderColor

    // camera feed, masked to the shape
    Item {
      id: videoHost
      anchors.fill: parent
      anchors.margins: 1
      visible: root.videoShowing

      VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        scale: root.flip ? -1 : 1
        transformOrigin: Item.Center
      }

      Rectangle { // shape mask fed to the opacity mask
        id: videoMask
        visible: false
        anchors.fill: parent
        radius: root.radius
        color: "#000000"
      }

      OpacityMask {
        anchors.fill: parent
        source: videoOut
        maskSource: videoMask
      }
    }

    // placeholder: gsr holds the camera for the stream, or none exists
    Item {
      id: placeholder
      anchors.fill: parent
      anchors.margins: 1
      visible: !videoHost.visible

      Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(Color.background, 0.55)
      }

      Item { // glyph: drawn shapes, no icon font needed
        anchors.centerIn: parent
        width: parent.width * 0.24
        height: width

        Rectangle {
          width: parent.width
          height: parent.height * 0.66
          radius: width * 0.22
          color: Style.normalBorderColor
        }
        Rectangle {
          x: parent.width * 0.3
          y: parent.height * 0.24
          width: parent.height * 0.48
          height: parent.height * 0.48
          radius: width / 2
          color: Color.background
        }
      }

      Rectangle { // pulsing corner dot while it is composited live
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Style.space(2)
        anchors.rightMargin: Style.space(2)
        visible: root.deviceHeldByGsr
        width: Style.space(10)
        height: width
        radius: width / 2
        color: Color.urgent

        SequentialAnimation on opacity {
          running: root.deviceHeldByGsr
          loops: Animation.Infinite
          NumberAnimation { from: 1.0; to: 0.35; duration: Style.duration(750) }
          NumberAnimation { from: 0.35; to: 1.0; duration: Style.duration(750) }
        }
      }
    }

    // ── move ────────────────────────────────────────────────────────────────────
    MouseArea {
      id: moveArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

      onPressed: (mouse) => {
        root.moveOriginMouse = Qt.point(mouse.x, mouse.y)
        root.moveOriginFrac = Qt.point(root.xFrac, root.yFrac)
        root.dragX = root.xFrac
        root.dragY = root.yFrac
      }
      onPositionChanged: (mouse) => {
        if (!pressed) return
        root.dragX = root.moveOriginFrac.x + (mouse.x - root.moveOriginMouse.x) / root.logicalW
        root.dragY = root.moveOriginFrac.y + (mouse.y - root.moveOriginMouse.y) / root.logicalH
      }
      onReleased: root.commitMove()
      onCanceled: root.commitMove()
    }

    // ── hover pill: shape switch + hide ────────────────────────────────────────
    readonly property bool hots: moveArea.containsMouse || resizeArea.containsMouse
      || pillBtnCircle.containsMouse || pillBtnSquare.containsMouse
      || pillBtnWide.containsMouse || pillBtnOff.containsMouse

    Item {
      id: pill
      visible: root.hots || root.resizing
      anchors.top: parent.top
      anchors.topMargin: Style.space(2)
      anchors.horizontalCenter: parent.horizontalCenter
      height: Style.space(24)

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(-2)
        radius: height / 2
        color: Qt.alpha(Color.background, 0.94)
        border.width: Style.normalBorderWidth
        border.color: Style.normalBorderColor
      }

      Row {
        id: pillRow
        anchors.centerIn: parent
        spacing: Style.space(2)

        MouseArea {
          id: pillBtnCircle
          width: pill.height
          height: pill.height
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.runCmd(["cam", "shape", "circle"])

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.shape === "circle" ? Qt.alpha(Color.accent, 0.25)
                 : parent.containsMouse ? Qt.alpha(Color.accent, 0.10) : "transparent"
          }
          Rectangle {
            anchors.centerIn: parent
            width: parent.height * 0.36
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Color.urgent
          }
        }

        MouseArea {
          id: pillBtnSquare
          width: pill.height
          height: pill.height
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.runCmd(["cam", "shape", "1:1"])

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.shape === "1:1" ? Qt.alpha(Color.accent, 0.25)
                 : parent.containsMouse ? Qt.alpha(Color.accent, 0.10) : "transparent"
          }
          Rectangle {
            anchors.centerIn: parent
            width: parent.height * 0.30
            height: width
            radius: 3
            color: "transparent"
            border.width: 2
            border.color: Color.urgent
          }
        }

        MouseArea {
          id: pillBtnWide
          width: pill.height
          height: pill.height
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.runCmd(["cam", "shape", "16:9"])

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: root.shape === "16:9" ? Qt.alpha(Color.accent, 0.25)
                 : parent.containsMouse ? Qt.alpha(Color.accent, 0.10) : "transparent"
          }
          Rectangle {
            anchors.centerIn: parent
            width: parent.height * 0.40
            height: parent.height * 0.24
            radius: 3
            color: "transparent"
            border.width: 2
            border.color: Color.urgent
          }
        }

        MouseArea {
          id: pillBtnOff
          width: pill.height
          height: pill.height
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.runCmd(["cam", "off"])

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: parent.pressed ? Qt.alpha(Color.urgent, 0.25)
                 : parent.containsMouse ? Qt.alpha(Color.urgent, 0.10) : "transparent"
          }
          Text {
            anchors.centerIn: parent
            text: "×"
            textFormat: Text.PlainText
            color: Color.urgent
            font.pixelSize: Math.round(pill.height * 0.55)
            font.bold: true
          }
        }
      }
    }

    // ── resize grip (bottom-right, keeps the shape ratio) ──────────────────────
    MouseArea {
      id: resizeArea
      width: Style.space(34)
      height: Style.space(34)
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      hoverEnabled: true
      cursorShape: Qt.SizeFDiagCursor
      acceptedButtons: Qt.LeftButton
      visible: root.hots

      onPressed: (mouse) => {
        root.resizeOriginSize = root.sizeFrac
        root.dragSize = root.sizeFrac
      }
      onPositionChanged: (mouse) => {
        if (!pressed) return
        var ns = root.resizeOriginSize + (mouse.x + mouse.y) / 2 / root.logicalW
        root.dragSize = Math.max(0.05, Math.min(0.75, ns))
      }
      onReleased: root.commitResize()
      onCanceled: root.commitResize()

      Rectangle {
        anchors.centerIn: parent
        width: Style.space(10)
        height: width
        radius: width / 2
        color: root.resizing ? Color.urgent : Style.normalBorderColor
      }
    }
  }

  function commitMove() {
    if (dragX < 0) return
    saveNow() // drag overrides clear once the CLI accepted the save
  }

  function commitResize() {
    if (dragSize < 0) return
    saveNow()
  }
}

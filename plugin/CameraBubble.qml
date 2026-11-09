import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// The omastream camera bubble — a floating self-view built for live streaming.
//
// Overlay layer, click-through everywhere except its own box.
// Shapes: 1:1 Square, 16:9 Widescreen, Circle.
// Dynamic Rounded Corner Slider: adjust from 0px (sharp square/rectangle) to squircle to full round!
// Sharpness Filter Slider: adjust video sharpness / clarity from 0.0 to 1.0 (OBS-style filter).
// Corner snapping: Top-Left, Top-Right, Bottom-Left, Bottom-Right.
// Drag to move with magnetic corner snapping; grab bottom-right grip to resize.
PanelWindow {
  id: root

  property var service: null

  // ── state synchronization (single writer: omastream CLI) ─────────────────────
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string statePath: (service && service.statePath) ? service.statePath : (stateHome + "/omastream/state.json")
  readonly property string confPath: (service && service.confPath) ? service.confPath : (Quickshell.env("HOME") + "/.config/omastream/config.env")

  property var localState: ({})
  property var localConf: ({})

  FileView {
    id: bubbleStateFile
    path: root.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadLocalState(text())
    onLoadFailed: root.loadLocalState("")
  }

  FileView {
    id: bubbleConfFile
    path: root.confPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.loadLocalConfig(text())
    onLoadFailed: root.loadLocalConfig("")
  }

  function loadLocalState(raw) {
    try {
      var obj = JSON.parse(String(raw || "{}"))
      if (obj && typeof obj === "object") localState = obj
    } catch (e) {
      localState = {}
    }
  }

  function loadLocalConfig(raw) {
    var c = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var eq = lines[i].indexOf("=")
      if (eq < 1) continue
      var k = lines[i].slice(0, eq).trim()
      var v = lines[i].slice(eq + 1).split("#")[0].trim()
      c[k] = v
    }
    localConf = {
      record: String(c.CAM_RECORD || "true") !== "false",
      flip: String(c.CAM_FLIP || "true") !== "false"
    }
  }

  Timer {
    interval: 800
    running: true
    repeat: true
    onTriggered: {
      bubbleStateFile.reload()
      bubbleConfFile.reload()
    }
  }

  // ── camera properties ────────────────────────────────────────────────────────
  readonly property var cam: service && service.cam ? service.cam : (localState.cam || null)
  readonly property bool camVisible: cam ? cam.visible === true : false

  property string localShape: ""
  readonly property string shape: localShape.length > 0
    ? localShape
    : (service && service.camShape ? service.camShape : (cam && cam.shape ? String(cam.shape) : "1:1"))

  property var localFlip: null
  readonly property bool flip: localFlip !== null
    ? (localFlip === true)
    : (cam && cam.flip !== null && cam.flip !== undefined
      ? cam.flip === true
      : (service && service.camConf ? service.camConf.flip === true : (localConf.flip !== false)))

  property bool locallyHidden: false
  onCamVisibleChanged: {
    if (root.camVisible) locallyHidden = false
  }

  property bool userPositioned: false

  // Corner radius ratio (0.0 = sharp corners, 1.0 = fully round)
  property real radiusRatio: {
    if (cam && typeof cam.radius === "number") {
      var r = cam.radius
      return (r > 1.0) ? Math.min(1.0, r / 60.0) : Math.max(0.0, Math.min(1.0, r))
    }
    return 0.20
  }

  // ── monitor resolution & visibility ──────────────────────────────────────────
  readonly property string screenName: screen && screen.name ? String(screen.name) : ""
  readonly property string focusScreenName: {
    try {
      if (typeof Hyprland !== "undefined" && Hyprland && Hyprland.focusedMonitor && Hyprland.focusedMonitor.name) {
        return String(Hyprland.focusedMonitor.name)
      }
    } catch (e) {}
    return Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0].name
      ? String(Quickshell.screens[0].name) : ""
  }

  readonly property real logicalW: screen && screen.width > 0 ? screen.width : 1920
  readonly property real logicalH: screen && screen.height > 0 ? screen.height : 1080

  readonly property var allGeom: cam && cam.geometry ? cam.geometry : null
  readonly property string myKey: shape + "@" + screenName

  readonly property var shapeGeom: {
    if (!allGeom) return null
    if (allGeom[myKey]) return allGeom[myKey]
    if (allGeom[shape + "@screen"]) return allGeom[shape + "@screen"]
    for (var k in allGeom) {
      if (k.indexOf(shape + "@") === 0 && allGeom[k]) return allGeom[k]
    }
    return null
  }

  readonly property bool isTargetScreen: {
    if (!Quickshell.screens || Quickshell.screens.length <= 1) return true
    if (shapeGeom !== null && allGeom && allGeom[myKey]) return true
    if (focusScreenName && screenName === focusScreenName) return true
    var firstScreen = Quickshell.screens.length > 0 ? String(Quickshell.screens[0].name || "") : ""
    return screenName === firstScreen
  }

  // Check whether omastream app is running or streaming is active
  readonly property bool appRunning: {
    if (service && service.appRunning) return true
    if (localState && localState.appRunning === true) return true
    return false
  }
  readonly property bool canShowCamera: service ? (service.streaming || appRunning) : (localState.streaming === true || appRunning)

  // Visible ONLY when requested, on target screen, AND either live streaming or app is open
  visible: !root.locallyHidden && root.camVisible && root.isTargetScreen && root.canShowCamera

  // ── geometry fractions & dimensions ──────────────────────────────────────────
  readonly property var defaults: {
    if (shape === "circle") return { "x": 0.78, "y": 0.68, "size": 0.17 }
    if (shape === "1:1") return { "x": 0.75, "y": 0.62, "size": 0.20 }
    return { "x": 0.62, "y": 0.58, "size": 0.30 }
  }

  property real currentXFrac: defaults.x
  property real currentYFrac: defaults.y
  property real currentSizeFrac: defaults.size

  function syncFromGeom() {
    if (moving || resizing) return
    var geom = shapeGeom
    if (geom && typeof geom.x === "number") {
      currentXFrac = geom.x
      if (typeof geom.y === "number") currentYFrac = geom.y
      if (typeof geom.size === "number") currentSizeFrac = geom.size
      root.userPositioned = true
    } else if (!root.userPositioned && defaults) {
      currentXFrac = defaults.x
      currentYFrac = defaults.y
      currentSizeFrac = defaults.size
    }
  }

  onShapeGeomChanged: syncFromGeom()
  onShapeChanged: syncFromGeom()
  Component.onCompleted: syncFromGeom()

  // True 1:1 square width == height in pixels!
  readonly property real boxWidth: Math.max(90, Math.round(currentSizeFrac * logicalW))
  readonly property real boxHeight: {
    if (shape === "1:1" || shape === "circle") return boxWidth
    return Math.max(50, Math.round(boxWidth * 9.0 / 16.0))
  }

  readonly property real fracW: boxWidth / logicalW
  readonly property real fracH: boxHeight / logicalH

  readonly property real maxRadius: Math.min(boxWidth, boxHeight) / 2
  readonly property real effectiveRadius: {
    if (shape === "circle") return maxRadius
    return Math.max(0, Math.min(maxRadius, Math.round(root.radiusRatio * maxRadius)))
  }

  readonly property real xPos: Math.max(0, Math.min(currentXFrac, 1 - fracW)) * logicalW
  readonly property real yPos: Math.max(0, Math.min(currentYFrac, 1 - fracH)) * logicalH

  // ── surface anchors & layer configuration ──────────────────────────────────
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"

  WlrLayershell.namespace: "omastream-bubble"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  // Only the bubble frame catches clicks; remainder of display is click-through
  mask: Region { item: frame }

  // ── persistence & commands ──────────────────────────────────────────────────
  Timer {
    id: delayedReload
    interval: 150
    repeat: false
    onTriggered: {
      bubbleStateFile.reload()
      if (root.service && typeof root.service.reloadState === "function") {
        root.service.reloadState()
      }
    }
  }

  function runCmd(args) {
    if (root.service && typeof root.service.runCli === "function") {
      root.service.runCli(args)
    } else {
      var shScript = 'if command -v omastream-cli >/dev/null 2>&1; then exec omastream-cli "$@"; elif [ -x "$HOME/.local/bin/omastream-cli" ]; then exec "$HOME/.local/bin/omastream-cli" "$@"; else exec /usr/bin/omastream-cli "$@"; fi'
      Quickshell.execDetached(["sh", "-c", shScript, "omastream-cli"].concat(args))
    }
    delayedReload.restart()
  }

  // ── Debounced and Throttled State Persistence ──────────────────────────────
  property real lastSaveTime: 0

  Timer {
    id: saveDebounceTimer
    interval: 220
    repeat: false
    onTriggered: root.executeSave()
  }

  function saveNow(immediate) {
    root.userPositioned = true
    var now = Date.now()
    if (immediate === true || (now - root.lastSaveTime > 650)) {
      saveDebounceTimer.stop()
      root.executeSave()
    } else {
      saveDebounceTimer.restart()
    }
  }

  function executeSave() {
    root.lastSaveTime = Date.now()
    var payload = JSON.stringify({
      shape: shape,
      screen: screenName,
      x: currentXFrac,
      y: currentYFrac,
      size: currentSizeFrac,
      radius: root.radiusRatio
    })
    runCmd(["cam", "save", payload])
  }

  property real lastShapeTime: 0
  function setShape(newShape) {
    if (root.shape === newShape) return
    var now = Date.now()
    if (now - root.lastShapeTime < 250) return
    root.lastShapeTime = now

    root.localShape = newShape
    root.userPositioned = false
    root.syncFromGeom()
    root.runCmd(["cam", "shape", newShape])
    root.saveNow(true)
  }

  property real lastFlipTime: 0
  function toggleFlip() {
    var now = Date.now()
    if (now - root.lastFlipTime < 250) return
    root.lastFlipTime = now

    var nextVal = !root.flip
    root.localFlip = nextVal
    root.runCmd(["cam", "flip", nextVal ? "true" : "false"])
  }

  property real lastCloseTime: 0
  function closeBubble() {
    var now = Date.now()
    if (now - root.lastCloseTime < 300) return
    root.lastCloseTime = now

    root.locallyHidden = true
    root.runCmd(["cam", "off"])
  }

  function snapCorner(corner) {
    var sw = fracW
    var sh = fracH
    var nx = 0.03
    var ny = 0.04
    if (corner === "bottom-right" || corner === "br") {
      nx = 1.0 - sw - 0.03
      ny = 1.0 - sh - 0.04
    } else if (corner === "bottom-left" || corner === "bl") {
      nx = 0.03
      ny = 1.0 - sh - 0.04
    } else if (corner === "top-right" || corner === "tr") {
      nx = 1.0 - sw - 0.03
      ny = 0.04
    } else if (corner === "top-left" || corner === "tl") {
      nx = 0.03
      ny = 0.04
    }
    currentXFrac = Math.max(0, Math.min(nx, 1 - sw))
    currentYFrac = Math.max(0, Math.min(ny, 1 - sh))
    userPositioned = true
    saveNow(true)
  }

  // ── camera capture pipeline ──────────────────────────────────────────────────
  MediaDevices { id: mediaDevices }

  Camera {
    id: camera
    cameraDevice: mediaDevices.defaultVideoInput
    active: root.camVisible && root.canShowCamera && !deviceBusy && cameraDevice !== null
    property bool deviceBusy: false
    onErrorOccurred: (error, errorString) => {
      console.warn("CameraBubble camera error: " + errorString)
      deviceBusy = true
    }
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

  readonly property bool videoShowing: camera.active && !camera.deviceBusy && camera.cameraDevice !== null

  // ── user interaction state (Zero-flicker hover management) ──────────────────
  property bool controlsVisible: false
  property bool sliderActive: false
  property point moveOriginMouse
  property point moveOriginFrac
  property point resizeOriginMouse
  property real resizeOriginSize: -1
  property bool moveDirty: false
  property bool resizeDirty: false

  readonly property bool moving: moveArea.pressed
  readonly property bool resizing: resizeArea.pressed

  // ── the floating bubble item ────────────────────────────────────────────────
  Rectangle {
    id: frame
    x: Math.round(root.xPos)
    y: Math.round(root.yPos)
    width: Math.round(root.boxWidth)
    height: Math.round(root.boxHeight)
    radius: root.effectiveRadius
    color: Color.background
    border.width: Style.normalBorderWidth
    border.color: Style.normalBorderColor

    // ── Passive Hover Detection (Never flickers, never re-renders video) ───────
    HoverHandler {
      id: bubbleHover
      onHoveredChanged: {
        if (hovered) {
          hoverGraceTimer.stop()
          root.controlsVisible = true
        } else {
          hoverGraceTimer.restart()
        }
      }
    }

    Timer {
      id: hoverGraceTimer
      interval: 450
      onTriggered: {
        if (!bubbleHover.hovered && !root.moving && !root.resizing && !root.sliderActive) {
          root.controlsVisible = false
        }
      }
    }

    // ── 1. Live video output with horizontal mirror & corner rounding ─────────
    Item {
      id: videoHost
      anchors.fill: parent
      anchors.margins: 1
      visible: root.videoShowing

      // MultiEffect applied only when rounding is active (> 0)
      layer.enabled: root.effectiveRadius > 0
      layer.smooth: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: maskRect
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
      }

      VideoOutput {
        id: videoOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        transformOrigin: Item.Center
        transform: Scale {
          xScale: root.flip ? -1 : 1
          origin.x: videoOut.width / 2
        }
      }
    }

    // Mask source for MultiEffect
    Rectangle {
      id: maskRect
      anchors.fill: parent
      radius: root.effectiveRadius
      color: "black"
      visible: false
      layer.enabled: true
    }

    // Camera placeholder when waiting for device or camera off
    Item {
      id: placeholder
      anchors.fill: parent
      anchors.margins: 1
      visible: !videoHost.visible

      Rectangle {
        anchors.fill: parent
        radius: root.effectiveRadius
        color: Qt.alpha(Color.background, 0.65)
      }

      Item {
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
    }

    // ── Active Outline Highlight (Smooth transition, never affects video) ─────
    Rectangle {
      id: activeHighlight
      anchors.fill: parent
      radius: root.effectiveRadius
      color: "transparent"
      border.width: root.moving || root.resizing ? 2 : 1
      border.color: root.moving || root.resizing ? Color.urgent : Color.accent
      opacity: root.moving || root.resizing ? 0.9 : (root.controlsVisible ? 0.5 : 0.0)
      Behavior on opacity { NumberAnimation { duration: 150 } }
      z: 5
    }

    // ── Drag Movement with magnetic edge/corner snapping ─────────────────────
    MouseArea {
      id: moveArea
      anchors.fill: parent
      hoverEnabled: false
      acceptedButtons: Qt.LeftButton
      cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      z: 10

      onPressed: (mouse) => {
        var pt = moveArea.mapToItem(null, mouse.x, mouse.y)
        root.moveOriginMouse = Qt.point(pt.x, pt.y)
        root.moveOriginFrac = Qt.point(root.currentXFrac, root.currentYFrac)
        root.moveDirty = false
      }
      onPositionChanged: (mouse) => {
        if (!pressed) return
        var pt = moveArea.mapToItem(null, mouse.x, mouse.y)
        var rawX = root.moveOriginFrac.x + (pt.x - root.moveOriginMouse.x) / root.logicalW
        var rawY = root.moveOriginFrac.y + (pt.y - root.moveOriginMouse.y) / root.logicalH
        var maxX = 1 - root.fracW
        var maxY = 1 - root.fracH
        var nx = Math.max(0, Math.min(rawX, maxX))
        var ny = Math.max(0, Math.min(rawY, maxY))

        // Magnetic snap: within 4% of display edges, snap with clean margin
        var marginX = 0.03
        var marginY = 0.04
        var snapDist = 0.04
        if (nx < marginX + snapDist) nx = marginX
        else if (nx > maxX - marginX - snapDist) nx = maxX - marginX

        if (ny < marginY + snapDist) ny = marginY
        else if (ny > maxY - marginY - snapDist) ny = maxY - marginY

        root.currentXFrac = nx
        root.currentYFrac = ny
        root.moveDirty = true
      }
      onReleased: root.commitMove()
      onCanceled: root.commitMove()
    }

    // ── HUD Controls Card (Pill + Corner Slider) ─────────────────────────────
    Item {
      id: hudCard
      anchors.top: parent.top
      anchors.topMargin: Style.space(4)
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(parent.width - Style.space(8), Style.space(240))
      height: hudColumn.height + Style.space(8)
      z: 20

      opacity: (root.controlsVisible || root.moving || root.resizing || root.sliderActive) ? 1.0 : 0.0
      visible: opacity > 0.01
      Behavior on opacity { NumberAnimation { duration: 160 } }

      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius > 0 ? Style.cornerRadius : 8
        color: Qt.alpha(Color.background, 0.94)
        border.width: Style.normalBorderWidth
        border.color: Style.normalBorderColor
      }

      Column {
        id: hudColumn
        anchors.centerIn: parent
        spacing: Style.space(3)
        width: parent.width - Style.space(6)

        // ── Row 1: Shapes (1:1, 16:9, Circle), Snap Corners, Flip, Close ───────
        Row {
          id: toolRow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(2)

          // 1:1 Square Button
          MouseArea {
            width: Style.space(24)
            height: Style.space(22)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setShape("1:1")

            Rectangle {
              anchors.fill: parent
              radius: 4
              color: root.shape === "1:1" ? Qt.alpha(Color.accent, 0.3)
                   : parent.containsMouse ? Qt.alpha(Color.accent, 0.12) : "transparent"
              border.width: root.shape === "1:1" ? 1 : 0
              border.color: Color.accent
            }
            Text {
              anchors.centerIn: parent
              text: "1:1"
              font.pixelSize: 10
              font.bold: true
              color: root.shape === "1:1" ? Color.urgent : Style.normalBorderColor
            }
          }

          // 16:9 Widescreen Button
          MouseArea {
            width: Style.space(28)
            height: Style.space(22)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setShape("16:9")

            Rectangle {
              anchors.fill: parent
              radius: 4
              color: root.shape === "16:9" ? Qt.alpha(Color.accent, 0.3)
                   : parent.containsMouse ? Qt.alpha(Color.accent, 0.12) : "transparent"
              border.width: root.shape === "16:9" ? 1 : 0
              border.color: Color.accent
            }
            Text {
              anchors.centerIn: parent
              text: "16:9"
              font.pixelSize: 10
              font.bold: true
              color: root.shape === "16:9" ? Color.urgent : Style.normalBorderColor
            }
          }

          // Circle Button
          MouseArea {
            width: Style.space(24)
            height: Style.space(22)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setShape("circle")

            Rectangle {
              anchors.fill: parent
              radius: 4
              color: root.shape === "circle" ? Qt.alpha(Color.accent, 0.3)
                   : parent.containsMouse ? Qt.alpha(Color.accent, 0.12) : "transparent"
              border.width: root.shape === "circle" ? 1 : 0
              border.color: Color.accent
            }
            Rectangle {
              anchors.centerIn: parent
              width: 11
              height: 11
              radius: 6
              color: "transparent"
              border.width: 2
              border.color: root.shape === "circle" ? Color.urgent : Style.normalBorderColor
            }
          }

          // Separator
          Rectangle {
            width: 1
            height: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            color: Style.normalBorderColor
          }

          // Snap: Top-Left
          MouseArea {
            width: Style.space(20)
            height: Style.space(22)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.snapCorner("top-left")

            Rectangle {
              anchors.fill: parent
              radius: 3
              color: parent.containsMouse ? Qt.alpha(Color.accent, 0.15) : "transparent"
            }
            Text {
              anchors.centerIn: parent
              text: "↖"
              color: parent.containsMouse ? Color.urgent : Style.normalBorderColor
              font.pixelSize: 11
              font.bold: true
            }
          }

          // Snap: Top-Right
          MouseArea {
            width: Style.space(20)
            height: Style.space(22)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.snapCorner("top-right")

            Rectangle {
              anchors.fill: parent
              radius: 3
              color: parent.containsMouse ? Qt.alpha(Color.accent, 0.15) : "transparent"
            }
            Text {
              anchors.centerIn: parent
              text: "↗"
              color: parent.containsMouse ? Color.urgent : Style.normalBorderColor
              font.pixelSize: 11
              font.bold: true
            }
          }

          // Snap: Bottom-Left
          MouseArea {
            width: Style.space(20)
            height: Style.space(22)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.snapCorner("bottom-left")

            Rectangle {
              anchors.fill: parent
              radius: 3
              color: parent.containsMouse ? Qt.alpha(Color.accent, 0.15) : "transparent"
            }
            Text {
              anchors.centerIn: parent
              text: "↙"
              color: parent.containsMouse ? Color.urgent : Style.normalBorderColor
              font.pixelSize: 11
              font.bold: true
            }
          }

          // Snap: Bottom-Right
          MouseArea {
            width: Style.space(20)
            height: Style.space(22)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.snapCorner("bottom-right")

            Rectangle {
              anchors.fill: parent
              radius: 3
              color: parent.containsMouse ? Qt.alpha(Color.accent, 0.15) : "transparent"
            }
            Text {
              anchors.centerIn: parent
              text: "↘"
              color: parent.containsMouse ? Color.urgent : Style.normalBorderColor
              font.pixelSize: 11
              font.bold: true
            }
          }

          // Separator
          Rectangle {
            width: 1
            height: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            color: Style.normalBorderColor
          }

          // Mirror / Flip Toggle
          MouseArea {
            width: Style.space(22)
            height: Style.space(22)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleFlip()

            Rectangle {
              anchors.fill: parent
              radius: 3
              color: root.flip ? Qt.alpha(Color.accent, 0.25)
                   : parent.containsMouse ? Qt.alpha(Color.accent, 0.12) : "transparent"
            }
            Text {
              anchors.centerIn: parent
              text: "⇄"
              color: root.flip ? Color.urgent : Style.normalBorderColor
              font.pixelSize: 12
              font.bold: true
            }
          }

          // Separator
          Rectangle {
            width: 1
            height: Style.space(14)
            anchors.verticalCenter: parent.verticalCenter
            color: Style.normalBorderColor
          }

          // Hide / Close Button
          MouseArea {
            width: Style.space(22)
            height: Style.space(22)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeBubble()

            Rectangle {
              anchors.fill: parent
              radius: 3
              color: parent.pressed ? Qt.alpha(Color.urgent, 0.3)
                   : parent.containsMouse ? Qt.alpha(Color.urgent, 0.15) : "transparent"
            }
            Text {
              anchors.centerIn: parent
              text: "×"
              color: Color.urgent
              font.pixelSize: 14
              font.bold: true
            }
          }
        }

        // ── Row 2: Corner Rounding Slider ─────────────────────────────────────
        Row {
          id: sliderRow
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(4)
          visible: root.shape !== "circle"

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "╭╮"
            font.pixelSize: 10
            color: Style.normalBorderColor
          }

          // Quick Preset: 0px Sharp
          MouseArea {
            width: Style.space(18)
            height: Style.space(18)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.radiusRatio = 0.0
              root.saveNow(true)
            }

            Rectangle {
              anchors.fill: parent
              radius: 2
              color: root.radiusRatio < 0.04 ? Qt.alpha(Color.accent, 0.3)
                   : parent.containsMouse ? Qt.alpha(Color.accent, 0.12) : "transparent"
              border.width: 1
              border.color: root.radiusRatio < 0.04 ? Color.accent : Style.normalBorderColor
            }
            Text {
              anchors.centerIn: parent
              text: "0"
              font.pixelSize: 9
              font.bold: true
              color: root.radiusRatio < 0.04 ? Color.urgent : Style.normalBorderColor
            }
          }

          // Slider Track
          Rectangle {
            id: sliderTrack
            width: Style.space(95)
            height: Style.space(6)
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Color.foreground, 0.18)

            // Active Track Fill
            Rectangle {
              width: Math.max(0, Math.min(sliderTrack.width, root.radiusRatio * sliderTrack.width))
              height: parent.height
              radius: parent.radius
              color: Color.accent
            }

            // Draggable Thumb Handle
            Rectangle {
              x: Math.max(0, Math.min(sliderTrack.width - width, root.radiusRatio * (sliderTrack.width - width)))
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(12)
              height: width
              radius: width / 2
              color: sliderMouse.containsMouse || sliderMouse.pressed ? Color.urgent : Color.accent
              border.width: 2
              border.color: "#ffffff"
            }

            MouseArea {
              id: sliderMouse
              anchors.fill: parent
              anchors.margins: -Style.space(6)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton

              function updateRatio(mouseX) {
                var localX = mouseX - Style.space(6)
                var ratio = Math.max(0.0, Math.min(1.0, localX / sliderTrack.width))
                root.radiusRatio = ratio
                root.saveNow(false)
              }

              onPressed: (mouse) => {
                root.sliderActive = true
                updateRatio(mouse.x)
              }
              onPositionChanged: (mouse) => {
                if (pressed) updateRatio(mouse.x)
              }
              onReleased: {
                root.sliderActive = false
                root.saveNow(true)
              }
              onCanceled: {
                root.sliderActive = false
                root.saveNow(true)
              }
            }
          }

          // Quick Preset: Max Round
          MouseArea {
            width: Style.space(26)
            height: Style.space(18)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.radiusRatio = 1.0
              root.saveNow(true)
            }

            Rectangle {
              anchors.fill: parent
              radius: 2
              color: root.radiusRatio > 0.95 ? Qt.alpha(Color.accent, 0.3)
                   : parent.containsMouse ? Qt.alpha(Color.accent, 0.12) : "transparent"
              border.width: 1
              border.color: root.radiusRatio > 0.95 ? Color.accent : Style.normalBorderColor
            }
            Text {
              anchors.centerIn: parent
              text: "Max"
              font.pixelSize: 8
              font.bold: true
              color: root.radiusRatio > 0.95 ? Color.urgent : Style.normalBorderColor
            }
          }

          // Radius Pixel Value Badge
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.effectiveRadius === 0 ? "Square" : (Math.round(root.effectiveRadius) + "px")
            font.pixelSize: 9
            font.bold: true
            color: Color.accent
          }
        }
      }
    }

    // ── Resize Grip (Bottom-right corner, preserves aspect ratio) ─────────────
    MouseArea {
      id: resizeArea
      width: Style.space(32)
      height: Style.space(32)
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      hoverEnabled: true
      cursorShape: Qt.SizeFDiagCursor
      acceptedButtons: Qt.LeftButton
      visible: root.controlsVisible || root.resizing
      z: 25

      onPressed: (mouse) => {
        var pt = resizeArea.mapToItem(null, mouse.x, mouse.y)
        root.resizeOriginMouse = Qt.point(pt.x, pt.y)
        root.resizeOriginSize = root.currentSizeFrac
        root.resizeDirty = false
      }
      onPositionChanged: (mouse) => {
        if (!pressed) return
        var pt = resizeArea.mapToItem(null, mouse.x, mouse.y)
        var delta = ((pt.x - root.resizeOriginMouse.x) + (pt.y - root.resizeOriginMouse.y)) / 2
        var ns = root.resizeOriginSize + delta / root.logicalW
        root.currentSizeFrac = Math.max(0.06, Math.min(0.70, ns))
        root.resizeDirty = true
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
    if (!root.moveDirty) return
    root.moveDirty = false
    saveNow(true)
  }

  function commitResize() {
    if (!root.resizeDirty) return
    root.resizeDirty = false
    saveNow(true)
  }
}

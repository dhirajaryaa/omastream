import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons

// omastream service — manages the camera bubble overlay across monitors.
//
// The omastream CLI is the single writer of ~/.local/state/omastream/state.json;
// this service watches it and instantiates CameraBubble (one per display via Variants).
// Live camera bubble is composited directly on the desktop display so gpu-screen-recorder
// captures it along with desktop windows.
Item {
  id: streamService

  readonly property string omastreamBin: (Quickshell.env("HOME") || "/home/user") + "/.local/bin/omastream-cli"
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string statePath: stateHome + "/omastream/state.json"
  readonly property string confPath: Quickshell.env("HOME") + "/.config/omastream/config.env"

  // Detect whether the omastream GUI app window is open
  readonly property bool appRunning: {
    if (!Hyprland.toplevels || !Hyprland.toplevels.values) return false
    var list = Hyprland.toplevels.values
    for (var i = 0; i < list.length; i++) {
      var item = list[i]
      if (!item) continue
      var appId = (item.wayland && item.wayland.appId) ? String(item.wayland.appId) : ""
      var clazz = item.clazz ? String(item.clazz) : ""
      var initClass = item.initialClass ? String(item.initialClass) : ""
      var ipcClass = (item.lastIpcObject && item.lastIpcObject.class) ? String(item.lastIpcObject.class) : ""
      var ipcInit = (item.lastIpcObject && item.lastIpcObject.initialClass) ? String(item.lastIpcObject.initialClass) : ""
      if (appId === "omastream" || clazz === "omastream" || initClass === "omastream" || ipcClass === "omastream" || ipcInit === "omastream") {
        return true
      }
    }
    return false
  }

  // On clean startup (e.g. PC/OS boot), ensure webcam overlay does NOT start automatically.
  // It only opens when triggered by omastream-app or user action.
  Component.onCompleted: {
    if (!streamService.streaming && !streamService.appRunning) {
      Quickshell.execDetached([streamService.omastreamBin, "cam", "off"])
    }
  }

  // ── runtime state snapshot (CLI is the writer) ─────────────────────────────
  property var state: ({})
  readonly property bool streaming: state.streaming === true
  readonly property var cam: state.cam || null
  readonly property bool camVisible: cam ? cam.visible === true : false
  readonly property string camShape: cam ? String(cam.shape || "16:9") : "16:9"
  readonly property real camRadius: cam && typeof cam.radius === "number" ? cam.radius : 0.20

  property var camConf: ({})

  FileView {
    id: stateFile
    path: streamService.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: streamService.loadState(text())
    onLoadFailed: streamService.loadState("")
  }

  FileView {
    id: confFile
    path: streamService.confPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: streamService.loadConfig(text())
    onLoadFailed: streamService.loadConfig("")
  }

  function loadState(raw) {
    var parsed = {}
    try {
      var obj = JSON.parse(String(raw || "{}"))
      if (obj && typeof obj === "object") parsed = obj
    } catch (e) {
      parsed = {}
    }
    streamService.state = parsed
  }

  function loadConfig(raw) {
    var c = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var eq = lines[i].indexOf("=")
      if (eq < 1) continue
      var key = lines[i].slice(0, eq).trim()
      var val = lines[i].slice(eq + 1).split("#")[0].trim()
      c[key] = val
    }
    streamService.camConf = {
      record: String(c.CAM_RECORD || "true") !== "false",
      flip: String(c.CAM_FLIP || "true") !== "false"
    }
  }

  function reloadState() {
    stateFile.reload()
    confFile.reload()
  }

  Timer {
    interval: streamService.streaming ? 300 : 800
    running: true
    repeat: true
    onTriggered: {
      streamService.reloadState()
      // If neither streaming nor the app is open, force cam off so it never lingers on the desktop
      if (streamService.camVisible && !streamService.streaming && !streamService.appRunning) {
        Quickshell.execDetached([streamService.omastreamBin, "cam", "off"])
      }
    }
  }

  ShellIpc {
    target: "omastream"
    function ping(): string {
      return "pong"
    }
    function status(): string {
      return JSON.stringify({
        camVisible: streamService.camVisible,
        streaming: streamService.streaming,
        shape: streamService.camShape,
        radius: streamService.camRadius
      })
    }
    function toggleCam(): string {
      Quickshell.execDetached([streamService.omastreamBin, "cam", "toggle"])
      return "ok"
    }
    function snapCorner(corner: string): string {
      Quickshell.execDetached([streamService.omastreamBin, "cam", "corner", corner])
      return "ok"
    }
    function setShape(shape: string): string {
      Quickshell.execDetached([streamService.omastreamBin, "cam", "shape", shape])
      return "ok"
    }
    function setRadius(radius: string): string {
      Quickshell.execDetached([streamService.omastreamBin, "cam", "radius", radius])
      return "ok"
    }
  }

  // ── one camera bubble per display ─────────────────────────────────────────
  Variants {
    model: Quickshell.screens

    delegate: Component {
      CameraBubble {
        required property var modelData
        screen: modelData
        service: streamService
      }
    }
  }
}

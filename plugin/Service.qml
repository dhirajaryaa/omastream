import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// omastream service — owns nothing but mirrors everything.
//
// The omastream CLI is the single writer of ~/.local/state/omastream/state.json;
// this service watches it and re-publishes the snapshot to the camera bubble
// (one per display via Variants). It also tells the omareel capture-exclude
// plugin to hide the "omastream-" layer namespace from capture while a camera
// is shown, so the stream shows gpu-screen-recorder's raw composited camera
// instead of two cameras at once (ours + the one gsr draws in-stream).
Item {
  id: service

  // Hosts inject their environment via these paths; keep them stable.
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string statePath: stateHome + "/omastream/state.json"
  readonly property string confPath: Quickshell.env("HOME") + "/.config/omastream/config.env"

  // ── runtime state snapshot (CLI is the writer) ─────────────────────────────
  property var state: ({})
  readonly property bool streaming: state.streaming === true
  readonly property var cam: state.cam || null
  readonly property bool camVisible: cam ? cam.visible === true : false
  readonly property string camShape: cam ? String(cam.shape || "16:9") : "16:9"

  // config.env defaults for the bits QML needs that state.json doesn't carry.
  property var camConf: ({})
  // gpu-screen-recorder composites the camera into the stream while shown
  // (CAM_RECORD), which locks the v4l2 device — the bubble then yields the
  // device and shows its LIVE placeholder until the stream ends.
  readonly property bool gsrOwnsCamera: streaming && (camConf.record !== false)

  FileView {
    id: stateFile
    path: service.statePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: service.loadState(text())
    onLoadFailed: service.loadState("")
  }

  FileView {
    id: confFile
    path: service.confPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: service.loadConfig(text())
    onLoadFailed: service.loadConfig("")
  }

  function loadState(raw) {
    var parsed = {}
    try {
      var obj = JSON.parse(String(raw || "{}"))
      if (obj && typeof obj === "object") parsed = obj
    } catch (e) {
      parsed = {}
    }
    service.state = parsed
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
    service.camConf = {
      record: String(c.CAM_RECORD || "true") !== "false",
      flip: String(c.CAM_FLIP || "true") !== "false"
    }
  }

  function reloadState() {
    stateFile.reload()
    confFile.reload()
  }

  // inotify can miss the CLI's atomic rename; a heartbeat closes the gap.
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      service.reloadState()
    }
  }

  // ── capture exclusion (omareel-exclude bridge) ─────────────────────────────
  property string excludePrefix: "omastream-"
  property bool excludeSupported: false
  property string excludeStateReq: "" // "add" | "remove" last requested

  Process {
    id: excludeProc
    property string mode: "" // "probe" | "add" | "remove"

    function run(args, kind) {
      mode = kind
      command = ["hyprctl"].concat(args)
      running = true
    }

    onExited: (code) => {
      if (mode === "probe") {
        service.excludeSupported = code === 0
        if (service.excludeSupported) service.syncExclusion()
      }
    }
  }

  function runExclude(kind, args) {
    if (!excludeSupported) return
    run(args, kind)
  }

  Component.onCompleted: excludeProc.run(["omareel-exclude", "status"], "probe")
  Component.onDestruction: {
    if (excludeSupported) excludeProc.run(["omareel-exclude", "remove", excludePrefix], "remove")
  }

  function syncExclusion() {
    if (!excludeSupported) return
    var active = service.streaming || (service.camVisible && service.gsrOwnsCamera)
    var want = active ? "add" : "remove"
    if (excludeStateReq === want) return
    excludeStateReq = want
    excludeProc.run(["omareel-exclude", want, excludePrefix], want)
  }

  onStreamingChanged: Qt.callLater(service.syncExclusion)
  onCamVisibleChanged: Qt.callLater(service.syncExclusion)
  onGsrOwnsCameraChanged: Qt.callLater(service.syncExclusion)

  // ── one camera bubble per display ─────────────────────────────────────────
  Variants {
    model: Quickshell.screens

    CameraBubble {
      required property var modelData
      screen: modelData
      service: service
    }
  }
}

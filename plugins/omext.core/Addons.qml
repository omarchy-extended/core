import QtQuick
import Quickshell
import Quickshell.Io

// Which omext addons are here, and on (omext core): asked the same way by
// every addon that behaves differently beside another one.
// Loaded by path: Loader { source: "file://" + <plugins>/omext.core/Addons.qml }.
Item {
  id: addons
  visible: false

  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")

  property var enabled: ({})   // plugin id -> on, as `omarchy plugin list` has it (Omarchy's own too)
  property bool ready: false   // asked once
  // Start has a switch of its own (its bar button and keys off, the plugin still loaded).
  property bool startOff: false

  // "start", "taskbar", "bell", "docks", ...: installed, and on.
  function installed(name) { return addons.enabled["omext." + name] !== undefined }
  function on(name) { return addons.enabled["omext." + name] === true && !(name === "start" && addons.startOff) }
  // Any plugin, by its full id ("omarchy.dock").
  function pluginOn(id) { return addons.enabled[id] === true }

  function refresh() { if (!lister.running) lister.running = true; startOffView.reload() }

  Process {
    id: lister
    running: true
    command: ["bash", "-c", "omarchy plugin list --json 2>/dev/null"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var next = ({})
        try { for (var p of JSON.parse(text)) if (p && p.id) next[p.id] = p.enabled === true } catch (e) { return }
        if (JSON.stringify(next) !== JSON.stringify(addons.enabled)) addons.enabled = next
        addons.ready = true
      }
    }
  }
  FileView {   // a plugin turned on or off
    path: addons.configHome + "/omarchy/shell.json"
    watchChanges: true
    printErrors: false
    onFileChanged: soon.restart()
  }
  FileView {
    id: startOffView
    path: addons.stateHome + "/omext/start/disabled"
    printErrors: false
    onLoaded: addons.startOff = true
    onLoadFailed: addons.startOff = false
  }
  Timer { id: soon; interval: 400; onTriggered: addons.refresh() }
  // (An install, or Start's switch: neither is in a file that's watched.)
  Timer { interval: 5000; running: true; repeat: true; onTriggered: addons.refresh() }
}

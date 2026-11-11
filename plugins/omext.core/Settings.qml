import QtQuick
import Quickshell
import Quickshell.Io

// An omext addon's settings (omext core): ~/.config/omext/<name>.json, read,
// watched (another screen's instance, or a hand edit, shows at once) and
// written in turn (a change is never overtaken by an older one).
// Loaded by path: Loader { source: ...; onLoaded: item.name = "taskbar" }, or
// setSource(url, { name: "taskbar" }).
Item {
  id: settings
  visible: false

  property string name: ""
  readonly property string path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/omext/" + name + ".json"
  property var values: ({})
  property bool ready: false   // read once (or found missing)

  // Changes some of them. `after`: a shell command to run once they're
  // written (a `hyprctl reload`, say).
  function set(patch, after) {
    values = Object.assign({}, values, patch)
    if (after) writer.after.push(String(after))
    writer.dirty = true
    writer.go()
  }

  FileView {
    path: settings.name ? settings.path : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      if (writer.running || writer.dirty) return   // ours is on its way: it wins
      try { var v = JSON.parse(text()); settings.values = v && typeof v === "object" && !Array.isArray(v) ? v : {} } catch (e) { settings.values = {} }
      settings.ready = true
    }
    onLoadFailed: { if (!writer.running && !writer.dirty) settings.values = {}; settings.ready = true }
  }

  Process {
    id: writer
    property bool dirty: false
    property var after: []
    function go() {
      if (running || !dirty || !settings.name) return
      dirty = false
      var then = after.join("; ")
      after = []
      // (To a link's file, not over the link: a settings file may be a link to
      // one kept elsewhere. Whole, or not at all.)
      command = ["bash", "-c", 'f=$(readlink -f "$0" 2>/dev/null) || f=$0; mkdir -p "$(dirname "$f")" && printf "%s\\n" "$1" > "$f.tmp" && mv "$f.tmp" "$f" && { [ -z "$2" ] || eval "$2"; }',
                 settings.path, JSON.stringify(settings.values, null, 2), then]
      running = true
    }
    onExited: go()
  }
}

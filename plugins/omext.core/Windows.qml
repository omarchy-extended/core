import QtQuick
import Quickshell
import Quickshell.Hyprland

// Going to a window, and the like (omext core): the same from the taskbar, from
// Start, from anywhere. Windows are as `hyprctl clients -j` gives them.
// Loaded by path: Loader { source: "file://" + <plugins>/omext.core/Windows.qml }.
QtObject {
  id: windows

  readonly property string dockTool: Quickshell.env("HOME") + "/.local/bin/omext-dock"

  // An omext dock opens on one of its windows: by its plugin, as resting on
  // its edge does (it slides out empty under a cover, then shows the app), and
  // the pointer goes onto the app, or the dock would close again at once.
  readonly property string dockGo: [
    '"$0" expand "$1" "$2" on',
    'omarchy-shell -q omext.docks open "$1"',
    'for i in $(seq 60); do',
    // The window, once it's out: on the screen's workspace (pinned), or its dock's shown.
    '  at=$(jq -rn --arg a "$3" --argjson c "$(hyprctl clients -j)" --argjson m "$(hyprctl monitors -j)"'
      + ' \'[$m[].specialWorkspace.name] as $up | $c[] | select(.address == $a and (.workspace.id > 0 or (.workspace.name | IN($up[]))))'
      + ' | "\\(.at[0] + (.size[0] / 2 | floor)) \\(.at[1] + (.size[1] / 2 | floor))"\')',
    '  [ -n "$at" ] && break; sleep 0.05',
    'done',
    '[ -n "$at" ] && hyprctl dispatch "hl.dsp.cursor.move({ x = ${at% *}, y = ${at#* } })" >/dev/null'
  ].join("\n")

  // A floating window back from being minimized is put wholly on its screen:
  // it keeps the size and place it had, and those may be another screen's (the
  // big one it was on is unplugged, or it comes back on the laptop's). No
  // larger than the room the bars leave, and no part of it outside that.
  readonly property string fitBack: [
    'import json, subprocess, sys, time',
    'addr = sys.argv[1]',
    'def hypr(what): return json.loads(subprocess.run(["hyprctl", what, "-j"], capture_output=True, text=True).stdout or "[]")',
    'def dsp(text): subprocess.run(["hyprctl", "dispatch", text], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)',
    'for _ in range(20):',
    '    c = next((c for c in hypr("clients") if c["address"] == addr), None)',
    '    if c and c["workspace"]["id"] > 0: break',
    '    time.sleep(0.05)',
    'else: sys.exit()',
    'if not c["floating"] or c.get("fullscreen"): sys.exit()',
    'm = next((m for m in hypr("monitors") if m["id"] == c["monitor"]), None)',
    'if not m: sys.exit()',
    'turned = m.get("transform", 0) % 2',
    'mw, mh = (m["height"], m["width"]) if turned else (m["width"], m["height"])',
    'r = m.get("reserved", [0, 0, 0, 0])',
    'gap = 2',
    'x0, y0 = m["x"] + r[0] + gap, m["y"] + r[1] + gap',
    'rw, rh = round(mw / m["scale"]) - r[0] - r[2] - 2 * gap, round(mh / m["scale"]) - r[1] - r[3] - 2 * gap',
    '(x, y), (w, h) = c["at"], c["size"]',
    'nw, nh = min(w, rw), min(h, rh)',
    'nx, ny = max(x0, min(x, x0 + rw - nw)), max(y0, min(y, y0 + rh - nh))',
    'if (nw, nh) != (w, h): dsp("hl.dsp.window.resize({ x = %d, y = %d, relative = false, window = \'address:%s\' })" % (nw, nh, addr))',
    'if (nx, ny) != (x, y): dsp("hl.dsp.window.move({ x = %d, y = %d, relative = false, window = \'address:%s\' })" % (nx, ny, addr))'
  ].join("\n")

  // Goes to a window: focused, on top. `docked`: {dock, app} when it's in an
  // omext dock (the dock opens on it). A minimized one (Omarchy's) comes back
  // onto the workspace `monitor` shows (the focused one's by default) first:
  // focusing it where it is would show the whole minimized workspace.
  function goTo(c, docked, monitor) {
    if (!c || !c.address) return
    if (docked) {
      Quickshell.execDetached(["bash", "-c", windows.dockGo, windows.dockTool, docked.dock, docked.app, c.address])
      return
    }
    var target = "window = 'address:" + c.address + "'"
    if (c.workspace && c.workspace.name === "special:minimized") {
      var m = monitor || Hyprland.focusedMonitor
      var ws = m && m.activeWorkspace ? m.activeWorkspace.id : -1
      if (!(ws >= 1)) return
      Hyprland.dispatch("hl.dsp.window.move({ workspace = '" + ws + "', " + target + " })")
      Quickshell.execDetached(["python3", "-c", windows.fitBack, String(c.address)])
    }
    Hyprland.dispatch("hl.dsp.focus({ " + target + " })")
    Hyprland.dispatch("hl.dsp.window.alter_zorder({ mode = 'top', " + target + " })")
  }

  function close(c) {
    if (c && c.address) Hyprland.dispatch("hl.dsp.window.close({ window = 'address:" + c.address + "' })")
  }

  // Omarchy's minimize (onto its minimized workspace, to come back from).
  function minimize(c) {
    if (c && c.address) Quickshell.execDetached(["omarchy-hyprland-window-minimize", c.address])
  }

  // Onto a workspace, staying where the focus is.
  function moveTo(c, workspaceId) {
    if (c && c.address && workspaceId >= 1)
      Hyprland.dispatch("hl.dsp.window.move({ workspace = '" + workspaceId + "', window = 'address:" + c.address + "', follow = false })")
  }
}

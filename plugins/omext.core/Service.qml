import QtQuick
import Quickshell
import Quickshell.Io

// omext core (omarchy-extended): what the omext addons share. The addons load
// its files by path (Apps.qml, Windows.qml, Settings.qml, Addons.qml); this
// service does what only one place should.
//
// The choices that cross addons are in ~/.config/omext/omext.json:
//   omarchyDockOff   true: Omarchy's dock off while Start is on (its keys open
//                    Start's apps): Start's Settings, or Setup › Omarchy Extended
//   startOnTaskbar   true: Start's button is on omext taskbar, not on the bar
//   hideBell         true: omext bell's button is off the bar while Start shows
//                    the notifications (notificationsInStart, which Start keeps)
//   barPosition      "top", "bottom", "left" or "right": Omarchy's bar is kept
//                    at that edge (a drag that takes it elsewhere is undone)
//
// Omarchy's dock is turned off and on here, and only here: off while omext
// taskbar is on (it's in the dock's place) or Start is on with omarchyDockOff.
// What was turned off here is remembered (~/.local/state/omext/core/
// omarchy-dock-off), and turned back on when nothing asks for it off any more.
Item {
  id: root
  property var shell: null
  property var manifest: null

  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")

  Addons { id: addons }
  Settings { id: shared; name: "omext" }

  // From before the core: Start's and the taskbar's own marks for the dock,
  // and the two of these choices that were in Start's settings.
  property bool migrated: false
  Process {
    running: true
    command: ["bash", "-c", [
      's=$0/omext; cfg=$1/omext/omext.json; old=$1/omext/start.json',
      'mkdir -p "$s/core" "$1/omext"',
      '[ -s "$cfg" ] || echo "{}" > "$cfg"',
      'if [ -e "$s/start/omarchy-dock-off" ] || [ -e "$s/taskbar/omarchy-dock-off" ]; then touch "$s/core/omarchy-dock-off"; moved=1; fi',
      'if [ -e "$s/start/omarchy-dock-off" ]; then jq ".omarchyDockOff = true" "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"; fi',
      'rm -f "$s/start/omarchy-dock-off" "$s/taskbar/omarchy-dock-off"',
      // (Start's keys follow the dock's mark: read again where it is now.)
      '[ -z "${moved:-}" ] || hyprctl reload >/dev/null 2>&1',
      'if [ -s "$old" ] && ! jq -e "has(\\"fromStart\\")" "$cfg" >/dev/null; then',
      '  jq -s ".[0] + {startOnTaskbar: (.[1].taskbar == true), hideBell: (.[1].hideBell == true), fromStart: true}" "$cfg" "$old" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"',
      'fi'
    ].join("\n"), root.stateHome, root.configHome]
    onExited: { root.migrated = true; decideSoon.restart() }
  }

  readonly property bool wantDockOff: addons.on("taskbar") || (addons.on("start") && shared.values.omarchyDockOff === true)
  onWantDockOffChanged: decideSoon.restart()
  Connections {
    target: addons
    function onEnabledChanged() { decideSoon.restart() }
    function onReadyChanged() { decideSoon.restart() }
  }
  Connections {
    target: shared
    function onReadyChanged() { decideSoon.restart() }
  }
  Timer {
    id: decideSoon
    interval: 1200
    onTriggered: {
      if (!root.migrated || !addons.ready || !shared.ready || decide.running) { if (decide.running) restart(); return }
      decide.command = ["bash", "-c", [
        'rec=$0/omext/core/omarchy-dock-off',
        'on() { omarchy plugin list --json 2>/dev/null | jq -e \'.[] | select(.id == "omarchy.dock") | .enabled\' >/dev/null; }',
        'if [ "$1" = off ]; then',
        '  if on; then mkdir -p "${rec%/*}" && touch "$rec"; omarchy plugin disable omarchy.dock >/dev/null; hyprctl reload >/dev/null 2>&1; fi',
        'elif [ -e "$rec" ]; then',
        '  rm -f "$rec"; on || omarchy plugin enable omarchy.dock >/dev/null; hyprctl reload >/dev/null 2>&1',
        'fi',
        'exit 0'
      ].join("\n"), root.stateHome, root.wantDockOff ? "off" : "on"]
      decide.running = true
    }
  }
  Process { id: decide }

  // barPosition: the bar stays at that edge. Omarchy's bar goes to another
  // edge when an empty part of it is dragged there (or held and moved), easily
  // done by accident, and has no lock of its own; so whenever its position in
  // shell.json is another, it's put back. Unset, the bar goes where it's taken.
  // The watching is done outside the shell (inotifywait, which Omarchy has):
  // right after a drag the shell is busy laying the bar out at its new edge,
  // and anything waiting in it waits seconds. (A plugin like this one gets no
  // live bar config from the shell either: the file it is.)
  readonly property string barPosition: ["top", "bottom", "left", "right"].indexOf(shared.values.barPosition) >= 0 ? shared.values.barPosition : ""
  // (Started over when the edge asked for changes; the start a moment after
  // the stop, or it doesn't happen.)
  onBarPositionChanged: { barWatch.running = false; Qt.callLater(function() { barWatch.running = root.barPosition !== "" }) }
  Component.onCompleted: barWatch.running = barPosition !== ""
  Process {
    id: barWatch
    command: ["bash", "-c", [
      'dir=$1/omarchy; want=$0',
      'check() { at=$(jq -r ".bar.position // \\"top\\"" "$dir/shell.json" 2>/dev/null) || return; [ -n "$at" ] && [ "$at" != "$want" ] && omarchy bar position "$want" >/dev/null 2>&1; }',
      // One save at a time, and a look every 2 s besides (a save between two
      // waits is caught then); an inotifywait left behind when this is stopped
      // is gone within 2 s too.
      'while true; do',
      '  check',
      '  if command -v inotifywait >/dev/null; then inotifywait -q -t 2 -e close_write,moved_to "$dir" >/dev/null 2>&1; else sleep 0.3; fi',
      'done'
    ].join("\n"), root.barPosition, root.configHome]
  }
}

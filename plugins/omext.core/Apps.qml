import QtQuick
import Quickshell

// Which app a window is (omext core). One rule for every omext addon, so a
// window is the same app on the taskbar, in Start and in a dock. Loaded by
// path: Loader { source: "file://" + <plugins>/omext.core/Apps.qml }.
//
// Never a guess that would file one app's window under another: a web app's
// window is that web app (the entry whose StartupWMClass says so), not the
// browser it runs in; an app run in a terminal under a class of its own is the
// one entry started that way.
QtObject {
  id: apps

  readonly property var all: DesktopEntries.applications ? DesktopEntries.applications.values : []

  // The desktop entry for a window class, or null.
  function ofClass(cls) {
    cls = String(cls || "")
    if (!cls) return null
    var list = apps.all
    for (var a of list) if (a.startupClass && a.startupClass === cls) return a
    for (var b of list) if (b.id === cls) return b
    // Run in a terminal under a class of its own (`xdg-terminal-exec
    // --app-id=TUI.tile -e ...`): the one entry started that way.
    var flag = "--app-id=" + cls
    var termed = list.filter(t => (t.command || []).some(w => String(w) === flag) || String(t.execString || "").indexOf(flag + " ") >= 0)
    if (termed.length === 1) return termed[0]
    if (termed.length > 1 || /^TUI\./.test(cls)) return null   // several share it (or none says so)
    // A web app with no entry of its own: not its browser.
    if (/^(msedge|chrome|chromium|brave|vivaldi)-.+-[^-]+$/.test(cls)) return null
    var e = DesktopEntries.heuristicLookup(cls)
    if (e) return e
    // "org.localsend.localsend_app": by its last part.
    var last = cls.split(".").pop().replace(/[-_]app$/i, "")
    return last && last !== cls ? DesktopEntries.heuristicLookup(last) : null
  }

  // ... for a window as `hyprctl clients -j` gives it ({class, initialClass}).
  function ofWindow(c) {
    return c ? ofClass(c["class"]) || ofClass(c.initialClass) : null
  }

  // An icon name or path, as something an Image can show.
  function iconSource(icon) {
    var fallback = Quickshell.iconPath("application-x-executable", true)
    if (!icon) return fallback
    if (String(icon).charAt(0) === "/") return "file://" + icon
    return Quickshell.iconPath(icon, true) || fallback
  }
  function iconOfWindow(c) { var e = ofWindow(c); return iconSource(e ? e.icon : "") }
  function nameOfWindow(c) { var e = ofWindow(c); return e ? e.name : String(c && c["class"] || "") }
}

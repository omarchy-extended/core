import QtQuick
import Quickshell
import Quickshell.Io

// Which app a window is (omext core). One rule for every omext addon, so a
// window is the same app on the taskbar, in Start and in a dock. Loaded by
// path: Loader { source: "file://" + <plugins>/omext.core/Apps.qml }.
//
// Never a guess that would file one app's window under another: a web app's
// window is that web app (the entry whose StartupWMClass says so), not the
// browser it runs in; an app run in a terminal under a class of its own is the
// one entry started that way.
Item {
  id: apps
  visible: false

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

  // A browser profile's own icon: the browser's with the profile's picture in
  // its corner, as Windows shows them. Every Edge profile's windows share one
  // class on Wayland, but the profile's name ends the title ("Page - Sinfra -
  // Microsoft Edge"); omext-profile-icons draws the icons and maps names to them.
  property var profileIcons: ({})   // class -> {profile name: png}
  readonly property string profileMapPath: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/omext/profile-icons/map.json"
  property var profilesAsked: ({})  // names we've already run the drawer for
  FileView {
    path: apps.profileMapPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { apps.profileIcons = JSON.parse(text()) } catch (e) { apps.profileIcons = {} } }
  }
  Process { id: profileDrawer; command: ["omext-profile-icons"]; running: true }
  function profileOf(c) {
    var parts = String(c && c.title || "").split(" - ")
    if (parts.length < 3 || parts[parts.length - 1].replace(/\u200b/g, "") !== "Microsoft Edge") return ""
    return parts[parts.length - 2]
  }
  function profileIconOf(c) {
    var cls = String(c && c["class"] || "")
    if (cls !== "microsoft-edge") return ""
    var name = apps.profileOf(c)
    if (!name) return ""
    var icon = (apps.profileIcons[cls] || {})[name]
    if (icon) return icon
    // A profile the map lacks (new, or renamed): draw again, once per name.
    if (!apps.profilesAsked[name] && !profileDrawer.running) {
      apps.profilesAsked[name] = true
      profileDrawer.running = true
    }
    return ""
  }

  // An icon name or path, as something an Image can show.
  function iconSource(icon) {
    var fallback = Quickshell.iconPath("application-x-executable", true)
    if (!icon) return fallback
    if (String(icon).charAt(0) === "/") return "file://" + icon
    return Quickshell.iconPath(icon, true) || fallback
  }
  function iconOfWindow(c) { var p = profileIconOf(c); if (p) return iconSource(p); var e = ofWindow(c); return iconSource(e ? e.icon : "") }
  function nameOfWindow(c) { var e = ofWindow(c); return e ? e.name : String(c && c["class"] || "") }
}

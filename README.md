# omext core

Part of [**omarchy-extended**](https://github.com/omarchy-extended): addons for [Omarchy](https://omarchy.org).

What the omext addons share, in one place, so they agree with each other. It
has nothing to look at: the other addons install it when it's missing, and use
it.

## What's in it

| File | What it does |
|------|--------------|
| `Apps.qml` | Which app a window is. A web app's window is that web app (the entry whose `StartupWMClass` says so), never the browser it runs in; an app run in a terminal under a class of its own is the one entry started that way. No guess that would file one app's window under another. |
| `Windows.qml` | Going to a window (one in an [omext dock](https://github.com/omarchy-extended/docks): the dock opens on it; a minimized one comes back first), closing it, minimizing it, moving it to a workspace. |
| `Settings.qml` | An addon's settings file, `~/.config/omext/<name>.json`: read, watched, and written in turn. |
| `Addons.qml` | Which omext addons are installed, and on: asked the same way by every addon that behaves differently beside another. |
| `omext_settings.py` | The same settings handling for the addons' command-line tools (`omext-dock`, `omext-zone`, `omext-layout`): `settings.read("docks", {})`, `settings.write("docks", data)`. |
| `hypr/escape.lua` | Escape closes what the omext addons have up over the windows: an open dock, the taskbar and its lists, a menu, the zone map. One Hyprland bind that takes nothing from the app in front; each addon hears it through a global shortcut of its own. |
| `omext-startup` | What starts at login, in one list: your own entries (`~/.config/autostart`), the system's (`/etc/xdg/autostart`, turned off by a file of your own that hides it) and the [omext docks](https://github.com/omarchy-extended/docks)' apps that start with their dock. `omext-startup list`, `set <id> on\|off`, `add <app>`, `remove <id>`; [omext start](https://github.com/omarchy-extended/start)'s settings show it. What `~/.config/hypr/autostart.lua` starts is not in it. |
| `omext-defaults` | Which app opens what: the default app per kind of thing (web browser, mail, files, terminal, text, PDF, pictures, video, music, documents, spreadsheets, archives) and per file type. `omext-defaults list`, `type <.ext\|mime>`, `set <kind\|.ext\|mime> <app>`. Kept where every app looks, in `~/.config/mimeapps.list`; the browser is set the way Omarchy sets it, the terminal is `xdg-terminal-exec`'s. [omext start](https://github.com/omarchy-extended/start)'s settings show it. |

## Every addon's settings, one way

Each addon keeps its own settings, in its own file in `~/.config/omext/`, and
all of them are read and written by the core: `Settings.qml` in the shell
plugins, `omext_settings.py` in the tools, `omext-settings` from a script. A
write is whole or not at all, and goes to a link's file, not over the link (a
settings file may be a link to one kept elsewhere, in git say).

| File | Whose |
|------|-------|
| `omext.json` | The choices that cross addons (below) |
| `start.json` | omext start |
| `taskbar.json` | omext taskbar |
| `bell.json` | omext bell |
| `workspaces.json` | omext workspaces |
| `docks.json` | omext docks |
| `zones.json`, `zone-sets.json`, `zone-hidden.json` | omext arrange's zones |
| `layouts/<name>.json` | omext arrange's layouts |

```bash
omext-settings list                               # the files there are
omext-settings get taskbar                        # one, whole
omext-settings toggle taskbar gatherOnUnplug      # one key: true <-> false
omext-settings set start size '"large"'           # one key, as JSON
```

## The choices that cross addons

They're in one file, `~/.config/omext/omext.json`, so no two addons each keep
their own idea of them:

| Key | What it says |
|-----|--------------|
| `omarchyDockOff` | Omarchy's dock off while Start is on (its keys open Start's apps). Set in Start's Settings, or Setup › Omarchy Extended. |
| `startOnTaskbar` | Start's button is on omext taskbar, not on the bar. |
| `hideBell` | omext bell's button is off the bar while Start shows the notifications. |

**Omarchy's dock is turned off and on in one place: here.** It's off while
omext taskbar is on (the taskbar is in its place) or Start is on with
`omarchyDockOff`. What the core turned off, it turns back on once nothing asks
for it off any more (an addon turned off or removed, the choice unset).

They're in `plugins/omext.core/`, and an addon loads one by its path:

```qml
Loader {
  id: apps
  source: "file://" + Quickshell.env("HOME") + "/.config/omarchy/plugins/omext.core/Apps.qml"
}
// apps.item.ofWindow(client), apps.item.iconOfWindow(client), ...
```

## Install

```bash
git clone https://github.com/omarchy-extended/core.git ~/.local/share/omext-core
~/.local/share/omext-core/install.sh
```

A `git pull` in that folder updates it. `./uninstall.sh` removes it (once no
other omext addon is installed).

Needs **Omarchy 4.5** or later.

## License

MIT. See [LICENSE](LICENSE).

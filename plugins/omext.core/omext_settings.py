"""The omext addons' settings files (omext core), for their command-line tools.

Every omext addon keeps its settings in ~/.config/omext/: one JSON file each
(docks.json, zones.json, start.json, ...), or a folder of them (layouts/). This
is the one way they're read and written, so every tool does it alike:

    import omext_settings as settings
    data = settings.read("docks", {})        # by name, or a Path
    settings.write("docks", data)

A write is whole or not at all (a temporary file beside the real one, moved
over it), and goes to a link's file, not over the link: a settings file may be
a link to one kept elsewhere (in git, say).

The shell plugins use Settings.qml, beside this file, the same way.
"""

import json
import os
from pathlib import Path


def config_dir():
    """~/.config/omext (XDG_CONFIG_HOME's)."""
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "omext"


def path(name):
    """A settings file by name ("docks", "layouts/work"), or a Path as it is."""
    if isinstance(name, Path):
        return name
    name = str(name)
    if "/" in name and name.startswith(("/", "~", ".")):
        return Path(name).expanduser()
    return config_dir() / (name if name.endswith(".json") else name + ".json")


def read(name, default=None):
    """What's in it; `default` ({} if left out) when it's missing or not JSON."""
    try:
        return json.loads(path(name).read_text())
    except (OSError, ValueError):
        return {} if default is None else default


def write(name, data, sort_keys=False):
    """Writes it whole: beside the real file (a link's file), then moved over it."""
    real = path(name)
    real = real.resolve() if real.is_symlink() or real.exists() else real.parent.resolve() / real.name
    real.parent.mkdir(parents=True, exist_ok=True)
    tmp = real.with_name(f".{real.name}.{os.getpid()}.tmp")
    try:
        tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False, sort_keys=sort_keys) + "\n")
        tmp.replace(real)
    finally:
        tmp.unlink(missing_ok=True)
    return real


def update(name, patch):
    """Changes some keys of a file that holds an object; returns it all."""
    data = read(name, {})
    if not isinstance(data, dict):
        data = {}
    data.update(patch)
    write(name, data)
    return data


def names():
    """The settings files there are: ["bell", "docks", "layouts/work", ...]."""
    base = config_dir()
    if not base.is_dir():
        return []
    found = []
    for folder, _, files in os.walk(base, followlinks=True):  # (layouts/ may be a link to a folder kept elsewhere)
        for f in files:
            if f.endswith(".json") and not f.startswith("."):
                found.append(str((Path(folder) / f).relative_to(base))[:-5])
    return sorted(found)

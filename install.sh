#!/bin/bash
# Installs omext core (omarchy-extended) on Omarchy, from this folder: a link,
# so a git pull here updates it. Safe to run again. To undo: ./uninstall.sh
# The other omext addons install it themselves when it's missing.
set -euo pipefail

dir=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
plugins=$HOME/.config/omarchy/plugins

die() { echo "install: $*" >&2; exit 1; }
info() { echo "install: $*"; }

for cmd in jq omarchy omarchy-shell; do
  command -v "$cmd" >/dev/null || die "needs $cmd (Omarchy)"
done
[[ -e $HOME/.local/share/omarchy-addons/enabled/core ]] && die "core is already deployed by omx here"
[[ -d ${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins ]] || die "needs Omarchy 4.5 or later (its shell plugins)"

target=$plugins/omext.core
if [[ -e $target && ! -L $target ]]; then die "$target is there already (not a link); move it away first"; fi
mkdir -p "$plugins"
ln -sfn "$dir/plugins/omext.core" "$target"

# Its command (omext-settings: the addons' settings, from a script or a menu entry).
mkdir -p "$HOME/.local/bin"
ln -sfn "$dir/bin/omext-settings" "$HOME/.local/bin/omext-settings"
# ... and omext-startup: what starts at login, in one list (omext start's settings show it).
ln -sfn "$dir/bin/omext-startup" "$HOME/.local/bin/omext-startup"
# ... and omext-defaults: which app opens what (the same settings show it).
ln -sfn "$dir/bin/omext-defaults" "$HOME/.local/bin/omext-defaults"

# Hyprland: Escape closes what the omext addons have up (hypr/escape.lua),
# loaded at every (re)load.
hypr_conf=$HOME/.config/hypr/hyprland.lua
if [[ -f $hypr_conf ]]; then
  sed -i "/^-- BEGIN omext-core\$/,/^-- END omext-core\$/d" "$hypr_conf"
  {
    echo "-- BEGIN omext-core"
    echo "pcall(dofile, \"$dir/hypr/escape.lua\")"
    echo "-- END omext-core"
  } >> "$hypr_conf"
  hyprctl reload >/dev/null 2>&1 || true
fi

omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
sleep 1  # the rescan finishes in the background
grep -q '"omext.core"' "$HOME/.config/omarchy/shell.json" 2>/dev/null || omarchy plugin enable omext.core >/dev/null
info "done."

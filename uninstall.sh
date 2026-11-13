#!/bin/bash
# Removes what install.sh added. The omext addons that are still installed
# need it: remove them first.
set -uo pipefail
others=$(find "$HOME/.config/omarchy/plugins" -maxdepth 1 -name 'omext.*' ! -name 'omext.core' 2>/dev/null | sed 's|.*/||' | tr '\n' ' ')
if [[ -n $others && ${1:-} != --force ]]; then
  echo "uninstall: still needed by: $others(remove them first, or run again with --force)" >&2
  exit 1
fi
omarchy plugin disable omext.core >/dev/null 2>&1
# Omarchy's dock, if it was turned off here: back on.
rec=${XDG_STATE_HOME:-$HOME/.local/state}/omext/core/omarchy-dock-off
[[ -e $rec ]] && { rm -f "$rec"; omarchy plugin enable omarchy.dock >/dev/null 2>&1; }
[[ -L $HOME/.config/omarchy/plugins/omext.core ]] && rm "$HOME/.config/omarchy/plugins/omext.core"
[[ -L $HOME/.local/bin/omext-settings ]] && rm "$HOME/.local/bin/omext-settings"
[[ -L $HOME/.local/bin/omext-startup ]] && rm "$HOME/.local/bin/omext-startup"
hypr_conf=$HOME/.config/hypr/hyprland.lua
[[ -f $hypr_conf ]] && sed -i "/^-- BEGIN omext-core\$/,/^-- END omext-core\$/d" "$hypr_conf" && { hyprctl reload >/dev/null 2>&1 || true; }
echo "uninstall: done"

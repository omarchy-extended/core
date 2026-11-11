-- omext core: Escape closes what the omext addons have up over the windows:
-- an open dock, the taskbar and its lists, a menu, the zone map. The key still
-- goes to the app in front as well (the bind takes nothing from it), and each
-- addon hears it through a global shortcut of its own: nothing is started per
-- keypress, and one that isn't installed just isn't there to hear it. (What
-- has the keyboard itself, as Start's menu or the switcher's list, closes on
-- Escape on its own.)
local addons = { "docks", "taskbar", "zones" }
hl.bind("ESCAPE", function()
  for _, name in ipairs(addons) do
    hl.dispatch(hl.dsp.global("omext:escape-" .. name))
  end
end, { non_consuming = true, transparent = true })

-- omext core: a maximized (or fullscreen) window that gets the focus is in
-- front of the others on its workspace, as it looks.
--
-- Hyprland keeps a floating window that was once raised over a maximized one
-- drawn above it from then on, also after the maximized window is chosen
-- again: that one has the focus and is on top of the stack, so it gets the
-- clicks and the keys, while the other is still drawn over it. Clicks on what
-- you see land in the window behind it, and its title bar's buttons do nothing.
-- So when a maximized window gets the focus (or the window in front is
-- maximized), the other floating windows there step behind it, in the order
-- they had. Choosing one of them again brings it back over, as before.
local function behind(window)
  if not window or (window.fullscreen or 0) < 1 then
    return
  end
  local id = window.workspace and window.workspace.id
  if not id or id < 1 then
    return
  end
  local others = {}
  for _, other in ipairs(hl.get_workspace_windows(tostring(id))) do
    if other.address ~= window.address and other.floating and not other.pinned then
      others[#others + 1] = other
    end
  end
  -- From the top one down: each goes to the bottom, so their order stays.
  for i = #others, 1, -1 do
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = others[i] }))
  end
end

hl.on("window.active", behind)
hl.on("window.fullscreen", function(window)
  local active = hl.get_active_window and hl.get_active_window()
  if window and active and active.address == window.address then
    behind(window)
  end
end)

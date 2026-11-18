-- omext core: maximized windows behave as you see them.
--
-- 1. In front when chosen. Hyprland keeps a floating window that was once
--    raised over a maximized one drawn above it from then on, also after the
--    maximized window is chosen again: that one has the focus and is on top of
--    the stack, so it gets the clicks and the keys, while the other is still
--    drawn over it. Clicks on what you see land in the window behind it, and
--    its title bar's buttons do nothing. So when a maximized (or fullscreen)
--    window gets the focus, the other floating windows there step behind it,
--    in the order they had. Choosing one of them brings it back over.
--
-- 2. Still maximized when it comes back. A workspace has one maximized window
--    at a time: maximizing a second one (or bringing one back from being
--    minimized) takes it from the first, behind your back, and Omarchy takes it
--    when another window opens beside it. The first is then at its own size
--    when you get back to it. A window that lost it that way, not being the one
--    in front, gets it back when it is in front again. One you bring back to
--    its own size yourself (it is the one in front then) stays that way.
local maximized = {}   -- address -> true: maximized, as last heard
local displaced = {}   -- address -> true: lost it while another window was in front

-- (The windows maximized as this loads: no event has told of them.)
for _, window in ipairs(hl.get_windows and hl.get_windows() or {}) do
  if window.address and (window.fullscreen or 0) == 1 then
    maximized[window.address] = true
  end
end

local function behind(window)
  if not window or (window.fullscreen or 0) < 1 then
    return
  end
  local id = window.workspace and window.workspace.id
  if not id or id < 1 then
    return
  end
  -- (Not its own dialogs: those stay in front of it, hypr/dialogs.lua.)
  local mine = "omext-dialog-of-" .. window.address
  local function dialog(other)
    for _, tag in ipairs(other.tags or {}) do
      if tag == mine then
        return true
      end
    end
    return false
  end
  local others = {}
  for _, other in ipairs(hl.get_workspace_windows(tostring(id))) do
    if other.address ~= window.address and other.floating and not other.pinned and not dialog(other) then
      others[#others + 1] = other
    end
  end
  -- From the top one down: each goes to the bottom, so their order stays.
  for i = #others, 1, -1 do
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "bottom", window = others[i] }))
  end
end

local function is_active(window)
  local active = hl.get_active_window and hl.get_active_window()
  return active ~= nil and active.address == window.address
end

hl.on("window.active", function(window)
  if not window or not window.address then
    return
  end
  if displaced[window.address] then
    displaced[window.address] = nil
    local id = window.workspace and window.workspace.id
    if (window.fullscreen or 0) == 0 and id and id >= 1 then
      -- (The window.fullscreen this sets off puts the others behind it.)
      hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "set", window = window }))
      return
    end
  end
  behind(window)
end)

hl.on("window.fullscreen", function(window)
  if not window or not window.address then
    return
  end
  local address, mode = window.address, window.fullscreen or 0
  if mode == 1 then
    maximized[address] = true
    displaced[address] = nil
  elseif mode == 0 and maximized[address] then
    maximized[address] = nil
    -- Whether it was the one in front is looked at once the focus has settled:
    -- the window taking its place gets the focus in the same breath.
    hl.timer(function()
      local now = hl.get_window("address:" .. address)
      if now and (now.fullscreen or 0) == 0 and not is_active(now) then
        displaced[address] = true
      end
    end, { type = "oneshot", timeout = 30 })
  else
    maximized[address] = nil
  end
  if is_active(window) then
    behind(window)
  end
end)

local function forget(window)
  -- (A window that is already gone has no address left.)
  local address = window and window.address
  if address then
    maximized[address] = nil
    displaced[address] = nil
  end
end
hl.on("window.close", forget)
hl.on("window.destroy", forget)

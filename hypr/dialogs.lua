-- A dialog stays with the window it belongs to (omext core, from
-- omarchy-extended). Hyprland doesn't tell which window a dialog is of, so it
-- is worked out as the dialog opens: a window that floats on its own account
-- (Omarchy's floating mode didn't place it), and is either the desktop portal's
-- (the file choosers, "Save as") or of the same program as the window that was
-- in front. It is tagged omext-dialog-of-<that window's address>: the taskbar
-- reads the tag too, and keeps the dialog under its app.
--
-- From then on the dialog follows its window: in front of it whenever the
-- window is gone to (so it is never left hidden behind it), and with it to
-- another workspace, minimized and back.
local TAG = "omext-dialog-of-"
local FLOATED = "omarchy-mode-floated"   -- on every window Omarchy's floating mode placed
local active, before                      -- the window in front, and the one before it

local function tagged(window, tag)
  for _, t in ipairs(window.tags or {}) do
    if t == tag or t == tag .. "*" then
      return true
    end
  end
  return false
end

local function parent_of(window)
  for _, t in ipairs(window.tags or {}) do
    if t:sub(1, #TAG) == TAG then
      return (t:sub(#TAG + 1):gsub("%*$", ""))
    end
  end
end

local function portal(window)
  return (window.class or ""):find("^xdg%-desktop%-portal") ~= nil
end

local function workspace_of(window)
  local ws = window.workspace
  if not ws then
    return nil
  end
  if ws.id and ws.id >= 1 then
    return tostring(ws.id)
  end
  return ws.name
end

local function dialogs_of(window)
  local ok, found = pcall(hl.get_windows, { tag = TAG .. window.address })
  return ok and found or {}
end

-- The window a newly opened one is a dialog of, or nil.
local function owner(window)
  if not window.floating or tagged(window, FLOATED) or tagged(window, "omext-docked") or parent_of(window) then
    return nil
  end
  local id = window.workspace and window.workspace.id
  if not id or id < 1 then
    return nil
  end
  for _, address in ipairs({ active, before }) do
    local front = address and address ~= window.address and hl.get_window("address:" .. address)
    if front and front.workspace and front.workspace.id == id and (portal(window) or front.pid == window.pid) then
      return front
    end
  end
  -- (Not opened from the window in front: the program's topmost other window here.)
  local found
  for _, other in ipairs(hl.get_workspace_windows(tostring(id))) do
    if other.address ~= window.address and other.pid == window.pid and not parent_of(other) then
      found = other
    end
  end
  return found
end

hl.on("window.open", function(window)
  local address = window and window.address
  if not address then
    return
  end
  -- (A moment later: Omarchy's own tags are on it by then.)
  hl.timer(function()
    local now = hl.get_window("address:" .. address)
    local of = now and owner(now)
    if of then
      hl.dispatch(hl.dsp.window.tag({ tag = "+" .. TAG .. of.address, window = now }))
    end
  end, { type = "oneshot", timeout = 80 })
end)

hl.on("window.active", function(window)
  local address = window and window.address
  if not address then
    return
  end
  if address ~= active then
    before, active = active, address
  end
  if #dialogs_of(window) == 0 then
    return
  end
  -- (A moment later: what brought the window forward often raises it after
  -- giving it the focus, and the dialogs go over that.)
  hl.timer(function()
    local now = hl.get_window("address:" .. address)
    local here = now and workspace_of(now)
    local id = now and now.workspace and now.workspace.id
    if not here or not id or id < 1 or active ~= address then
      return
    end
    local last
    for _, dialog in ipairs(dialogs_of(now)) do
      if workspace_of(dialog) ~= here then
        hl.dispatch(hl.dsp.window.move({ workspace = here, follow = false, window = dialog }))
      end
      hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = dialog }))
      if portal(dialog) then
        last = dialog
      end
    end
    -- (The portal's dialogs wait for an answer: the keyboard goes to them.)
    if last then
      hl.dispatch(hl.dsp.focus({ window = last }))
    end
  end, { type = "oneshot", timeout = 60 })
end)

hl.on("window.move_to_workspace", function(window, workspace)
  if not window or not window.address or not workspace then
    return
  end
  local to = workspace.id and workspace.id >= 1 and tostring(workspace.id) or workspace.name
  if not to then
    return
  end
  for _, dialog in ipairs(dialogs_of(window)) do
    if workspace_of(dialog) ~= to then
      hl.dispatch(hl.dsp.window.move({ workspace = to, follow = false, window = dialog }))
    end
  end
end)

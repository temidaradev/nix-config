local t = require("theme")
local M = {}

function M.font(size, style)
  return { family = t.font, style = style or "Regular", size = size or t.size }
end

-- BarButton: transparent until hovered.
function M.hover(item, base_color)
  item:subscribe("mouse.entered", function()
    item:set({ background = { color = t.hover } })
  end)
  item:subscribe("mouse.exited", function()
    item:set({ background = { color = base_color or t.transparent } })
  end)
end

-- Breathing room between groups, without a visible divider.
function M.sep(position)
  return sbar.add("item", {
    position = position,
    padding_left = 0,
    padding_right = 0,
    icon = { drawing = false },
    width = 9,
    label = { drawing = false },
  })
end

function M.lines(s)
  local out = {}
  for line in tostring(s or ""):gmatch("[^\r\n]+") do out[#out + 1] = line end
  return out
end

function M.trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- One popup at a time. SketchyBar has no "clicked elsewhere" event, so a
-- popup closes shortly after the pointer leaves both it and its button, and
-- on app/space/display switches.
local open_popup = nil
local hover_gen = 0
local popup_gen = 0

function M.is_open(parent) return open_popup == parent end

function M.close_popups()
  popup_gen = popup_gen + 1
  if open_popup then open_popup:set({ popup = { drawing = false } }) end
  open_popup = nil
end

local function hovered()
  hover_gen = hover_gen + 1
end

local function left()
  hover_gen = hover_gen + 1
  local mine = hover_gen
  sbar.delay(0.4, function()
    if mine == hover_gen then M.close_popups() end
  end)
end

-- Draw PARENT's popup with its current content. SketchyBar lays a popup out
-- when its button redraws, but only draws the rows on the refresh after that,
-- and a refresh only happens when something changed. So nudge an invisible
-- property of the button (a 1/255-alpha border) twice: once with the open,
-- once a moment later. Also used after content changes while open.
local flip = false
local function nudge(parent)
  flip = not flip
  parent:set({ background = { border_color = flip and 0x01000000 or 0x00000000 } })
end

function M.redraw(parent)
  if open_popup ~= parent then return end
  parent:set({ popup = { drawing = true } })
  nudge(parent)
  sbar.delay(0.05, function()
    if open_popup == parent then nudge(parent) end
  end)
end

M.refresh_open = M.redraw

-- Open PARENT's popup (closing any other). ON_OPEN(show) fills it and calls
-- show() once its content is ready.
function M.open(parent, on_open)
  M.close_popups()
  open_popup = parent
  hovered()
  local mine = popup_gen
  local function current() return open_popup == parent and popup_gen == mine end
  local function show() if current() then M.redraw(parent) end end
  if on_open then on_open(show, current) else show() end
end

-- A click with BUTTON ("left" by default, "right" where the left click opens
-- Apple's own menu) toggles PARENT's popup; `sketchybar --trigger popup_open
-- TARGET=<item>` opens one without a click.
function M.attach(parent, on_open, button)
  -- Opening goes through the popup_open event rather than straight from the
  -- click handler: a popup opened in the middle of the click doesn't stay up.
  parent:subscribe("mouse.clicked", function(env)
    if env.BUTTON ~= (button or "left") then return end
    if open_popup == parent then
      M.close_popups()
    else
      sbar.trigger("popup_open", { TARGET = parent.name })
    end
  end)
  parent:subscribe("popup_open", function(env)
    if env.TARGET == parent.name then M.open(parent, on_open) end
  end)
  M.track(parent)
  parent:subscribe({ "front_app_switched", "space_change", "display_change" }, function()
    if open_popup == parent then M.close_popups() end
  end)
end

-- Items inside a popup keep it open while hovered.
function M.track(item)
  item:subscribe("mouse.entered", hovered)
  item:subscribe("mouse.exited", left)
end

function M.popup_style(parent, align)
  parent:set({
    popup = {
      align = align or "center",
      y_offset = 6,
      height = 28,
      background = { color = t.popup, border_color = t.border, border_width = 1, corner_radius = 10 },
    },
  })
end

-- Popup under PARENT: a column of rows
--   { icon=, text=, header=, bold=, dim=, faint=, warn=, highlight=, on_click= }.
-- Returns fill(rows). Clicking PARENT toggles it, calling REFRESH(fill) first.
function M.popup(parent, n, refresh, width, align, button)
  width = width or 260
  M.popup_style(parent, align)
  local rows, handlers, marked = {}, {}, {}
  for i = 1, n do
    local row = sbar.add("item", parent.name .. ".row" .. i, {
      position = "popup." .. parent.name,
      drawing = false,
      width = width,
      icon = { color = t.dim, padding_left = 12, padding_right = 6, width = 32 },
      label = { padding_right = 12, max_chars = math.floor((width - 56) / 7.8) },
      background = { height = 24, corner_radius = t.radius },
    })
    row:subscribe("mouse.clicked", function(env)
      if handlers[i] then
        handlers[i](env)
        M.close_popups()
      end
    end)
    row:subscribe("mouse.entered", function()
      hovered()
      if handlers[i] then row:set({ background = { color = t.hover } }) end
    end)
    row:subscribe("mouse.exited", function()
      left()
      row:set({ background = { color = marked[i] and t.hover or t.transparent } })
    end)
    rows[i] = row
  end

  local function fill(data)
    for i = 1, n do
      local r = data[i]
      handlers[i] = r and r.on_click or nil
      marked[i] = r and r.highlight or nil
      if r then
        local warn = r.warn == true and t.red or r.warn
        local color = warn or (r.faint and t.faint) or ((r.header or r.on_click or r.bold or not r.dim) and t.fg or t.dim)
        if r.dim then color = warn or t.dim end
        rows[i]:set({
          drawing = true,
          background = { color = r.highlight and t.hover or t.transparent },
          icon = { string = r.icon or "", color = warn or (r.header and t.fg or t.dim) },
          label = { string = r.text or "", color = color, font = M.font(t.size, (r.header or r.bold) and "Bold" or "Regular") },
        })
      else
        rows[i]:set({ drawing = false })
      end
    end
  end

  M.attach(parent, function(show, current)
    if not refresh then return show() end
    refresh(function(data)
      if not current() then return end
      fill(data)
      show()
    end)
  end, button)
  return fill
end

-- Displays, matched to SketchyBar's arrangement ids by CGDirectDisplayID
-- (not by list position). Queried once per change and shared by every user.
local display_listeners, display_cache = {}, nil

function M.on_displays(fn)
  table.insert(display_listeners, fn)
  if display_cache then fn(display_cache) end
end

function M.refresh_displays()
  sbar.exec(SBMENUS .. " -d", function(out)
    local info = {}
    for _, line in ipairs(M.lines(out)) do
      local id, b, a, w = line:match("^(%d+)\t(%d)\t(%d)\t(%d+)")
      if id then info[tonumber(id)] = { builtin = b == "1", active = a == "1", width = tonumber(w) } end
    end
    sbar.exec("sketchybar --query displays", function(list)
      if type(list) ~= "table" then return end
      local result = {}
      for _, d in ipairs(list) do
        local i = info[tonumber(d.DirectDisplayID)]
        if i then
          i.aid = d["arrangement-id"]
          result[#result + 1] = i
        end
      end
      display_cache = result
      for _, fn in ipairs(display_listeners) do fn(result) end
    end)
  end)
end

-- Click handler that opens one of Apple's own menu bar menus
-- (com.apple.menuextra.*) through sbmenus.
function M.apple_menu(id)
  return function()
    M.close_popups()
    sbar.exec(SBMENUS .. " -i " .. id)
  end
end

-- Match only an executable path at the start of the command line, never a
-- shell whose script mentions the provider. [/] also excludes pkill itself.
local function watch_pattern(kind)
  assert(kind:match("^[a-z]+$"), "invalid provider kind")
  return "^/[^ ]*[/]sbwatch " .. kind .. "( |$)"
end

function M.stop_watch(kind)
  sbar.exec("pkill -f '" .. watch_pattern(kind) .. "'")
end
function M.watch(kind, ...)
  local args = table.concat({ ... }, " ")
  sbar.exec(string.format("pkill -f '%s'; nohup %s %s %s >/dev/null 2>&1 &", watch_pattern(kind), SBWATCH, kind, args))
end

return M

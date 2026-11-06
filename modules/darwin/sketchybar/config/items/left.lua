-- Left: nix button (Apple menu), then the front app's own menus (bold app
-- name, File, Edit, ...). Menus that would run under the notch are dropped,
-- like macOS does.
local t = require("theme")
local h = require("helpers")
local g = require("glyphs")

local nix = sbar.add("item", "nix", {
  icon = { string = g.nix, font = h.font(17), color = t.nix, padding_left = 7, padding_right = 7 },
  label = { drawing = false },
  click_script = SBMENUS .. " -s 0",
})
h.hover(nix)

local MENUS = 16
local CHAR = 7.8           -- JetBrains Mono advance at 13pt (0.6em)
local PAD = 2 * 7 + 2      -- label padding + item padding per menu
local NIX = 36             -- nix button width
local NOTCH = 210          -- notch plus a little air

local menus = {}
for i = 1, MENUS do
  local m = sbar.add("item", "menu." .. i, {
    drawing = false,
    icon = { drawing = false },
    label = {
      font = h.font(t.size, i == 1 and "Bold" or "Regular"),
      color = i == 1 and t.fg or t.dim,
      padding_left = 7,
      padding_right = 7,
    },
    display = "active",
    click_script = SBMENUS .. " -s " .. i,
  })
  h.hover(m)
  menus[i] = m
end

-- Menus show on the active display only (like macOS); the notch limit
-- applies only while that is the built-in screen.
local room = math.huge
h.on_displays(function(displays)
  room = math.huge
  for _, d in ipairs(displays) do
    if d.active and d.builtin then room = (d.width - NOTCH) / 2 - NIX - 8 end
  end
end)

local function refresh_menus()
  sbar.exec(SBMENUS .. " -l", function(out)
    local titles = h.lines(out)
    local used = 0
    for i = 1, MENUS do
      local title = titles[i]
      local width = title and (utf8.len(title) or #title) * CHAR + PAD or 0
      local fits = title ~= nil and title ~= "" and used + width <= room
      if fits then used = used + width end
      menus[i]:set({ drawing = fits, label = { string = title or "" } })
    end
  end)
end

local watcher = sbar.add("item", "menu.watcher", { drawing = false, updates = true })
-- Apps build their menus a moment after activating (and the active display
-- may have changed), so read twice.
watcher:subscribe({ "front_app_switched", "system_woke", "forced" }, function()
  refresh_menus()
  sbar.delay(0.6, refresh_menus)
end)

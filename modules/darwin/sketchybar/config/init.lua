sbar = require("sketchybar")
local t = require("theme")
local h = require("helpers")

sbar.begin_config()

sbar.bar({
  position = "top",
  height = t.height,
  notch_display_height = t.notch_height,
  color = t.bg,
  border_width = 0,
  corner_radius = 0,
  margin = 0,
  y_offset = 0,
  padding_left = 6,
  padding_right = 6,
  shadow = "off",
  sticky = "on",
  -- Above Apple's menu bar (patched one level higher in ../default.nix).
  topmost = "on",
  show_in_fullscreen = "on",
})

sbar.default({
  updates = "when_shown",
  padding_left = 1,
  padding_right = 1,
  icon = { font = h.font(t.glyph), color = t.fg, padding_left = 6, padding_right = 4 },
  label = { font = h.font(t.size), color = t.fg, padding_left = 0, padding_right = 6 },
  background = { height = t.pill, corner_radius = t.radius, color = t.transparent },
  scroll_texts = "off",
})

-- Ask once for Accessibility (app menus, tray and the gear need it).
sbar.exec(SBMENUS .. " --prompt")

sbar.add("event", "popup_open")
sbar.add("event", "network_change") -- from `sbwatch net`
sbar.add("event", "stats_update")   -- from `sbwatch stats`
sbar.add("event", "tray_change") -- app launch/quit notifications

require("items.left")
require("items.right")

local displays = sbar.add("item", "displays.watch", { drawing = false, updates = true })
displays:subscribe({ "display_change", "system_woke", "front_app_switched", "forced" }, h.refresh_displays)
h.watch("net")
h.watch("apps")

sbar.end_config()

sbar.event_loop()

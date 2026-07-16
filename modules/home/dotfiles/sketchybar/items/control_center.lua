local settings = require("settings")
local colors = require("colors")
local icons = require("icons")

-- Padding item required because of bracket
sbar.add("item", { position = "center", width = settings.group_paddings })

local control_center = sbar.add("item", {
  icon = {
    string = icons.control_center,
    color = colors.white,
    padding_left = 6,
    padding_right = 8,
    font = {
      style = settings.font.style_map["Black"],
      size = 14.0,
    },
  },
  label = { drawing = false },
  position = "right",
  padding_left = 1,
  padding_right = 1,
  background = {
    color = colors.bg2,
    border_color = colors.black,
    border_width = 1
  },
})

control_center:subscribe("mouse.clicked", function(env)
  sbar.exec([[osascript -e 'tell application "System Events" to tell process "Control Center"
    repeat with theItem in menu bar items of menu bar 1
      if description of theItem is "Control Center" then
        perform action "AXPress" of theItem
        exit repeat
      end if
    end repeat
  end tell']])
end)

-- Double border for control center using a single item bracket
sbar.add("bracket", { control_center.name }, {
  background = {
    color = colors.transparent,
    height = 30,
    border_color = colors.grey,
  }
})

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

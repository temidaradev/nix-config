local settings = require("settings")
local colors = require("colors")

sbar.add("item", { position = "right", width = settings.group_paddings })

local warp = sbar.add("item", "warp", {
  position = "right",
  icon = {
    string = "󰖂",  -- NerdFont VPN/shield icon
    color = colors.white,
    padding_left = 8,
    padding_right = 8,
    font = {
      style = settings.font.style_map["Black"],
      size = 14.0,
    },
  },
  label = { drawing = false },
  padding_left = 1,
  padding_right = 1,
  background = {
    color = colors.bg2,
    border_color = colors.black,
    border_width = 1
  },
})

warp:subscribe("mouse.clicked", function(env)
  sbar.exec([[osascript -e 'tell application "System Events" to tell process "Cloudflare WARP" to click menu bar item 1 of menu bar 1']])
end)

sbar.add("bracket", { warp.name }, {
  background = {
    color = colors.transparent,
    height = 30,
    border_color = colors.grey,
  }
})

sbar.add("item", { position = "right", width = settings.group_paddings })

return warp

local settings = require("settings")
local colors = require("colors")
local icons = require("icons")

local eqmac = sbar.add("item", "eqmac", {
  position = "right",
  icon = {
    string = "󰺢",
    color = colors.white,
    padding_left = 8,
    padding_right = 8,
    font = {
      style = settings.font.style_map["Black"],
      size = 16.0,
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
  click_script = 'open -a eqMac',
})

sbar.add("bracket", { eqmac.name }, {
  background = {
    color = colors.transparent,
    height = 30,
    border_color = colors.grey,
  }
})

return eqmac

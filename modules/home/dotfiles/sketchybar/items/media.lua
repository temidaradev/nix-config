local icons = require("icons")
local colors = require("colors")

local whitelist = { ["Spotify"] = true,
                    ["Music"] = true    };

-- Add the media_change event
sbar.add("event", "media_change")

local media_cover = sbar.add("item", "media.cover", {
  position = "right",
  background = {
    image = {
      scale = 0.045,
      corner_radius = 5,
    },
    color = colors.transparent,
    height = 28,
    drawing = true,
  },
  label = { drawing = false },
  icon = { drawing = false },
  drawing = false,
  updates = true,
  update_freq = 1,
  popup = {
    align = "center",
    horizontal = true,
  },
  script = "~/.config/sketchybar/plugins/media.sh",
})

local media_artist = sbar.add("item", "media.artist", {
  position = "right",
  drawing = false,
  padding_left = 3,
  padding_right = 0,
  width = 0,
  icon = { drawing = false },
  label = {
    width = 0,
    font = { size = 9 },
    color = colors.with_alpha(colors.white, 0.6),
    max_chars = 18,
    y_offset = 6,
  },
})

local media_title = sbar.add("item", "media.title", {
  position = "right",
  drawing = false,
  padding_left = 3,
  padding_right = 0,
  icon = { drawing = false },
  label = {
    font = { size = 11 },
    width = 0,
    max_chars = 16,
    y_offset = -5,
  },
})

sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.back },
  label = { drawing = false },
  click_script = "osascript -e 'tell application \"Music\" to previous track' || osascript -e 'tell application \"Spotify\" to previous track'",
})
sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.play_pause },
  label = { drawing = false },
  click_script = "osascript -e 'tell application \"Music\" to playpause' || osascript -e 'tell application \"Spotify\" to playpause'",
})
sbar.add("item", {
  position = "popup." .. media_cover.name,
  icon = { string = icons.media.forward },
  label = { drawing = false },
  click_script = "osascript -e 'tell application \"Music\" to next track' || osascript -e 'tell application \"Spotify\" to next track'",
})

local interrupt = 0
local function animate_detail(detail)
  if (not detail) then interrupt = interrupt - 1 end
  if interrupt > 0 and (not detail) then return end

  sbar.animate("tanh", 30, function()
    media_artist:set({ label = { width = detail and "dynamic" or 0 } })
    media_title:set({ label = { width = detail and "dynamic" or 0 } })
  end)
end

media_cover:subscribe("media_change", function(env)
  if media_cover:query().geometry.drawing == "on" then
    animate_detail(true)
    interrupt = interrupt + 1
    sbar.delay(5, animate_detail)
  else
    media_cover:set({ popup = { drawing = false } })
  end
end)

media_cover:subscribe("mouse.entered", function(env)
  interrupt = interrupt + 1
  animate_detail(true)
end)

media_cover:subscribe("mouse.exited", function(env)
  animate_detail(false)
end)

media_cover:subscribe("mouse.clicked", function(env)
  media_cover:set({ popup = { drawing = "toggle" }})
end)

media_title:subscribe("mouse.exited.global", function(env)
  media_cover:set({ popup = { drawing = false }})
end)

media_cover:subscribe("routine", function(env)
  sbar.exec("~/.config/sketchybar/plugins/media.sh")
end)

media_cover:subscribe("forced", function(env)
  sbar.exec("~/.config/sketchybar/plugins/media.sh")
end)

sbar.exec("~/.config/sketchybar/plugins/media.sh")

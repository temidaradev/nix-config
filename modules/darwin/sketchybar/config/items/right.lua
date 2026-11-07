-- Right, grouped like the Linux bar (right-positioned items stack leftwards,
-- so they're added from the screen edge inwards):
--   tray | layout, volume, Wi-Fi, Bluetooth, battery | cpu, memory | gear, clock
local t = require("theme")
local h = require("helpers")
local g = require("glyphs")
local icon_map = require("icon_map")

local function right(name, props)
  props.position = "right"
  return sbar.add("item", name, props)
end

local function settings(pane)
  return function() sbar.exec("open 'x-apple.systempreferences:" .. pane .. "'") end
end

local function open_app(app)
  return function() sbar.exec("open -a '" .. app .. "'") end
end

---------------- clock ----------------
-- Built-in (notched) screen: just the time at the far right. Displays
-- without a notch get the Linux layout instead: dim date + bold time centred.
-- Calendar popup: a month grid rendered to an image by sbcal (popups can
-- only stack rows of text). Scroll over it to change month.
local CAL_DIR = (os.getenv("TMPDIR") or "/tmp/"):gsub("/?$", "/")
local function calendar_popup(parent, align, button)
  h.popup_style(parent, align)
  local offset = 0
  local cal = sbar.add("item", parent.name .. ".cal", {
    position = "popup." .. parent.name,
    width = 268,
    padding_left = 0,
    padding_right = 0,
    icon = { drawing = false },
    label = { drawing = false },
    background = { color = t.transparent, image = { scale = 0.5 } },
  })
  h.track(cal)
  local function render(done)
    local now = os.date("*t")
    local d = os.date("*t", os.time({ year = now.year, month = now.month + offset, day = 1, hour = 12 }))
    local today = offset == 0 and now.day or 0
    local path = string.format("%ssbcal-%d-%02d-%d.png", CAL_DIR, d.year, d.month, today)
    local colors = string.format("0x%08x 0x%08x 0x%08x 0x%08x 0x%08x", t.fg, t.dim, t.faint, t.bg, t.border)
    sbar.exec(string.format("rm -f '%s'sbcal-*.png; %s %d %d %d '%s' %s",
      CAL_DIR, SBCAL, d.year, d.month, today, path, colors), function(out)
      local height = tonumber(h.trim(out))
      if height then cal:set({ background = { height = height, image = { string = path } } }) end
      if done then done() end
    end)
  end
  cal:subscribe("mouse.scrolled", function(env)
    local delta = tonumber(env.INFO and env.INFO.delta or env.SCROLL_DELTA) or 0
    offset = offset + (delta > 0 and -1 or 1)
    render(function() h.refresh_open(parent) end)
  end)
  cal:subscribe("mouse.clicked", function()
    offset = 0
    render(function() h.refresh_open(parent) end)
  end)
  h.attach(parent, function(show)
    offset = 0
    render(show)
  end, button)
end

local clock = right("clock", {
  update_freq = 60,
  updates = true,
  icon = { drawing = false },
  label = { font = h.font(t.size, "Bold"), padding_left = 6, padding_right = 6 },
})
h.hover(clock)
-- Click (either button): the calendar. Apple's clock item (Notification
-- Center) ignores programmatic presses, so it isn't offered here; the
-- trackpad's two-finger swipe from the right edge opens it.
calendar_popup(clock, "right", "left")
clock:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then sbar.trigger("popup_open", { TARGET = "clock" }) end
end)

local center_clock = sbar.add("item", "clock.center", {
  position = "center",
  drawing = false,
  updates = true,
  icon = { font = h.font(t.size), color = t.dim, padding_left = 10, padding_right = 8 },
  label = { font = h.font(t.size, "Bold"), padding_right = 10 },
})
h.hover(center_clock)
calendar_popup(center_clock, nil, "left")

local function tick()
  local time = os.date("%H:%M")
  clock:set({ label = { string = time } })
  center_clock:set({
    icon = { string = os.date("%a ") .. tonumber(os.date("%d")) .. os.date(" %b") },
    label = { string = time },
  })
end
clock:subscribe({ "routine", "forced", "system_woke" }, tick)
tick()

h.on_displays(function(displays)
  local builtin, external = {}, {}
  for _, d in ipairs(displays) do
    table.insert(d.builtin and builtin or external, tostring(d.aid))
  end
  clock:set({ display = #builtin > 0 and table.concat(builtin, ",") or "all", drawing = #builtin > 0 or #external == 0 })
  center_clock:set({ display = #external > 0 and table.concat(external, ",") or "1", drawing = #external > 0 })
end)

---------------- control centre ----------------
local control = right("control", {
  icon = { string = g.gear, padding_left = 6, padding_right = 6 },
  label = { drawing = false },
  click_script = SBMENUS .. " -i com.apple.menuextra.controlcenter",
})
h.hover(control)

h.sep("right")

---------------- cpu + memory ----------------
local function stat(name, glyph)
  local item = right(name, {
    updates = true,
    icon = { string = glyph, color = t.dim, padding_right = 4 },
    label = { font = h.font(t.small), width = 32, align = "left" },
  })
  h.hover(item)
  return item
end

local function show_pct(item, v)
  item:set({
    icon = { color = v > 85 and t.red or t.dim },
    label = { string = math.floor(v + 0.5) .. "%", color = v > 85 and t.red or t.fg },
  })
end

-- Popup body: top processes from `ps`, "value path" per line.
local function top_rows(cmd, header, fmt, extra, fill)
  sbar.exec(cmd, function(out)
    local rows = { header }
    for _, r in ipairs(extra) do rows[#rows + 1] = r end
    for _, line in ipairs(h.lines(out)) do
      local value, path = line:match("^%s*([%d%.]+)%s+(.+)$")
      if value then
        local name = path:match("([^/]+)$") or path
        rows[#rows + 1] = { text = string.format("%-22.22s %9s", name, fmt(tonumber(value))), dim = true }
      end
    end
    rows[#rows + 1] = { icon = g.gear, text = "Activity Monitor…", on_click = open_app("Activity Monitor") }
    fill(rows)
  end)
end

-- Memory the way Activity Monitor counts it: used = app + wired + compressed,
-- coloured by macOS's own pressure level (1 normal, 2 warning, 4 critical).
local MEM_CMD = "vm_stat; sysctl -n hw.memsize vm.swapusage kern.memorystatus_vm_pressure_level"
local function parse_mem(out)
  out = tostring(out)
  local page = tonumber(out:match("page size of (%d+) bytes")) or 16384
  local function pages(key)
    return (tonumber(out:match(key .. ":%s+(%d+)")) or 0) * page / 1073741824
  end
  local tail = h.lines(out)
  local n = #tail
  local m = {
    app = pages("Anonymous pages") - pages("Pages purgeable"),
    wired = pages("Pages wired down"),
    compressed = pages("Pages occupied by compressor"),
    cached = pages("File%-backed pages") + pages("Pages purgeable"),
    total = (tonumber(tail[n - 2]) or 0) / 1073741824,
    swap = (tonumber(tostring(tail[n - 1] or ""):match("used = ([%d%.]+)M")) or 0) / 1024,
    pressure = tonumber(tail[n]) or 1,
  }
  m.used = m.app + m.wired + m.compressed
  return m
end
local function pressure_color(p)
  return p >= 4 and t.red or (p >= 2 and t.amber or nil)
end

local mem = right("mem", {
  updates = true,
  icon = { string = g.memory, color = t.dim, padding_right = 4 },
  label = { font = h.font(t.small), width = 42, align = "left" },
})
h.hover(mem)
mem:subscribe({ "routine", "forced", "system_woke" }, function()
  sbar.exec(MEM_CMD, function(out)
    local m = parse_mem(out)
    local warn = pressure_color(m.pressure)
    mem:set({
      icon = { color = warn or t.dim },
      label = { string = string.format("%.1fG", m.used), color = warn or t.fg },
    })
  end)
end)
h.popup(mem, 14, function(fill)
  sbar.exec(MEM_CMD, function(memout)
    sbar.exec("df -H /System/Volumes/Data | awk 'NR==2 {print $3 \" of \" $2 \" used\"; print $5}'", function(dfout)
    local m = parse_mem(memout)
    local l = h.lines(dfout)
    local disk, disk_pct = l[1] or "-", tonumber((l[2] or ""):match("%d+")) or 0
    local warn = pressure_color(m.pressure)
    local gb = function(v) return string.format("%5.1f GB", v) end
    top_rows("ps -Ao rss=,comm= -m | head -5",
      { icon = g.memory, text = string.format("Memory · %.1f of %.0f GB", m.used, m.total), header = true },
      function(kb) return kb >= 1048576 and string.format("%.1f GB", kb / 1048576) or string.format("%.0f MB", kb / 1024) end,
      {
        { icon = g.load, text = "Pressure    " .. (m.pressure >= 4 and "Critical" or (m.pressure >= 2 and "Warning" or "Normal")), warn = warn },
        { text = "App         " .. gb(m.app) },
        { text = "Wired       " .. gb(m.wired) },
        { text = "Compressed  " .. gb(m.compressed) },
        { text = "Cached      " .. gb(m.cached), dim = true },
        { text = "Swap        " .. gb(m.swap), dim = true },
        { icon = g.disk, text = "Disk  " .. disk, warn = disk_pct > 90, on_click = settings("com.apple.settings.Storage") },
      },
      fill)
    end)
  end)
end, 310, "right")

-- Fed by `sbwatch stats` (real load from processor tick deltas), no polling here.
local cpu = stat("cpu", g.cpu)
cpu:subscribe("stats_update", function(env)
  local v = tonumber(env.CPU)
  if v then show_pct(cpu, v) end
end)
h.popup(cpu, 9, function(fill)
  sbar.exec("sysctl -n machdep.cpu.brand_string hw.ncpu; uptime | sed 's/.*load averages*: //'", function(info)
    local l = h.lines(info)
    top_rows("ps -Ao pcpu=,comm= -r | head -6",
      { icon = g.cpu, text = (l[1] or "CPU") .. " · " .. (l[2] or "?") .. " cores", header = true },
      function(p) return string.format("%.1f%%", p) end,
      { { icon = g.load, text = "Load  " .. (l[3] or "-") } },
      fill)
  end)
end, 310, "right")

-- Network speed: two stacked lines, from the same stats event.
local net_up = right("net.up", {
  width = 0,
  y_offset = 6,
  icon = { string = g.up, font = h.font(9), color = t.dim, padding_left = 4, padding_right = 2 },
  label = { string = "0B", font = h.font(10), width = 42, align = "right", color = t.dim, padding_right = 6 },
})
local net_down = right("net.down", {
  y_offset = -6,
  updates = true,
  icon = { string = g.down, font = h.font(9), color = t.dim, padding_left = 4, padding_right = 2 },
  label = { string = "0B", font = h.font(10), width = 42, align = "right", color = t.dim, padding_right = 6 },
})
local function rate(b)
  if b >= 1048576 then return string.format("%.1fM", b / 1048576) end
  if b >= 1024 then return string.format("%.0fK", b / 1024) end
  return string.format("%.0fB", b)
end
net_down:subscribe("stats_update", function(env)
  net_down:set({ label = { string = rate(tonumber(env.RX) or 0) } })
  net_up:set({ label = { string = rate(tonumber(env.TX) or 0) } })
end)

-- A quiet surface separates telemetry from the interactive system controls.
sbar.add("bracket", "telemetry", { "cpu", "mem", "net.up", "net.down" }, {
  background = { color = t.surface, height = t.pill, corner_radius = t.radius },
})

-- One sampler for CPU/network/battery; shell-based memory queries run less often.
-- Restart on wake even when the power source has not changed.
local power = right("stats.power", { drawing = false, updates = true })
local on_ac = nil
local function refresh_power(env)
  sbar.exec("pmset -g batt | head -1", function(out)
    local ac = tostring(out):find("AC Power") ~= nil
    if ac == on_ac and env and env.SENDER == "power_source_change" then return end
    on_ac = ac
    h.watch("stats", ac and 1 or 3)
    mem:set({ update_freq = ac and 30 or 120 })
  end)
end
power:subscribe({ "power_source_change", "forced", "system_woke" }, refresh_power)
power:subscribe("system_will_sleep", function() h.stop_watch("stats") end)
refresh_power()

h.sep("right")

---------------- battery ----------------
-- Compact charge and current system wattage, with details on a normal click.
local battery = right("battery", {
  updates = true,
  icon = { padding_right = 4 },
  label = { font = h.font(t.small, "Bold") },
  background = { color = t.surface },
})
h.hover(battery, t.surface)
local draw = right("power.draw", {
  updates = true,
  drawing = false,
  icon = { string = g.bolt, color = t.dim, padding_right = 3 },
  label = { font = h.font(t.small), width = 48, align = "right", color = t.dim },
})
h.hover(draw)
draw:subscribe("mouse.clicked", function()
  sbar.trigger("popup_open", { TARGET = "battery" })
end)
local function show_battery(pct, ac, charging)
  if not pct or pct < 0 then
    battery:set({ drawing = false })
    return
  end
  local low = pct < 20 and not ac
  -- Time estimates and power draw are available in the battery popup.
  battery:set({
    drawing = true,
    icon = {
      -- bolt while charging, plug when held (e.g. at the 80% limit)
      string = charging and g.charging or (ac and g.plug or g.battery[math.floor(pct / 10) + 1]),
      color = low and t.red or t.fg,
    },
    label = { string = pct .. "%", color = low and t.red or t.fg },
  })
end

battery:subscribe("stats_update", function(env)
  local ac = env.AC == "1"
  show_battery(tonumber(env.BATT), ac, env.CHARGING == "1")
  local watts = tonumber(env.WATTS) or -1
  local color = not ac and watts > 25 and t.amber or t.dim
  draw:set({
    drawing = watts >= 0,
    label = { string = string.format("%.1fW", watts), color = color },
    icon = { color = color },
  })
end)
battery:subscribe({ "power_source_change", "forced", "system_woke" }, function()
  sbar.exec("pmset -g batt", function(out)
    out = tostring(out)
    show_battery(tonumber(out:match("(%d+)%%")), out:find("AC Power") ~= nil, out:find("; charging;") ~= nil)
  end)
end)

h.popup(battery, 8, function(fill)
  -- Raw capacities sit inside the BatteryData dictionary as "Key"=value.
  sbar.exec("pmset -g batt; ioreg -rc AppleSmartBattery | grep -E '\"(CycleCount|BatteryData|AdapterDetails|PowerTelemetryData)\"'", function(out)
    out = tostring(out)
    local pct = out:match("(%d+)%%") or "?"
    local status = out:match("%d+%%; ([^;]+);") or "-"
    local remain = out:match("(%d+:%d+) remaining")
    local ac = out:find("AC Power") ~= nil
    local cycles = out:match('"CycleCount"%s*=%s*(%d+)')
    -- NominalChargeCapacity is what System Settings bases "Maximum Capacity" on.
    local maxc = tonumber(out:match('"NominalChargeCapacity"%s*=%s*(%d+)'))
    local design = tonumber(out:match('"DesignCapacity"%s*=%s*(%d+)'))
    local health = (maxc and design and design > 0) and math.floor(maxc / design * 100 + 0.5) or nil
    local load = tonumber(out:match('"SystemLoad"%s*=%s*(%d+)'))
    local adapter = ac and tonumber(out:match('"Watts"%s*=%s*(%d+)'))
    local time = remain and (remain .. (ac and " to full" or " left")) or (ac and "Plugged in" or "Calculating…")
    fill({
      { icon = g.battery[math.floor((tonumber(pct) or 0) / 10) + 1], text = "Battery · " .. pct .. "%", header = true },
      { icon = g.plug, text = "Status   " .. status:gsub("^%l", string.upper) .. (adapter and (" · " .. adapter .. " W adapter") or "") },
      { icon = g.clock, text = "Time     " .. time },
      { icon = g.bolt, text = "Draw     " .. (load and string.format("%.1f W", load / 1000) or "-") },
      { icon = g.heart, text = "Health   " .. (health and (health .. "%") or "-"), warn = health and health < 80 },
      { icon = g.cycle, text = "Cycles   " .. (cycles or "-") },
      { icon = g.battery[8], text = "macOS battery menu…", on_click = h.apple_menu("com.apple.menuextra.battery") },
      { icon = g.gear, text = "Battery settings…", on_click = settings("com.apple.Battery-Settings.extension") },
    })
  end)
end, 300, "right")

---------------- bluetooth ----------------
local bt = right("bluetooth", {
  update_freq = 180,
  updates = true,
  icon = { padding_right = 6 },
  label = { drawing = false },
})
h.hover(bt)
local function refresh_bt()
  sbar.exec("blueutil -p; blueutil --connected | grep -c .", function(out)
    local l = h.lines(out)
    local on, linked = l[1] == "1", (tonumber(l[2]) or 0) > 0
    bt:set({ icon = { string = not on and g.bt_off or (linked and g.bt_linked or g.bt_on), color = on and t.fg or t.faint } })
  end)
end
bt:subscribe({ "routine", "forced", "system_woke" }, refresh_bt)
bt:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then sbar.exec("blueutil -p toggle", refresh_bt) end
end)
h.popup(bt, 9, function(fill)
  sbar.exec("blueutil -p; blueutil --paired --format json", function(out)
    local text = tostring(out)
    local on = text:sub(1, 1) == "1"
    local rows = {
      { icon = on and g.bt_on or g.bt_off, text = "Bluetooth · " .. (on and "On" or "Off"), header = true,
        on_click = function() sbar.exec("blueutil -p toggle", refresh_bt) end },
    }
    -- blueutil's JSON: one object per paired device; connected ones first
    local devices = {}
    for obj in text:gmatch("{(.-)}") do
      local name, addr = obj:match('"name":"(.-)"'), obj:match('"address":"(.-)"')
      if name and addr then
        devices[#devices + 1] = { name = name, addr = addr, connected = obj:find('"connected":true') ~= nil }
      end
    end
    table.sort(devices, function(a, b)
      if a.connected ~= b.connected then return a.connected end
      return a.name < b.name
    end)
    for _, d in ipairs(devices) do
      if #rows >= 8 then break end
      rows[#rows + 1] = {
        icon = d.connected and g.bt_linked or g.device,
        text = d.name,
        dim = not d.connected,
        on_click = function()
          sbar.exec("blueutil --" .. (d.connected and "disconnect" or "connect") .. " " .. d.addr, refresh_bt)
        end,
      }
    end
    rows[#rows + 1] = { icon = g.gear, text = "Bluetooth settings…", on_click = settings("com.apple.BluetoothSettings") }
    fill(rows)
  end)
end, 300, "right")

---------------- network ----------------
-- Wi-Fi (en0) first, then any wired/dock interface (en1..); updated
-- instantly by `sbwatch net` instead of polling. (Not subscribed to
-- SketchyBar's own wifi_change: that polls the SSID internally.)
local NET_CMD = [[(for i in en0 $(ifconfig -l | tr ' ' '\n' | grep '^en' | grep -vx en0); do ]]
  .. [[ip=$(ipconfig getifaddr "$i") && { echo "$i"; echo "$ip"; exit; }; done; echo none)]]
local wifi = right("wifi", {
  updates = true,
  icon = { padding_right = 6 },
  label = { drawing = false },
})
h.hover(wifi)
local function refresh_wifi()
  sbar.exec(NET_CMD, function(out)
    local iface = h.lines(out)[1] or "none"
    local up = iface ~= "none"
    wifi:set({
      icon = {
        string = not up and g.wifi_off or (iface == "en0" and g.wifi or g.ethernet),
        color = up and t.fg or t.faint,
      },
    })
  end)
end
wifi:subscribe({ "network_change", "system_woke", "forced" }, refresh_wifi)
h.popup(wifi, 7, function(fill)
  refresh_wifi()
  sbar.exec(NET_CMD
      .. [[; ipconfig getsummary en0 | awk -F ' SSID : ' '/ SSID : / {print $2}' | grep . || echo -; ]]
      .. [[route -n get default 2>/dev/null | awk '/interface:/{print $2}' | grep . || echo -; ]]
      .. [[route -n get default 2>/dev/null | awk '/gateway:/{print $2}' | grep . || echo -; ]]
      .. [[scutil --dns | awk '/nameserver\[0\]/{print $3; exit}' | grep . || echo -]],
    function(out)
      local l = h.lines(out)
      local iface, ip = l[1] or "none", (l[1] ~= "none" and l[2]) or "-"
      local rest = l[1] == "none" and 2 or 3 -- the SSID line follows the address
      local ssid = l[rest]
      local title
      if iface == "none" then
        title = "Offline"
      elseif iface == "en0" then
        title = (ssid and ssid ~= "-" and ssid ~= "<redacted>") and ssid or "Wi-Fi"
      else
        title = "Ethernet (" .. iface .. ")"
      end
      fill({
        { icon = iface == "none" and g.wifi_off or (iface == "en0" and g.wifi or g.ethernet), text = title, header = true },
        { icon = g.network, text = "IP       " .. ip },
        { icon = g.network, text = "Route    " .. (l[rest + 1] or "-") },
        { icon = g.router, text = "Gateway  " .. (l[rest + 2] or "-") },
        { icon = g.dns, text = "DNS      " .. (l[rest + 3] or "-") },
        { icon = g.wifi, text = "Wi-Fi controls…", on_click = h.apple_menu("com.apple.menuextra.wifi") },
        { icon = g.gear, text = "Network settings…", on_click = settings("com.apple.Network-Settings.extension") },
      })
    end
  )
end, 280, "right")

---------------- volume ----------------
-- Open Apple's Sound menu; its native menu-bar extra is enabled in Nix.
local volume = right("volume", {
  icon = { padding_right = 6 },
  label = { drawing = false },
  updates = true,
})
h.hover(volume)
volume:subscribe("volume_change", function(env)
  local v = tonumber(env.INFO) or 0
  volume:set({ icon = { string = v == 0 and g.vol_mute or (v < 35 and g.vol_low or (v < 70 and g.vol_mid or g.vol_high)) } })
end)
volume:subscribe("mouse.clicked", h.apple_menu("com.apple.menuextra.sound"))
-- Scrolling is summed and applied once the wheel has been quiet for 80 ms,
-- instead of one osascript per tick.
local pending, scroll_gen = 0, 0
volume:subscribe("mouse.scrolled", function(env)
  local d = tonumber(env.INFO and env.INFO.delta or env.SCROLL_DELTA) or 0
  pending = pending + (d > 0 and 5 or -5)
  scroll_gen = scroll_gen + 1
  local mine = scroll_gen
  sbar.delay(0.08, function()
    if mine ~= scroll_gen or pending == 0 then return end
    local step = pending
    pending = 0
    sbar.exec("osascript -e 'set volume output volume (output volume of (get volume settings) + " .. step .. ")'")
  end)
end)

---------------- display ----------------
local display = right("display", {
  icon = { string = "\u{f0379}", padding_left = 6, padding_right = 6 },
  label = { drawing = false },
})
h.hover(display)
display:subscribe("mouse.clicked", h.apple_menu("com.apple.menuextra.display"))
---------------- keyboard layout (only with more than one) ----------------
local layout = right("layout", {
  updates = true,
  drawing = false,
  icon = { drawing = false },
  label = { font = h.font(t.small, "Bold"), padding_left = 6, padding_right = 6 },
})
h.hover(layout)
local SHORT = { ["U.S."] = "US", ABC = "US", British = "GB", ["Turkish-QWERTY-PC"] = "TR", ["Turkish-QWERTY"] = "TR",
                Turkish = "TR", German = "DE", French = "FR" }
layout:subscribe("mouse.clicked", function(env)
  if env.BUTTON == "right" then
    sbar.exec("open 'x-apple.systempreferences:com.apple.Keyboard-Settings.extension'")
  else
    sbar.exec(SBMENUS .. " -k") -- the input_change event then updates the label
  end
end)
sbar.add("event", "input_change", "AppleSelectedInputSourcesChangedNotification")
layout:subscribe({ "input_change", "forced", "system_woke" }, function()
  sbar.exec("defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleEnabledInputSources | grep -c 'KeyboardLayout Name'; "
    .. "defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources"
    .. " | awk -F'= ' '/KeyboardLayout Name/ {gsub(/[\";]/, \"\", $2); print $2; exit}'", function(out)
    local l = h.lines(out)
    local name = h.trim(l[2] or "")
    if name == "" then name = "U.S." end
    layout:set({ drawing = (tonumber(l[1]) or 0) > 1, label = { string = SHORT[name] or name:sub(1, 2):upper() } })
  end)
end)

h.sep("right")

---------------- tray: third-party menu bar icons ----------------
-- macOS draws these itself now; sbmenus finds each icon's owning app so we
-- can show a monochrome glyph for it here and click the real one.
local FALLBACK = {
  ["Kopuz"] = g.music,
  ["Macs Fan Control"] = g.fan,
  ["WakaTime"] = g.timer,
}
-- Native extras already represented by dedicated widgets are not duplicated.
local DEDICATED = {}
for _, name in ipairs({ "clock", "wifi", "battery", "sound", "display", "controlcenter" }) do
  DEDICATED["com.apple.menuextra." .. name] = true
end
local tray, tray_targets = {}, {}
local function ensure_tray(i)
  if tray[i] then return end
  local item = right("tray." .. i, {
    drawing = false,
    icon = { color = t.fg, padding_left = 4, padding_right = 4 },
    label = { drawing = false },
  })
  item:subscribe("mouse.clicked", function()
    if tray_targets[i] then h.close_popups(); sbar.exec(tray_targets[i]) end
  end)
  h.hover(item)
  tray[i] = item
end

local function tray_icon(name)
  local glyph = icon_map[name]
  if glyph then return glyph, "sketchybar-app-font:Regular:15.0", -1 end
  return FALLBACK[name] or g.app, h.font(t.glyph), 0
end

local tray_watch = right("tray.watch", { drawing = false, updates = true, update_freq = 180 })
local function scan_tray()
  sbar.exec(SBMENUS .. " -t", function(out)
    local apps, occurrences = {}, {}
    for _, line in ipairs(h.lines(out)) do
      local pid, name, bundle, title = line:match("^(%d+)\t([^\t]*)\t([^\t]*)\t(.*)$")
      if pid then
        local occurrence = occurrences[pid] or 0
        occurrences[pid] = occurrence + 1
        if not DEDICATED[bundle] then
          apps[#apps + 1] = {
            name = name ~= "" and name or title,
            target = tonumber(pid) == 0 and (SBMENUS .. " -i '" .. bundle:gsub("'", "'\\''") .. "'")
              or (SBMENUS .. " -x " .. pid .. " " .. occurrence),
          }
        end
      end
    end
    for i = 1, #apps do ensure_tray(i) end
    -- right-positioned: slot 1 is rightmost; keep the menu bar's order
    for i = 1, #tray do
      local a = apps[#apps - i + 1]
      tray_targets[i] = a and a.target or nil
      if a then
        local glyph, font, y = tray_icon(a.name)
        tray[i]:set({ drawing = true, icon = { string = glyph, font = font, y_offset = y } })
      else
        tray[i]:set({ drawing = false })
      end
    end
  end)
end
-- App launch/quit events are debounced so Accessibility can settle first.
local tray_generation = 0
tray_watch:subscribe("tray_change", function()
  tray_generation = tray_generation + 1
  local generation = tray_generation
  sbar.delay(0.5, function()
    if generation == tray_generation then scan_tray() end
  end)
end)
tray_watch:subscribe({ "routine", "forced", "system_woke" }, scan_tray)
sbar.delay(1, scan_tray)

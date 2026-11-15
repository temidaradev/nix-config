-- Follow the desktop theme (`shell-theme`): steinsgate <-> the configured
-- colorscheme. Watches ~/.local/state/quickshell for the theme file being
-- replaced, so open editors switch live too.
local M = {}
local dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/quickshell"
local file = dir .. "/theme"
local normal = vim.g.colors_name or "default"
local normal_lualine = "auto"

local sg_lualine = {
  normal = { a = { fg = "#160b03", bg = "#ff9e2c", gui = "bold" }, b = { fg = "#ffdcae", bg = "#2a1c10" }, c = { fg = "#a88760", bg = "#160e08" } },
  insert = { a = { fg = "#160b03", bg = "#8fb359", gui = "bold" } },
  visual = { a = { fg = "#160b03", bg = "#d48aa0", gui = "bold" } },
  replace = { a = { fg = "#160b03", bg = "#e8452c", gui = "bold" } },
  command = { a = { fg = "#160b03", bg = "#ffcc4d", gui = "bold" } },
  inactive = { a = { fg = "#967a5a", bg = "#160e08" }, b = { fg = "#967a5a", bg = "#160e08" }, c = { fg = "#967a5a", bg = "#0c0805" } },
}

local function read()
  local f = io.open(file, "r")
  if not f then return "normal" end
  local t = (f:read("*a") or ""):gsub("%s+", "")
  f:close()
  return t
end

local current
function M.apply()
  local mode = read() == "steinsgate" and "steinsgate" or "normal"
  if mode == current then return end
  current = mode
  pcall(vim.cmd.colorscheme, mode == "steinsgate" and "steinsgate" or normal)
  local ok, lualine = pcall(require, "lualine")
  if ok and lualine.get_config then
    local cfg = lualine.get_config()
    cfg.options = cfg.options or {}
    cfg.options.theme = mode == "steinsgate" and sg_lualine or normal_lualine
    pcall(lualine.setup, cfg)
  end
end

function M.setup()
  normal = vim.g.colors_name or normal
  local ok, lualine = pcall(require, "lualine")
  if ok and lualine.get_config then normal_lualine = (lualine.get_config().options or {}).theme or "auto" end
  vim.fn.mkdir(dir, "p")
  M.apply()
  local w = vim.uv.new_fs_event()
  if w then
    w:start(dir, {}, vim.schedule_wrap(function(_, name)
      if name == nil or name == "theme" then M.apply() end
    end))
  end
end

return M

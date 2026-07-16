vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

require("presence").setup({
    -- General options
    auto_update         = true,                      
    neovim_image_text   = "The One True Text Editor",    
    main_image          = "file",
    log_level           = nil,
    debounce_timeout    = 10,
    enable_line_number  = false,
    blacklist           = {},
    buttons             = true,
    file_assets         = {},
    show_time           = true,
    -- Rich Presence text options
    editing_text        = "Editing %s",
    file_explorer_text  = "Browsing %s",
    git_commit_text     = "Committing changes",
    plugin_manager_text = "Managing plugins",
    reading_text        = "Reading %s",
    workspace_text      = "Working on %s",
    line_number_text    = "Line %s out of %s",
})

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "autocmds"

vim.schedule(function()
  require "mappings"
end)

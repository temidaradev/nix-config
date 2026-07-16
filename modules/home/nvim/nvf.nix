{ pkgs, ... }:

{
  vim = {
    viAlias = true;
    vimAlias = true;

    globals.mapleader = " ";

    theme = {
      enable = true;
      name = "gruvbox";
      style = "dark";
    };

    options = {
      number = true;
      numberwidth = 2;
      ruler = false;

      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      softtabstop = 2;
      smartindent = true;

      ignorecase = true;
      smartcase = true;

      cursorline = true;
      signcolumn = "yes";
      splitright = true;
      splitbelow = true;
      mouse = "a";
      undofile = true;
      termguicolors = true;
      timeoutlen = 400;
      updatetime = 250;
      clipboard = "unnamedplus";
    };

    lsp.enable = true;

    languages = {
      enableTreesitter = true;
      enableFormat = true;

      rust = {
        enable = true;
        lsp.enable = false;
        dap.enable = false;
        format.enable = true;
        extensions.crates-nvim.enable = true;
        extensions.rustaceanvim.enable = true;
      };

      go = {
        enable = true;
        lsp.enable = true;
        dap.enable = true;
        format.enable = true;
      };

      haskell = {
        enable = true;
        lsp.enable = true;
        format = {
          enable = true;
          type = [ "fourmolu" ];
        };
      };

      lua = {
        enable = true;
        format.enable = true;
      };

      nix.enable = true;
      html.enable = true;
      css.enable = true;
    };

    statusline.lualine.enable = true;

    tabline.nvimBufferline = {
      enable = true;
      setupOpts.options = {
        mode = "buffers";
        numbers = "none";
        separator_style = "thin";
        always_show_bufferline = true;
        show_buffer_close_icons = true;
        show_close_icon = false;
        indicator = {
          style = "underline";
        };
        offsets = [
          {
            filetype = "NvimTree";
            text = "File Explorer";
            text_align = "center";
            separator = true;
          }
        ];
      };
    };

    telescope.enable = true;

    filetree.nvimTree = {
      enable = true;
      setupOpts = {
        view.width = 25;
        view.side = "left";
        view.preserve_window_proportions = true;
        # Snap the tree back to view.width after opening a file
        # (nvf defaults this to false, which lets the tree stay half-width).
        actions.open_file.resize_window = true;
        filters.dotfiles = false;
        renderer = {
          root_folder_label = false;
          highlight_git = false;
          indent_markers.enable = false;
          icons = {
            show = {
              file = true;
              folder = true;
              folder_arrow = true;
              git = false;
            };
            glyphs = {
              default = "󰈚";
              symlink = "";
              folder = {
                default = "";
                empty = "";
                empty_open = "";
                open = "";
                arrow_open = "";
                arrow_closed = "";
                symlink = "";
                symlink_open = "";
              };
            };
          };
        };
      };
    };
    autocomplete.nvim-cmp.enable = true;
    binds.whichKey.enable = true;
    git.gitsigns.enable = true;
    treesitter.enable = true;
    autopairs.nvim-autopairs.enable = true;
    comments.comment-nvim.enable = true;
    visuals.indent-blankline.enable = true;

    debugger.nvim-dap = {
      enable = true;
      ui.enable = true;
    };

    presence.neocord.enable = true;
    utility.vim-wakatime.enable = true;

    extraPlugins.claude-code = {
      package = pkgs.vimPlugins.claude-code-nvim;
      setup = "require('claude-code').setup()";
    };

    keymaps = [
      {
        mode = "n";
        key = ";";
        action = ":";
        desc = "CMD enter command mode";
      }
      {
        mode = "i";
        key = "jk";
        action = "<ESC>";
      }

      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
        desc = "Window left";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
        desc = "Window right";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
        desc = "Window down";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
        desc = "Window up";
      }

      {
        mode = "n";
        key = "<C-n>";
        action = "<cmd>NvimTreeToggle<CR>";
        desc = "Toggle file tree";
      }
      {
        mode = "n";
        key = "<Leader>e";
        action = "<cmd>NvimTreeFocus<CR>";
        desc = "Focus file tree";
      }

      {
        mode = "n";
        key = "<C-t>";
        action = "<cmd>!cargo check<CR>";
        desc = "cargo check";
      }
      {
        mode = "n";
        key = "<C-b>";
        action = "<cmd>!cargo build<CR>";
        desc = "cargo build";
      }

      {
        mode = "n";
        key = "<Leader>dl";
        action = "<cmd>lua require'dap'.step_into()<CR>";
        desc = "Debugger step into";
      }
      {
        mode = "n";
        key = "<Leader>dj";
        action = "<cmd>lua require'dap'.step_over()<CR>";
        desc = "Debugger step over";
      }
      {
        mode = "n";
        key = "<Leader>dk";
        action = "<cmd>lua require'dap'.step_out()<CR>";
        desc = "Debugger step out";
      }
      {
        mode = "n";
        key = "<Leader>dc";
        action = "<cmd>lua require'dap'.continue()<CR>";
        desc = "Debugger continue";
      }
      {
        mode = "n";
        key = "<Leader>db";
        action = "<cmd>lua require'dap'.toggle_breakpoint()<CR>";
        desc = "Debugger toggle breakpoint";
      }
      {
        mode = "n";
        key = "<Leader>dd";
        action = "<cmd>lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>";
        desc = "Debugger set conditional breakpoint";
      }
      {
        mode = "n";
        key = "<Leader>de";
        action = "<cmd>lua require'dap'.terminate()<CR>";
        desc = "Debugger reset";
      }
      {
        mode = "n";
        key = "<Leader>dr";
        action = "<cmd>lua require'dap'.run_last()<CR>";
        desc = "Debugger run last";
      }

      {
        mode = "n";
        key = "<Leader>dt";
        action = "<cmd>lua vim.cmd('RustLsp testables')<CR>";
        desc = "Debugger testables";
      }
      {
        mode = "n";
        key = "<Leader>dgt";
        action = "<cmd>lua require('dap-go').debug_test()<CR>";
        desc = "Debugger Go test";
      }
      {
        mode = "n";
        key = "<Leader>dgl";
        action = "<cmd>lua require('dap-go').debug_last_test()<CR>";
        desc = "Debugger Go last test";
      }
    ];
  };
}

-- Basic option settings
vim.opt.number = true -- Display line numbers
vim.opt.relativenumber = true -- Relative line numbers
vim.opt.tabstop = 4 -- Tab width
vim.opt.shiftwidth = 4 -- Indent width
vim.opt.expandtab = true -- Convert tabs to spaces
vim.opt.smartindent = true -- Smart indent
vim.opt.clipboard = 'unnamedplus' -- System clipboard integration
vim.opt.termguicolors = true -- True color support
vim.opt.mouse = 'a' -- Enable mouse
vim.opt.scrolloff = 5 -- Keep at least 5 lines below/above the cursor

-- Hide global statusline at the bottom to emphasize winbar
vim.opt.laststatus = 0  -- 0: No global statusline
vim.opt.cmdheight = 0   -- Hide cmdline (Neovim 0.8+)

-- Leader key setting (space as leader)
vim.g.mapleader = ' '

-- Keymap
vim.keymap.set('n', '<leader>e', ':Ex<CR>', { desc = 'File explorer' }) -- Open Netrw
vim.keymap.set('n', '<C-s>', ':w<CR>', { desc = 'Save' }) -- Ctrl+S to save

-- lazy.nvim installation (bootstrap)
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin settings (minimal for syntax highlighting)
require('lazy').setup({
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup {
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
      }
    end
  },
  {
    'projekt0n/github-nvim-theme',
    lazy = false, -- Load during startup
    priority = 1000, -- Load before other plugins
    config = function()
      require('github-theme').setup({
        -- Optional custom configurations
      })
      vim.cmd('colorscheme github_dark') -- Set to GitHub Dark theme (VS Code-like)
    end
  },
  {
    'nvim-lualine/lualine.nvim',
    config = function()
      require('lualine').setup {
        options = {
          theme = 'auto',  -- Automatic theme (follows colorscheme)
          section_separators = '',  -- Disable separators for simplicity
          component_separators = '',
        },
        winbar = {
          lualine_a = {'mode'},  -- Left: Mode
          lualine_b = {'filename'},  -- Center: Filename
          lualine_z = {'location'},  -- Right: Location (Ln x/y Col z)
        },
        inactive_winbar = {
          lualine_a = {'filename'},  -- Inactive: Filename only
        },
      }
    end
  },
})

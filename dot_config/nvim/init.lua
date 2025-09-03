-- init.lua: Complete Neovim Config with Enhanced Language Support (Go, Zig, Shell, Python, Lua) and macOS Clipboard Integration
-- Fixed: mason "zigfmt" package not found - Removed 'zigfmt' from mason-tool-installer (zigfmt is part of Zig toolchain, not Mason). Install Zig via brew install zig for 'zig fmt'.
-- Use 'zig fmt' in conform.nvim for Zig formatting.
-- mason-tool-installer ensures other tools (e.g., goimports, revive, etc.).

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
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

-- Leader key
vim.g.mapleader = ' '

-- Core options (simplified)
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.clipboard = 'unnamedplus'  -- System clipboard integration (macOS compatible)
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.scrolloff = 8
vim.opt.mouse = 'a'
vim.opt.termguicolors = true
vim.opt.laststatus = 3  -- Global statusline for better LSP info

-- macOS-specific clipboard provider (ensures pbcopy/pbpaste usage)
if vim.fn.has('mac') == 1 then
  vim.g.clipboard = {
    name = 'macOS-clipboard',
    copy = {
      ['+'] = 'pbcopy',
      ['*'] = 'pbcopy',
    },
    paste = {
      ['+'] = 'pbpaste',
      ['*'] = 'pbpaste',
    },
    cache_enabled = true,
  }
end

-- Keymaps
vim.keymap.set('n', '<Esc><Esc>', ':nohlsearch<CR><Esc>', { silent = true })
vim.keymap.set('n', '<leader>e', ':Oil<CR>', { desc = 'File explorer' })
vim.keymap.set('n', '<C-s>', ':w<CR>', { desc = 'Save' })

-- Plugins
require('lazy').setup({
  -- Treesitter: Syntax highlighting, indent (parsers for all languages)
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup {
        ensure_installed = { 'go', 'zig', 'bash', 'python', 'lua', 'vimdoc' },  -- Includes Lua
        highlight = { enable = true },
        indent = { enable = true },
      }
    end
  },
  -- Theme
  {
    'projekt0n/github-nvim-theme',
    lazy = false,
    priority = 1000,
    config = function()
      require('github-theme').setup({})
      vim.cmd('colorscheme github_dark')
    end
  },
  -- Statusline
  {
    'nvim-lualine/lualine.nvim',
    config = function()
      require('lualine').setup {
        options = { theme = 'auto' },
        sections = {
          lualine_c = { 'filename' },
          lualine_x = { 'diagnostics' },  -- LSP diagnostics
        },
      }
    end
  },
  -- Git signs
  { 'lewis6991/gitsigns.nvim', config = true },
  -- Fuzzy finder
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
    end
  },
  -- Completion
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
    },
    config = function()
      local cmp = require('cmp')
      cmp.setup({
        snippet = { expand = function(args) require('luasnip').lsp_expand(args.body) end },
        mapping = cmp.mapping.preset.insert({
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
        },
      })
    end
  },
  -- LSP: Core + mason (updated to latest API without setup_handlers)
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',  -- Install linters/formatters
    },
    config = function()
      local lspconfig = require('lspconfig')
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      require('mason').setup()
      require('mason-lspconfig').setup({
        ensure_installed = {
          'gopls',       -- Go
          'zls',         -- Zig (for linting; zig-lamp handles LSP)
          'bashls',      -- Shell
          'pyright',     -- Python
          'lua_ls',      -- Lua
        },
        automatic_installation = true,
      })
      require('mason-tool-installer').setup({
        ensure_installed = {
          'goimports',      -- Go formatter
          'shfmt', 'shellcheck',    -- Shell
          'ruff',           -- Python
          'stylua', 'luacheck',     -- Lua
          'revive',         -- Go linter
        },
      })
      -- Individual LSP setups (replaces setup_handlers)
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = {
          Lua = {
            runtime = { version = 'LuaJIT' },
            diagnostics = { globals = { 'vim' } },
            workspace = {
              library = vim.api.nvim_get_runtime_file('', true),
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      })
      lspconfig.pyright.setup({
        capabilities = capabilities,
        settings = {
          python = {
            analysis = { autoSearchPaths = true, useLibraryCodeForTypes = true },
          },
        },
      })
      lspconfig.gopls.setup({
        capabilities = capabilities,
        settings = {
          gopls = {
            analyses = { unusedparams = true },
            staticcheck = true,
          },
        },
      })
      lspconfig.bashls.setup({ capabilities = capabilities })
      lspconfig.zls.setup({ capabilities = capabilities })  -- For Zig linting fallback
      -- LSP keymaps
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local bufnr = args.buf
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, { buffer = bufnr })
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, { buffer = bufnr })
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = bufnr })
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { buffer = bufnr })
        end,
      })
    end
  },
  -- Formatting (conform.nvim) - Use 'zig fmt' for Zig (requires Zig installed)
  {
    'stevearc/conform.nvim',
    config = function()
      require('conform').setup({
        format_on_save = { timeout_ms = 500, lsp_format = 'fallback' },
        formatters_by_ft = {
          go = { 'goimports' },  -- Use goimports (includes gofmt functionality)
          zig = { 'zig fmt' },  -- Use zig fmt (install Zig via brew install zig)
          sh = { 'shfmt' },
          python = { 'ruff_format' },
          lua = { 'stylua' },  -- Lua formatter
        },
      })
    end
  },
  -- Linting (nvim-lint)
  {
    'mfussenegger/nvim-lint',
    config = function()
      require('lint').linters_by_ft = {
        go = { 'revive' },
        zig = { 'zls' },
        sh = { 'shellcheck' },
        python = { 'ruff' },
        lua = { 'luacheck' },  -- Install luacheck: luarocks install luacheck
      }
      vim.api.nvim_create_autocmd({ 'BufWritePost', 'InsertLeave' }, {
        callback = function() require('lint').try_lint() end,
      })
    end
  },
  -- Zig-specific (zig-lamp with proper setup)
  {
    'jinzhongjia/zig-lamp',
    event = 'VeryLazy',
    build = ':ZigLamp build sync',
    dependencies = { 'neovim/nvim-lspconfig', 'nvim-lua/plenary.nvim' },
    init = function()
      -- Optional settings (defaults from docs)
      vim.g.zig_lamp_zls_auto_install = nil  -- Disable auto-install if needed
      vim.g.zig_lamp_fall_back_sys_zls = nil
      vim.g.zig_lamp_zls_lsp_opt = {}
      vim.g.zig_lamp_pkg_help_fg = "#CF5C00"
      vim.g.zig_lamp_zig_fetch_timeout = 5000
    end,
  },
  -- Go-specific
  { 'ray-x/go.nvim', config = true },
  -- File explorer
  { 'stevearc/oil.nvim', config = true },
  -- Comments
  { 'numToStr/Comment.nvim', config = true },
  -- Indent guides
  { 'lukas-reineke/indent-blankline.nvim', main = 'ibl', config = true },
  -- Rainbow delimiters
  { 'HiPhish/rainbow-delimiters.nvim' },
})

-- Filetype specifics
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'go',
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'sh',
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
  end,
})
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'zig',
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'lua',
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
  end,
})

vim.cmd('filetype plugin indent on')
vim.cmd('syntax enable')
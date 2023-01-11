local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data') .. '/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({ 'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path })
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

require('packer').startup(function(use)
  -- Package manager
  use 'wbthomason/packer.nvim'

  use { -- LSP Configuration & Plugins
    'neovim/nvim-lspconfig',
    requires = {
      -- Automatically install LSPs to stdpath for neovim
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',

      -- Useful status updates for LSP
      'j-hui/fidget.nvim',

      -- Additional lua configuration, makes nvim stuff amazing
      'folke/neodev.nvim',
    },
  }

  use { -- Autocompletion
    'hrsh7th/nvim-cmp',
    requires = { 'hrsh7th/cmp-nvim-lsp', 'L3MON4D3/LuaSnip', 'saadparwaiz1/cmp_luasnip' },
  }

  use { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    run = function()
      pcall(require('nvim-treesitter.install').update { with_sync = true })
    end,
  }

  use { -- Additional text objects via treesitter
    'nvim-treesitter/nvim-treesitter-textobjects',
    after = 'nvim-treesitter',
  }

  -- hop hop
  -- why you no work
  use {
    'ggandor/leap.nvim',
    config = function() require ('leap').set_default_keymaps() end
  }

  -- Git related plugins
  use 'tpope/vim-fugitive'
  use 'lewis6991/gitsigns.nvim'
  use {
    'notjedi/nvim-rooter.lua',
    config = function() require 'nvim-rooter'.setup() end
  }

  use 'gruvbox-community/gruvbox'
  use 'nvim-lualine/lualine.nvim' -- Fancier statusline
  use 'lukas-reineke/indent-blankline.nvim' -- Add indentation guides even on blank lines
  use 'numToStr/Comment.nvim' -- "gc" to comment visual regions/lines
  use 'tpope/vim-sleuth' -- Detect tabstop and shiftwidth automatically

  -- Fuzzy Finder (files, lsp, etc)
  use { 'ibhagwan/fzf-lua' }

  use 'nvim-tree/nvim-tree.lua'

  -- Add custom plugins to packer from ~/.config/nvim/lua/custom/plugins.lua
  local has_plugins, plugins = pcall(require, 'custom.plugins')
  if has_plugins then
    plugins(use)
  end

  if packer_bootstrap then
    require('packer').sync()
  end
end)

-- When we are bootstrapping a configuration, it doesn't
-- make sense to execute the rest of the init.lua.
--
-- You'll need to restart nvim, and then it will work.
if packer_bootstrap then
  print '=================================='
  print '    Plugins are being installed'
  print '    Wait until Packer completes,'
  print '       then restart nvim'
  print '=================================='
  return
end

-- Automatically source and re-compile packer whenever you save this init.lua
local packer_group = vim.api.nvim_create_augroup('Packer', { clear = true })
vim.api.nvim_create_autocmd('BufWritePost', {
  command = 'source <afile> | silent! LspStop | silent! LspStart | PackerCompile',
  group = packer_group,
  pattern = vim.fn.expand '$MYVIMRC',
})

-- [[ Setting options ]]
-- See `:help vim.o`
-- disable netrw at the very start of your init.lua (strongly advised)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.o.autoindent     = true -- Indent newlines automatically
vim.o.breakindent    = true -- Enable break indent
vim.o.clipboard      = 'unnamedplus' -- Always use system clipboard for cut/copy
vim.o.colorcolumn    = '100' -- color colorcolumn
vim.o.cursorline     = true -- Highlight the line the Cursor is on
vim.o.expandtab      = true -- Indent tabs as spaces
vim.o.guifont        = 'Hack:h10' -- Font and size in GUI:s
vim.o.hidden         = true -- Keep unsaved data and undo information when switching buffers
vim.o.hlsearch       = false -- Set highlight on search
vim.o.ignorecase     = true -- Search is not case-sensitive
vim.o.linebreak      = true -- Break long lines by word-boundaries instead of in the middle of word
vim.o.mouse          = 'a' -- Enable mouse mode
vim.o.number         = true -- Make line numbers default
vim.o.relativenumber = true
vim.o.scrolloff      = 999 -- Cursor centered-ish
vim.o.shiftwidth     = 0 -- Indent with cindent the same amount of characters as tabstop
vim.o.shiftwidth     = 0 -- Indent with cindent the same amount of characters as tabstop
vim.o.showcmd        = true -- Show count of marked lines in bottom right
vim.o.smartcase      = true -- Search is case sensitive when searching for words with capital letters
vim.o.smartcase      = true -- Search is case sensitive when searching for words with capital letters
vim.o.softtabstop    = -1 -- Indent is removed with same amount of characters as tabstop
vim.o.tabstop        = 2 -- Indent with 2 spaces
vim.o.termguicolors  = true -- Enables truecolor support
vim.o.termguicolors  = true -- set termguicolors to enable highlight groups
vim.o.undofile       = true -- Save undo history
vim.o.updatetime     = 300 -- Wait 300 milliseconds for saving swap files and cursorhold autocommand
vim.o.wildmenu       = true -- Better completion mode
vim.o.wildmode       = 'full' -- Complete to first word'

-- Decrease update time
vim.o.updatetime = 250
vim.wo.signcolumn = 'yes'

-- Set colorscheme
vim.o.termguicolors = true
vim.o.background = 'dark'
if not packer_bootstrap then
  vim.cmd [[colorscheme gruvbox]]
end

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- [[ Basic Keymaps ]]
-- Set <space> as the leader key
-- See `:help mapleader`
--  NOTE: Must happen before plugins are required (otherwise wrong leader will be used)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local highlight_group = vim.api.nvim_create_augroup('YankHighlight', { clear = true })
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = highlight_group,
  pattern = '*',
})

-- Set lualine as statusline
-- See `:help lualine.txt`
require('lualine').setup {
  options = {
    icons_enabled = false,
    theme = 'gruvbox',
    component_separators = '|',
    section_separators = '',
  },
}

-- Enable Comment.nvim
require('Comment').setup()

-- Enable `lukas-reineke/indent-blankline.nvim`
-- See `:help indent_blankline.txt`
require('indent_blankline').setup {
  char = '┊',
  show_trailing_blankline_indent = false,
}

-- Gitsigns
-- See `:help gitsigns.txt`
require('gitsigns').setup {
  signs = {
    add = { text = '+' },
    change = { text = '~' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
  },
}

vim.keymap.set('n', '<leader>ft', ':NvimTreeFindFileToggle<CR>', { desc = 'Open [f]ile [t]ee' })
vim.keymap.set('n', '<leader>ff', ':NvimTreeFindFileToggle<CR>', { desc = '[f]ind [f]ile' })


vim.keymap.set('n', '<leader>s/', require('fzf-lua').search_history, { desc = '[S]earch history[/]' })
vim.keymap.set('n', '<leader>s;', require('fzf-lua').commands, { desc = '[S]earch commands[;]' })
vim.keymap.set('n', '<leader>sb', require('fzf-lua').blines, { desc = '[S]earch current [b]uffer' })
vim.keymap.set('n', '<leader>sB', require('fzf-lua').buffers, { desc = '[S]earch Open [B]uffers' })
vim.keymap.set('n', '<leader>sf', require('fzf-lua').files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>sg', require('fzf-lua').git_files, { desc = '[S]earch in [g]it files' })
vim.keymap.set('n', '<leader>sG', require('fzf-lua').git_status, { desc = '[S]earch in [G]it status' })
vim.keymap.set('n', '<leader>sh', require('fzf-lua').oldfiles, { desc = '[S]earch in [h]istory' })
vim.keymap.set('n', '<leader>st', require('fzf-lua').grep_project, { desc = '[S]earch in [p]roject' })
vim.keymap.set('n', '<leader>sC', require('fzf-lua').git_bcommits, { desc = '[S]earch git [C]ommit log (buffers)' })
vim.keymap.set('n', '<leader>sc', require('fzf-lua').git_bcommits, { desc = '[S]earch git [c]ommit log (project)' })
vim.keymap.set('n', '<leader>sH', require('fzf-lua').command_history, { desc = '[S]earch command [H]istory' })
vim.keymap.set('n', '<leader>sl', require('fzf-lua').lines, { desc = '[S]earch open buffers [l]ines' })

vim.keymap.set('n', '<leader>sa', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':Ag'           , 'text Ag'],
vim.keymap.set('n', '<leader>sM', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':Maps'         , 'normal maps'] ,
vim.keymap.set('n', '<leader>sm', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':Marks'        , 'marks'] ,
vim.keymap.set('n', '<leader>sp', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':Helptags'     , 'help tags'] ,
vim.keymap.set('n', '<leader>sP', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':Tags'         , 'project tags'],
vim.keymap.set('n', '<leader>sS', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':Colors'       , 'color schemes'],
vim.keymap.set('n', '<leader>ss', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':Snippets'     , 'snippets'],
vim.keymap.set('n', '<leader>sT', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':BTags'        , 'buffer tags'],
vim.keymap.set('n', '<leader>sw', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':Windows'      , 'search windows'],
vim.keymap.set('n', '<leader>sy', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':Filetypes'    , 'file types'],
vim.keymap.set('n', '<leader>sz', function() print('Not implemented yet') end, { desc = 'not implemented yet' }) -- [':FZF'          , 'FZF'],

-- [[ Configure nvim-tree ]]
require("nvim-tree").setup({
  sort_by = "case_sensitive",
  actions = {
    open_file = {
      quit_on_open = true,
    },
  },
  view = {
    adaptive_size = true,
    mappings = {
      list = {
        { key = "u", action = "dir_up" },
      },
    },
  },
  renderer = {
    group_empty = true,
    highlight_git = true,
    icons = {
      show = {
        git = true,
        file = true,
        folder = true,
        folder_arrow = true
      }
    }
  },
  filters = {
    dotfiles = true,
  },
})

-- [[ Configure nvim-rooter ]]
require('nvim-rooter').setup {
  rooter_patterns = { '.git' },
  trigger_patterns = { '*' },
  manual = false,
}

-- [[ Configure Treesitter ]]
-- See `:help nvim-treesitter`
require('nvim-treesitter.configs').setup {
  -- Add languages to be installed here that you want installed for treesitter
  ensure_installed = { 'c', 'cpp', 'go', 'lua', 'python', 'rust', 'typescript', 'help' },

  highlight = { enable = true },
  indent = { enable = true, disable = { 'python' } },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = '<c-space>',
      node_incremental = '<c-space>',
      scope_incremental = '<c-s>',
      node_decremental = '<c-backspace>',
    },
  },
  textobjects = {
    select = {
      enable = true,
      lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ['aa'] = '@parameter.outer',
        ['ia'] = '@parameter.inner',
        ['af'] = '@function.outer',
        ['if'] = '@function.inner',
        ['ac'] = '@class.outer',
        ['ic'] = '@class.inner',
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        [']m'] = '@function.outer',
        [']]'] = '@class.outer',
      },
      goto_next_end = {
        [']M'] = '@function.outer',
        [']['] = '@class.outer',
      },
      goto_previous_start = {
        ['[m'] = '@function.outer',
        ['[['] = '@class.outer',
      },
      goto_previous_end = {
        ['[M'] = '@function.outer',
        ['[]'] = '@class.outer',
      },
    },
    swap = {
      enable = true,
      swap_next = {
        ['<leader>a'] = '@parameter.inner',
      },
      swap_previous = {
        ['<leader>A'] = '@parameter.inner',
      },
    },
  },
}

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)

-- LSP settings.
--  This function gets run when an LSP connects to a particular buffer.
local on_attach = function(_, bufnr)
  -- NOTE: Remember that lua is a real programming language, and as such it is possible
  -- to define small helper and utility functions so you don't have to repeat yourself
  -- many times.
  --
  -- In this case, we create a function that lets us more easily define mappings specific
  -- for LSP related items. It sets the mode, buffer and description for us each time.
  local nmap = function(keys, func, desc)
    if desc then
      desc = 'LSP: ' .. desc
    end

    vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
  end

  nmap('<leader>cr', vim.lsp.buf.rename, '[C]ode [R]ename')
  nmap('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
  nmap('<leader>cf', ':Format<CR>', '[C]ode [F]ormat')

  nmap('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
  nmap('gr', require('fzf-lua').lsp_references, '[G]oto [R]eferences')
  nmap('gI', vim.lsp.buf.implementation, '[G]oto [I]mplementation')
  nmap('<leader>D', vim.lsp.buf.type_definition, 'Type [D]efinition')
  nmap('<leader>ds', require('fzf-lua').lsp_document_symbols, '[D]ocument [S]ymbols')
  nmap('<leader>ws', require('fzf-lua').lsp_live_workspace_symbols, '[W]orkspace [S]ymbols')

  -- See `:help K` for why this keymap
  nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
  nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

  -- Lesser used LSP functionality
  nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
  nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
  nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
  nmap('<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, '[W]orkspace [L]ist Folders')

  -- Create a command `:Format` local to the LSP buffer
  vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
    vim.lsp.buf.format()
  end, { desc = 'Format current buffer with LSP' })
end

-- Enable the following language servers
--  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
--
--  Add any additional override configuration in the following tables. They will be passed to
--  the `settings` field of the server config. You must look up that documentation yourself.
local servers = {
  -- clangd = {},
  -- gopls = {},
  -- pyright = {},
  rust_analyzer = {},
  tsserver = {},

  sumneko_lua = {
    Lua = {
      workspace = { checkThirdParty = false },
      telemetry = { enable = false },
    },
  },
}

-- Setup neovim lua configuration
require('neodev').setup()
--
-- nvim-cmp supports additional completion capabilities, so broadcast that to servers
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Setup mason so it can manage external tooling
require('mason').setup()

-- Ensure the servers above are installed
local mason_lspconfig = require 'mason-lspconfig'

mason_lspconfig.setup {
  ensure_installed = vim.tbl_keys(servers),
}

mason_lspconfig.setup_handlers {
  function(server_name)
    require('lspconfig')[server_name].setup {
      capabilities = capabilities,
      on_attach = on_attach,
      settings = servers[server_name],
    }
  end,
}

-- Turn on lsp status information
require('fidget').setup()

-- nvim-cmp setup
local cmp = require 'cmp'
local luasnip = require 'luasnip'

cmp.setup {
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert {
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<CR>'] = cmp.mapping.confirm {
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    },
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { 'i', 's' }),
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
  },
}

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et

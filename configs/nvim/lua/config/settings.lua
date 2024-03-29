-- [[ General vim settings ]]
vim.g.mapleader = ' '                   -- map leader key
vim.g.maplocalleader = ' '
vim.g.loaded_netrw = 1                  -- Disable netrw
vim.g.loaded_netrwPlugin = 1            -- Disable netrw

vim.o.autoindent     = true             -- Indent newlines automatically
vim.o.background = 'dark'
vim.o.breakindent    = true             -- Enable break indent
vim.o.clipboard      = 'unnamedplus'    -- Always use system clipboard for cut/copy
vim.o.colorcolumn    = '100'            -- color colorcolumn
vim.o.completeopt = 'menuone,noselect'
vim.o.cursorline     = true             -- Highlight the line the Cursor is on
vim.o.expandtab      = true             -- Indent tabs as spaces
vim.o.guifont        = 'Hack:h10'       -- Font and size in GUI:s
vim.o.hidden         = true             -- Keep unsaved data and undo information when switching buffers
vim.o.hlsearch       = false            -- Set highlight on search
vim.o.ignorecase     = true             -- Search is not case-sensitive
vim.o.linebreak      = true             -- Break long lines by word-boundaries instead of in the middle of word
vim.o.mouse          = 'a'              -- Enable mouse mode
vim.o.number         = true             -- Make line numbers default
vim.o.relativenumber = false
vim.o.scrolloff      = 999              -- Cursor centered-ish
vim.o.shiftwidth     = 0                -- Indent with cindent the same amount of characters as tabstop
vim.o.shiftwidth     = 0                -- Indent with cindent the same amount of characters as tabstop
vim.o.showcmd        = true             -- Show count of marked lines in bottom right
vim.o.smartcase      = true             -- Search is case sensitive when searching for words with capital letters
vim.o.smartcase      = true             -- Search is case sensitive when searching for words with capital letters
vim.o.softtabstop    = -1               -- Indent is removed with same amount of characters as tabstop
vim.o.tabstop        = 2                -- Indent with 2 spaces
vim.o.termguicolors  = true             -- Enables truecolor support
vim.o.title = true
vim.o.undofile       = true             -- Save undo history
vim.o.updatetime     = 300              -- Wait 300 milliseconds for saving swap files and cursorhold autocommand
vim.o.updatetime = 250
vim.o.wildmenu       = true             -- Better completion mode
vim.o.wildmode       = 'full'           -- Complete to first word'

vim.wo.signcolumn = 'yes'

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


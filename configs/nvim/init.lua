local opt = vim.opt
local o = vim.o
local g = vim.g

-------------------------------------- globals -----------------------------------------
g.toggle_theme_icon = "   "

-------------------------------------- options ------------------------------------------
o.laststatus = 3
o.showmode = false

o.clipboard = "unnamedplus"
o.cursorline = true
o.cursorlineopt = "number"
o.colorcolumn = "100"

-- Indenting
o.expandtab = true
o.shiftwidth = 2
o.smartindent = true
o.tabstop = 2
o.softtabstop = 2

opt.fillchars = { eob = " " }
o.ignorecase = true
o.smartcase = true
o.mouse = "a"

-- Numbers
o.number = true
o.relativenumber = true

o.numberwidth = 2
o.ruler = true

-- disable nvim intro
opt.shortmess:append "sI"

o.signcolumn = "yes"
o.splitbelow = true
o.splitright = true
o.timeoutlen = 400
o.undofile = true

o.updatetime = 250

g.mapleader = " "       -- Make sure to set `mapleader` before lazy so your mappings are correct
g.maplocalleader = "\\" -- Same for `maplocalleader`

-------------------------------------- Plugin Manager ------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local opts = {}

require("lazy").setup("plugins", opts)

local builtin = require("telescope.builtin")
-- find
vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
vim.keymap.set("n", "<leader>fb", builtin.buffers, {})

vim.keymap.set("n", "gd", function() builtin.lsp_definitions({ reuse_win = true }) end)
vim.keymap.set("n", "gr", "<cmd>Telescope lsp_references<cr>")
vim.keymap.set("n", "gI", function() builtin.lsp_implementations({ reuse_win = true }) end)
vim.keymap.set("n", "gy", function() builtin.lsp_type_definitions({ reuse_win = true }) end)

vim.keymap.set("n", "<leader>ee", ":Neotree filesystem reveal float<CR>")

vim.cmd.colorscheme("tokyonight-night")

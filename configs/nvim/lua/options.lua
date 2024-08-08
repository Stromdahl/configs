local opt = vim.opt
local g = vim.g

-------------------------------------- globals -----------------------------------------
g.toggle_theme_icon = "   "

-------------------------------------- options ------------------------------------------
opt.laststatus = 3
opt.showmode = false

opt.clipboard = "unnamedplus"
opt.cursorline = true
opt.cursorlineopt = "both"
opt.colorcolumn = "100"
opt.scrolloff = 999

opt.virtualedit = 'block'
opt.inccommand = "split"

-- Indenting
opt.expandtab = true
opt.shiftwidth = 2
opt.smartindent = true
opt.tabstop = 2
opt.softtabstop = 2

opt.fillchars = { eob = " " }
opt.ignorecase = true
opt.smartcase = true
opt.mouse = "a"

-- Numbers
opt.number = true
opt.relativenumber = true

opt.numberwidth = 2
opt.ruler = true

-- disable nvim intro
opt.shortmess:append "sI"

opt.signcolumn = "yes"
opt.splitbelow = true
opt.splitright = true
opt.timeoutlen = 400
opt.undofile = true

opt.updatetime = 250

g.mapleader = " "       -- Make sure to set `mapleader` before lazy so your mappings are correct
g.maplocalleader = "\\" -- Same for `maplocalleader`

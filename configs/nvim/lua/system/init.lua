-- -- -- --
-- set leader (NEEDS TO BE BEFORE PLUGIN MANAGER)
-- -- -- --
vim.g.mapleader = require('ms.keymap').leader.leader
vim.g.maplocalleader = require('ms.keymap').leader.localleader

-- -- -- --
-- Load lazy.nvim plugin manager
-- -- -- --
require('system.lazy')

-- -- -- --
-- Setup lsp
-- -- -- --
require('ms.lsp')

-- -- -- --
-- Set vim options
-- -- -- --
require('ms.options')

-- -- -- --
-- Set autocmds keymaps
-- -- -- --
require('ms.autocmds')

-- -- -- --
-- Set cursomt user commands
-- -- -- --
require('ms.user_commands')

-- -- -- --
-- Set general keymaps
-- -- -- --
require('system.keys')


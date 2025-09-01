local M = {};
--
-- -- -- --
-- General 
-- -- -- --
-- All keybinds except general vim keybinds should be loaded by lazy 
-- e.g plugins/fzflua.lua {..., keys = require('ms.keymap').fzf_lua}

M.leader = {
  leader = ' ',
  localleader = '//'
}

M.vim = {
  {"<C-g>d", function () require('ms.utils').definition_split() end, desc='open definition in split window', noremap = true, silent = true },
  {"tp", '<CMD>TermExec cmd="cd %:p:h" go_back=0<CR>'},
  {"<leader>bd", '<CMD>CloseBufKeepWin<CR>'},
}


M.lsp = {
  -- TODO: Move lsp keymaps here
}

M.oil = {
  -- {"-", "<CMD>Oil --float<CR>", desc = "Open parent directory"}
  {"<leader>ft", "<CMD>Oil --float<CR>", desc = "Open parent directory"}
}

M.fzf_lua  = {
    {"-", function() require('fzf-lua').files({cwd = '%:p:h'}) end, desc = "Open parent directory"},
    { '<leader><leader>', function() require('fzf-lua').files() end, desc="[f]ind [f]file" },
    { '<leader>ff', function() require('fzf-lua').files() end, desc="[f]ind [f]file"},
    { '<leader>fc', function() require('fzf-lua').files({cwd = '%:p:h'}) end, desc="[f]ind [f]file"},
    { '<leader>fg', function() require('fzf-lua').live_grep() end, desc="[[f]ind files by [g]rep]"},
    { '<leader>bb', function() require('fzf-lua').buffers() end, desc="[[f]ind in [b]uffer]"},
    { '<leader>bb', function() require('fzf-lua').buffers() end, desc="[[f]ind in [b]uffer]"},
    { '<leader>/', function() require('fzf-lua').grep_curbuf() end, desc="Grep in current buffer"}
}

M.toggleterm  = {

}


-- -- -- --
-- Plugin Keybinds
-- -- -- --

-- vim.fn.expand('%:p:h') 
return M

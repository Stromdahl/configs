local M = {};

M.leader = {
  leader = ' ',
  localleader = '//'
}

M.vim = {
  -- TODO: Move general vim keymaps here
}

M.lsp = {
  -- TODO: Move lsp keymaps here
}

M.oil = {
  {"-", "<CMD>Oil --float<CR>", desc = "Open parent directory"}
}

M.fzf_lua  = {
    { '<leader><leader>', function() require('fzf-lua').files() end, desc="[f]ind [f]file" },
    { '<leader>ff', function() require('fzf-lua').files() end, desc="[f]ind [f]file"},
    { '<leader>fc', function() require('fzf-lua').files({cwd = '%:p:h'}) end, desc="[f]ind [f]file"},
    { '<leader>fg', function() require('fzf-lua').live_grep() end, desc="[[f]ind files by [g]rep]"},
    { '<leader>fb', function() require('fzf-lua').buffers() end, desc="[[f]ind in [b]uffer]"},
    { '<leader>/', function() require('fzf-lua').grep_curbuf() end, desc="Grep in current buffer"}
}

-- vim.fn.expand('%:p') 
return M

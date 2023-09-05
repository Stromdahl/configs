
local map = vim.keymap.set
local fzf_lua = require('fzf-lua')

local function todo() print('Not implemented yet') end


local keymaps = {
  { mode = 'n', keys = '<leader>ff', command = ':NvimTreeFindFileToggle<CR>', desc = '[f]ind [f]ile'},
}

map('n', '<C-d>', '30j', { desc = '[f]ind [f]ile' })
map('n', '<C-u>', '30k', { desc = '[f]ind [f]ile' })
map('n', '<leader>ff', ':NvimTreeFindFileToggle<CR>', { desc = '[f]ind [f]ile' })

map('n', '<leader>dn', ':lua vim.diagnostic.goto_next()<CR>', { desc = 'next diagnostic' })
map('n', '<leader>dp', ':lua vim.diagnostic.goto_prev()<CR>', { desc = 'previous diagnostic' })
map('n', '<leader>do', ':lua vim.diagnostic.open_float()<CR>', { desc = 'open diagnostic' })
map('n', '<leader>dn', ':lua vim.diagnostic.goto_next()<CR>', { desc = 'next diagnostic' })
map('n', '<leader>dp', ':lua vim.diagnostic.goto_prev()<CR>', { desc = 'previous diagnostic' })
map('n', '<leader>do', ':lua vim.diagnostic.open_float()<CR>', { desc = 'open diagnostic' })

map('n', '<leader>ft', ':NvimTreeFindFileToggle<CR>', { desc = 'Open [f]ile [t]ee' })
map('n', '<leader>ff', ':NvimTreeFindFileToggle<CR>', { desc = '[f]ind [f]ile' })

map('n', '<leader>s/', fzf_lua.search_history, { desc = '[S]earch history[/]' })
map('n', '<leader>s;', fzf_lua.commands, { desc = '[S]earch commands[;]' })
map('n', '<leader>sb', fzf_lua.blines, { desc = '[S]earch current [b]uffer' })
map('n', '<leader>sB', fzf_lua.buffers, { desc = '[S]earch Open [B]uffers' })
map('n', '<leader>sf', fzf_lua.files, { desc = '[S]earch [F]iles' })
map('n', '<leader>sg', fzf_lua.git_files, { desc = '[S]earch in [g]it files' })
map('n', '<leader>sG', fzf_lua.git_status, { desc = '[S]earch in [G]it status' })
map('n', '<leader>sh', fzf_lua.oldfiles, { desc = '[S]earch in [h]istory' })
map('n', '<leader>st', fzf_lua.grep_project, { desc = '[S]earch in [p]roject' })
map('n', '<leader>sC', fzf_lua.git_bcommits, { desc = '[S]earch git [C]ommit log (buffers)' })
map('n', '<leader>sc', fzf_lua.git_bcommits, { desc = '[S]earch git [c]ommit log (project)' })
map('n', '<leader>sH', fzf_lua.command_history, { desc = '[S]earch command [H]istory' })
map('n', '<leader>sl', fzf_lua.lines, { desc = '[S]earch open buffers [l]ines' })

map('n', '<leader>sa', todo, { desc = 'not implemented yet' }) -- [':Ag'           , 'text Ag'],
map('n', '<leader>sM', todo, { desc = 'not implemented yet' }) -- [':Maps'         , 'normal maps'] ,
map('n', '<leader>sm', todo, { desc = 'not implemented yet' }) -- [':Marks'        , 'marks'] ,
map('n', '<leader>sp', todo, { desc = 'not implemented yet' }) -- [':Helptags'     , 'help tags'] ,
map('n', '<leader>sP', todo, { desc = 'not implemented yet' }) -- [':Tags'         , 'project tags'],
map('n', '<leader>sS', todo, { desc = 'not implemented yet' }) -- [':Colors'       , 'color schemes'],
map('n', '<leader>ss', todo, { desc = 'not implemented yet' }) -- [':Snippets'     , 'snippets'],
map('n', '<leader>sT', todo, { desc = 'not implemented yet' }) -- [':BTags'        , 'buffer tags'],
map('n', '<leader>sw', todo, { desc = 'not implemented yet' }) -- [':Windows'      , 'search windows'],
map('n', '<leader>sy', todo, { desc = 'not implemented yet' }) -- [':Filetypes'    , 'file types'],
map('n', '<leader>sz', todo, { desc = 'not implemented yet' }) -- [':FZF'          , 'FZF'],

map('n', '<leader>H', ':HopWord<CR>', { desc = '[H]op word' })
map('n', '<leader>h', ':HopChar2<CR>', { desc = '[h]op char' })
-- map('n', '<leader>h', hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true }), { desc = '[h]op' })
--

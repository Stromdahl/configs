-- Description: Keymaps

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


-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)

-- See `:help vim.keymap.set()`
vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- Diagnostic keymaps
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)



vim.keymap.set('n', '<leader>ff', ':NvimTreeFindFileToggle<CR>', { desc = '[f]ind [f]ile' })

vim.keymap.set('n', '<leader>dn', ':lua vim.diagnostic.goto_next()<CR>', { desc = 'next diagnostic' })
vim.keymap.set('n', '<leader>dp', ':lua vim.diagnostic.goto_prev()<CR>', { desc = 'previous diagnostic' })
vim.keymap.set('n', '<leader>do', ':lua vim.diagnostic.open_float()<CR>', { desc = 'open diagnostic' })


-- [Key maps]
vim.keymap.set('n', '<leader>ff', ':NvimTreeFindFileToggle<CR>', { desc = '[f]ind [f]ile' })
vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, { buffer = bufnr, desc = '[C]ode [A]ction' })
vim.keymap.set('n', 'K', vim.lsp.buf.hover, {buffer = bufnr, desc = 'Hover Documentation' })
vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, {buffer = bufnr, desc = 'Signature Documentation' })


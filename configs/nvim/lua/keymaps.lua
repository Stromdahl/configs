local utils = require('utils');
local builtin = require("telescope.builtin")


-- find
vim.keymap.set("n", "<leader>ff",  "<cmd>FzfLua files<cr>", {})
vim.keymap.set('n', '<leader>fd', function() builtin.find_files({ cwd = vim.fn.expand('%:p:h:h') }) end)
vim.keymap.set("n", "<leader>fg", "<cmd>FzfLua live_grep<cr>", {})
vim.keymap.set("n", "<leader>fb", builtin.buffers, {})


-- go to
vim.keymap.set("n", "gd", function() builtin.lsp_definitions({ reuse_win = true }) end)
vim.keymap.set("n", "gr", "<cmd>Telescope lsp_references<cr>")
vim.keymap.set("n", "gI", function() builtin.lsp_implementations({ reuse_win = true }) end)
vim.keymap.set("n", "gy", function() builtin.lsp_type_definitions({ reuse_win = true }) end)


-- file tree
vim.keymap.set("n", "<leader>ee", ":Neotree filesystem reveal float<CR>")


-- buffer
vim.keymap.set("n", "<leader>bd", utils.bufremove, { desc = "Delete Buffer" })


-- diagnostics
vim.keymap.set("n", "<leader>dn", vim.diagnostic.goto_next)
vim.keymap.set("n", "<leader>dp", vim.diagnostic.goto_prev)
vim.keymap.set("n", "<leader>do", vim.diagnostic.open_float)


-- uncategorized
vim.keymap.set('n', '<leader>yp', utils.yank_filepath, {desc= "[y]ank buffer file[p]ath"})


local utils = require('utils');

vim.keymap.set("n", "<leader>bd", utils.bufremove, { desc = "Delete Buffer" })

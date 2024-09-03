local utils = require('utils');


vim.keymap.set("n", "<leader>bd", utils.bufremove, { desc = "Delete Buffer" })
vim.keymap.set('n', '<leader>yp', utils.yank_filepath, {desc= "[y]ank buffer file[p]ath"})


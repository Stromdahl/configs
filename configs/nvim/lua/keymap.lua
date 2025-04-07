vim.keymap.set("n", "-", "<CMD>Oil --float<CR>", { desc = "Open parent directory" })

local M = {
  general = {
    leader = ' ',
    localleader = '//'
	}
}

return M

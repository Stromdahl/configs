local utils = require('ms.utils')
local keys = require('ms.utils.keys')

-- Highlight on yank
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
utils.augroup('HilightYank', {
  event = 'TextYankPost',
  command = function()
    vim.highlight.on_yank()
  end
})

-- resize splits if window got resized
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
utils.augroup('ResizeSplits', {
  event = 'VimResized',
  command = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end
})

-- go to last loc when opening a buffer
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
utils.augroup('GoToLastValueOnFileopen', {
  event = {'BufReadPost'},
  command = function(event)
    local exclude = { "gitcommit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].lazyvim_last_loc then
      return
    end
    vim.b[buf].lazyvim_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

utils.augroup('CreateMissingFilesOnWrite', {
  event = {'BufWritePre'},
  command = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end
})

-- Toggle between relative numbers and absolute numbers based on mode
utils.augroup("ToggleNumbersOnModeChange", {
  event = {'ModeChanged'},
  command = function()
    local mode = vim.api.nvim_get_mode().mode
    if mode == 'i' then
      vim.opt.relativenumber = false
      vim.opt.number = true
    else
      vim.opt.relativenumber = true
      vim.opt.number = true
    end
  end,
})

utils.augroup('AddTerminalMappings', {
  event = { 'TermOpen' },
  pattern = { 'term://*' },
  command = function()
    if vim.bo.filetype == '' or vim.bo.filetype == 'toggleterm' then
      local opts = { silent = false, buffer = 0 }
      keys.map_t({'kj', [[<C-\><C-n>]], opts})
      keys.map_t({'<C-w>h', '<Cmd>wincmd h<CR>', opts})
      keys.map_t({'<C-w>j', '<Cmd>wincmd j<CR>', opts})
      keys.map_t({'<C-w>k', '<Cmd>wincmd k<CR>', opts})
      keys.map_t({'<C-w>l', '<Cmd>wincmd l<CR>', opts})
      -- tnoremap('<S-Tab>', '<Cmd>bprev<CR>')
      -- tnoremap('<leader><Tab>', '<Cmd>close \\| :bnext<cr>')
    end
  end,
})

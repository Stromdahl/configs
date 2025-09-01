local u = require('ms.u');

local function nvim_put_lang_debug_log (args)
  local filetype = vim.bo.filetype
  local logline = u.concat(args)

  local line = ""
  if filetype == "javascript" or filetype == "typescript" then
    line = string.format("console.log('%s');", logline)
  elseif filetype == "rust" then
    line = string.format('dbg!("%s");', logline)
  else
    line = string.format('-- %s', logline)
  end

  vim.api.nvim_put({line}, "l", true, true)
end


vim.api.nvim_create_user_command("CloseBufKeepWin", function()
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()

  -- Get all listed buffers in most recently used order
  local buffers = vim.fn.getbufinfo({ buflisted = 1 })

  -- Get buffers currently visible in windows
  local visible_bufs = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    visible_bufs[vim.api.nvim_win_get_buf(win)] = true
  end

  -- Find most recently used buffer that is not visible and not the current one
  local replacement_buf = nil
  for _, bufinfo in ipairs(buffers) do
    if not visible_bufs[bufinfo.bufnr] and bufinfo.bufnr ~= current_buf then
      replacement_buf = bufinfo.bufnr
      break
    end
  end

  if replacement_buf then
    vim.api.nvim_win_set_buf(current_win, replacement_buf)
    vim.api.nvim_buf_delete(current_buf, { force = false })
  else
    vim.api.nvim_err_writeln("No suitable hidden buffer found to replace the current one.")
  end
end, { desc = "Close current buffer and open most recent hidden buffer in its place" })


vim.api.nvim_create_user_command("InsertLog", function()
  local filename = vim.fn.expand("%:t")
  local timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
  nvim_put_lang_debug_log({filename, ": ", timestamp})
end, {})

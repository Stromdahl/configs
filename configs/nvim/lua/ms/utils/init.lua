local M = {};


-- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
---@param client vim.lsp.Client
---@param method vim.lsp.protocol.Method
---@param bufnr? integer some lsp support methods only in specific files
---@return boolean
 function M.client_supports_method (client, method, bufnr)
  if vim.fn.has 'nvim-0.11' == 1 then
    return client:supports_method(method, bufnr)
  else
    return client.supports_method(method, { bufnr = bufnr })
  end
end

---------------------------------------------------------------------------------------------------
--- autogroup
--- Source: https://github.com/akinsho/dotfiles/blob/main/.config/nvim/lua/as/globals.lua
---------------------------------------------------------------------------------------------------

---@class AutocmdArgs
---@field id number autocmd ID
---@field event string
---@field group string?
---@field buf number
---@field file string
---@field match string | number
---@field data any

---@class Autocommand
---@field desc string?
---@field event  (string | string[])? list of autocommand events
---@field pattern (string | string[])? list of autocommand patterns
---@field command string | fun(args: AutocmdArgs): boolean?
---@field nested  boolean?
---@field once    boolean?
---@field buffer  number?

local autocmd_keys = { 'event', 'buffer', 'pattern', 'desc', 'command', 'group', 'once', 'nested' }
--- Validate the keys passed to as.augroup are valid
---@param name string
---@param command Autocommand
local function validate_autocmd(name, command)
  local incorrect = vim.iter(command):map(function(key, _)
    if not vim.tbl_contains(autocmd_keys, key) then return key end
  end)
  if #incorrect > 0 then
    vim.schedule(function()
      local msg = ('Incorrect keys: %s'):format(table.concat(incorrect, ', '))
      vim.notify(msg, 'error', { title = ('Autocmd: %s'):format(name) })
    end)
  end
end

--- Create augroup
---@param name string
---@param ... Autocommand A list of autocommands to create
---@return number
 function M.augroup (name, ...)
  local commands = { ... }
  assert(name ~= 'User', 'The name of an augroup CANNOT be User')
  assert(#commands > 0, string.format('You must specify at least one autocommand for %s', name))
  local id = vim.api.nvim_create_augroup(name, { clear = true })
  for _, autocmd in ipairs(commands) do
    validate_autocmd(name, autocmd)
    local is_callback = type(autocmd.command) == 'function'
    vim.api.nvim_create_autocmd(autocmd.event, {
      group = name,
      pattern = autocmd.pattern,
      desc = autocmd.desc,
      callback = is_callback and autocmd.command or nil,
      command = not is_callback and autocmd.command or nil,
      once = autocmd.once,
      nested = autocmd.nested,
      buffer = autocmd.buffer,
    })
  end
  return id
end

---------------------------------------------------------------------------------------------------
--- split definition
---------------------------------------------------------------------------------------------------

-- # Open definitions in a split window
function M.definition_split()
  local params = vim.lsp.util.make_position_params()

  vim.lsp.buf_request(0, 'textDocument/definition', params, function(err, result, ctx, _)
    if err or not result or vim.tbl_isempty(result) then
      vim.notify("Definition not found", vim.log.levels.ERROR)
      return
    end

    local def = result[1]
    if #result > 1 then
      vim.notify("Multiple definitions found, opening the first", vim.log.levels.WARN)
    end

    local uri = def.uri or def.targetUri
    local range = def.range or def.targetSelectionRange
    local filename = vim.uri_to_fname(uri)

    vim.cmd('vsplit ' .. vim.fn.fnameescape(filename))
    vim.api.nvim_win_set_cursor(0, { range.start.line + 1, range.start.character })
  end)
end

--- @class CommandArgs
--- @field args string
--- @field fargs table
--- @field bang boolean,

---Create an nvim command
---@param name string
---@param rhs string | fun(args: CommandArgs)
---@param opts table?
function M.command(name, rhs, opts)
  opts = opts or {}
  vim.api.nvim_create_user_command(name, rhs, opts)
end

return M

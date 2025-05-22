local M = {}

--- @class MSKeysSpec
--- @field [1] string lhs
--- @field [2]? string|fun():string?|false rhs
--- @field mode? string
--- @field desc? string
--- @field noremap? boolean
--- @field silent? boolean
--- @field buffer? number

--- @class MSKeysOpts
--- @field desc string
--- @field noremap? boolean
--- @field silent? boolean

--- @class MSKeys
--- @field lhs string lhs
--- @field rhs? string|fun() rhs
--- @field mode? string
--- @field opts MSKeysOpts

---@param keys MSKeysSpec
---@return MSKeys
local function _opts(keys)
  return {
    desc = keys.desc,
    noremap = keys.noremap,
    silent = keys.silent,
    buffer = keys.buffer,
  }
end

---@param keys MSKeysSpec
---@return MSKeys
function M._parse(keys)
  local opts = _opts(keys)

  return {
    lhs = keys[1],
    rhs = keys[2],
    mode = keys.mode,
    opts = opts
  }
end

---@param keys MSKeys
function M._set(keys)
  local rhs;
  local is_callback = type(keys.rhs) == 'function'
  if is_callback then
    rhs = function ()
      keys.rhs()
    end
  else
    rhs = keys.rhs
  end

  vim.keymap.set(keys.mode, keys.lhs, rhs, keys.opts)
end

---@param keys MSKeysSpec
function M.set (keys)
  local k = M._parse(keys);
  M._set(k)
end

-- DEPRECADED START: REMOVE WHEN ASAP
M.n = {}

---@param keys MSKeysSpec
function M.n.set(keys)
  local k = M._parse(keys);
  k.mode = 'n'
  M._set(k)
end
-- DEPRECADED END

---@param keys MSKeysSpec
function M.map_n(keys)
  local k = M._parse(keys);
  k.mode = 'n'
  M._set(k)
end

---@param keys MSKeysSpec
function M.map_t(keys)
  local k = M._parse(keys);
  k.mode = 't'
  M._set(k)
end

return M

local servers = {
  lua_ls = {},
  bashls = {},
  marksman = {},
  ts_ls = {},
  -- eslint_d = {}
  rust_analyzer = {
    -- Server-specific settings. See `:help lspconfig-setup`
    settings = {
      ['rust-analyzer'] = {},
    },
  },
}

return servers


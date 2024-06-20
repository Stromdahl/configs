local servers = {
  tsserver = {},
  eslint = {},
  lua_ls = {},
  rust_analyzer = {
    settings = {
      ['rust-analyser'] = {},
    }
  },
}

local on_attach = function(client, bufnr)
  local function opts(desc)
    return { buffer = bufnr, desc = "LSP " .. desc }
  end

  -- Mappings.
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts("Go to decleration"))
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts("Go to definition"))
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts("Show signature help"))
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts("Go to implementation"))
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts("Show signature help"))
  vim.keymap.set('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts("Add workspace folder"))
  vim.keymap.set('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts("Remove workspace folder"))
  vim.keymap.set('n', '<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts "List workspace folders")
  vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts "")
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts "")
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts "")
  vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts "")
  vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts "")
  vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts "")
  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts "")
end

return {
  {
    'neovim/nvim-lspconfig',
    config = function (_, _)
      local lspconfig = require 'lspconfig'
      for name, _ in pairs(servers) do
        lspconfig[name].setup {
          on_attach = on_attach,
        }
      end
    end
  },
  {
    "williamboman/mason.nvim",
    config = true
  },
  {
    "williamboman/mason-lspconfig.nvim",
    opts = function ()
      local ensure_installed = {}
      for server, _ in pairs(servers) do
        table.insert(ensure_installed, server)
      end
      return {
        ensure_installed=ensure_installed
      }
    end,
    config = true
  },
}

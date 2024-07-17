local servers = {
  tsserver = {},
  -- eslint = {},
  lua_ls = {},
  rust_analyzer = {
    filetypes = {"rust"},
    settings = {
      ['rust-analyser'] = {
        cargo = {
          allFeatures = true,
        }
      },
    }
  },
}

local on_attach = function(client, bufnr)
	if client.name == "tsserver" then
		client.server_capabilities.documentFormattingProvider = false
	end

  local function opts(desc)
    return { buffer = bufnr, desc = "LSP " .. desc }
  end

  local keymap = vim.keymap.set;
  keymap('n', 'gD', vim.lsp.buf.declaration, opts("Go to decleration"))
  keymap('n', 'gd', vim.lsp.buf.definition, opts("Go to definition"))
  keymap('n', 'K', vim.lsp.buf.hover, opts("Show signature help"))
  keymap('n', 'gi', vim.lsp.buf.implementation, opts("Go to implementation"))
	keymap("n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<cr>", opts("Code Action"))
  keymap("n", "<leader>cr", '<cmd>lua vim.lsp.buf.rename()<cr>', opts("Rename symbol"))
  keymap('n', '<C-k>', vim.lsp.buf.signature_help, opts("Show signature help"))
  keymap('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts("Add workspace folder"))
  keymap('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts("Remove workspace folder"))
  keymap('n', '<leader>wl', function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end, opts "List workspace folders")
  keymap('n', '<leader>D', vim.lsp.buf.type_definition, opts "")
  keymap('n', '<leader>rn', vim.lsp.buf.rename, opts "")
  keymap('n', 'gr', vim.lsp.buf.references, opts "")
  keymap('n', '<leader>e', vim.diagnostic.open_float, opts "")
  keymap('n', '[d', vim.diagnostic.goto_prev, opts "")
  keymap('n', ']d', vim.diagnostic.goto_next, opts "")
  keymap('n', '<leader>q', vim.diagnostic.setloclist, opts "")
end

return {
  {
    'neovim/nvim-lspconfig',
    config = function (_, _)
      local signs = {
        { name = "DiagnosticSignError", text = "" },
        { name = "DiagnosticSignWarn", text = "" },
        { name = "DiagnosticSignHint", text = "" },
        { name = "DiagnosticSignInfo", text = "" },
      }

      for _, sign in ipairs(signs) do
        vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
      end

      local config = {
        virtual_text = true, -- disable virtual text
        signs = {
          active = signs, -- show signs
        },
        update_in_insert = true,
        underline = true,
        severity_sort = true,
        float = {
          focusable = true,
          style = "minimal",
          border = "rounded",
          source = "always",
          header = "",
          prefix = "",
        },
      }

      vim.diagnostic.config(config)

      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
        border = "rounded",
      })

      vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
        border = "rounded",
      })

      local lspconfig = require 'lspconfig'
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      for name, config in pairs(servers) do
        local opts = {
          on_attach = on_attach,
          capabilities = capabilities,
        }


        -- TODO: Move server settings to seperate files
        -- local require_ok, conf_opts = pcall(require, "user.lsp.settings." .. server)
        -- if require_ok then
        -- 	opts = vim.tbl_deep_extend("force", conf_opts, opts)
        -- end

        opts = vim.tbl_deep_extend('force', config, opts);
        lspconfig[name].setup(opts)
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

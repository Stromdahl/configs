vim.g.mapleader = " "
vim.g.maplocalleader = "//"

--------------------------------------
-- Options
--------------------------------------
local o = vim.opt
o.laststatus = 3
o.showmode = false
o.clipboard = "unnamedplus"
o.cursorline = true
o.cursorlineopt = "both"
o.colorcolumn = "100"
o.scrolloff = 999
o.background = "dark"
o.autoread = true
o.virtualedit = "block"
o.inccommand = "split"

-- Indenting
o.expandtab = true
o.shiftwidth = 2
o.smartindent = true
o.tabstop = 2
o.softtabstop = 2

o.fillchars = { eob = " " }
o.ignorecase = true
o.smartcase = true
o.mouse = "a"

-- Numbers
o.number = true
o.relativenumber = true
o.numberwidth = 4

-- disable nvim intro
vim.opt.shortmess:append "I"

o.signcolumn = "yes"
o.splitbelow = true
o.splitright = true
o.timeoutlen = 400
o.undofile = true
o.updatetime = 250

vim.o.winborder = "rounded"
vim.opt.completeopt = { "menuone", "noinsert", "noselect", "fuzzy" }

-- Diagnostics
vim.diagnostic.config({
  virtual_text = { spacing = 2, prefix = "●", severity = { min = vim.diagnostic.severity.WARN }, current_line = true },
  virtual_lines = false,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { border = "rounded" },
})

vim.lsp.handlers["textDocument/hover"] =
    vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
vim.lsp.handlers["textDocument/signatureHelp"] =
    vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

--------------------------------------
-- Utils
--------------------------------------

-- Close current buffer, keep window; fill with most-recently-used buffer
-- that isn't already visible. Falls back to a new empty buffer.
local function bclose_keep_layout()
  local cur = vim.api.nvim_get_current_buf()

  -- collect listed buffers with lastused, newest first
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(bufs, function(a, b) return (a.lastused or 0) > (b.lastused or 0) end)

  -- pick first not currently visible
  local target
  for _, b in ipairs(bufs) do
    if b.bufnr ~= cur and #vim.fn.win_findbuf(b.bufnr) == 0 then
      target = b.bufnr
      break
    end
  end

  if target then
    vim.api.nvim_win_set_buf(0, target)
  else
    vim.cmd.enew()
  end

  -- delete old buffer (no force; will fail if modified)
  local ok, err = pcall(vim.api.nvim_buf_delete, cur, {})
  if not ok then vim.notify(err, vim.log.levels.WARN) end
end

local function go_to_definition_split()
  vim.cmd("split")
  vim.lsp.buf.definition()
end

local function go_to_definition_vsplit()
  vim.cmd("vsplit")
  vim.lsp.buf.definition()
end

local function toggle_diagnostic_virtual_text()
  local vt = vim.diagnostic.config().virtual_text
  vim.diagnostic.config({ virtual_text = not vt })
end

local function toggle_diagnostic_virtual_lines()
  local vl = vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = not vl })
end

--------------------------------------
-- Keymaps
--------------------------------------
-- diagnostic toggles
vim.keymap.set("n", "<leader>dl", toggle_diagnostic_virtual_lines, { desc = "Toggle diagnostic virtual_lines" })
vim.keymap.set("n", "<leader>dt", toggle_diagnostic_virtual_text, { desc = "Toggle diagnostic virtual_text" })

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.keymap.set("n", "<leader>E", vim.diagnostic.setloclist)
vim.keymap.set("n", "<leader>dd", vim.diagnostic.setqflist, { desc = "Diagnostics → quickfix" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
vim.keymap.set("n", "<leader>q", bclose_keep_layout, { desc = "Close buffer, keep layout" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

-- LSP keys
local lsp = vim.lsp.buf
vim.keymap.set("i", "<C-Space>", lsp.signature_help) -- avoids <C-s> TTY issues
vim.keymap.set("n", "<leader>cr", lsp.rename)
vim.keymap.set("n", "K", lsp.hover)
vim.keymap.set("n", "gD", lsp.declaration)
vim.keymap.set("n", "gd", lsp.definition)
vim.keymap.set("n", "gi", lsp.implementation)
vim.keymap.set("n", "gr", lsp.references)
vim.keymap.set("n", "gsd", go_to_definition_split, { desc = "Go to definition in split" })
vim.keymap.set("n", "gvd", go_to_definition_vsplit, { desc = "Go to definition in vsplit" })
vim.keymap.set({ "n", "v" }, "<leader>ca", lsp.code_action)


--------------------------------------
-- Autocmds
--------------------------------------
-- highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.highlight.on_yank({ timeout = 150 }) end,
})



-- open fuzzy files on start when no file args
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() == 0 and vim.fn.empty(vim.fn.expand("%")) == 1 and vim.bo.buftype == "" then
      if vim.bo.modified == false then
        pcall(vim.api.nvim_buf_delete, 0, { force = true })
      end
      pcall(function() require("fzf-lua").files() end)
    end
  end,
})


-- restore cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})


-- close helpers with q
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "qf", "help", "man", "lspinfo" },
  callback = function() vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true }) end,
})


-- resize splits on terminal resize
vim.api.nvim_create_autocmd("VimResized", { callback = function() vim.cmd("tabdo wincmd =") end })


-- cursorline only in active window
vim.api.nvim_create_autocmd({ "WinEnter" }, {
  callback = function() vim.opt_local.cursorline = true end,
})
vim.api.nvim_create_autocmd({ "WinLeave" }, {
  callback = function() vim.opt_local.cursorline = false end,
})


-- relative number toggle on insert
vim.api.nvim_create_autocmd("InsertEnter", { callback = function() vim.opt.relativenumber = false end })
vim.api.nvim_create_autocmd("InsertLeave", { callback = function() vim.opt.relativenumber = true end })


-- create parent dirs on save
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(ev)
    local dir = vim.fn.fnamemodify(ev.match, ":p:h")
    if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end
  end,
})


-- trim trailing whitespace except markdown/diff
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    if ft ~= "markdown" and ft ~= "diff" then
      local view = vim.fn.winsaveview()
      vim.cmd([[%s/\s\+$//e]])
      vim.fn.winrestview(view)
    end
  end,
})


-- check for external file changes
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  callback = function() if vim.o.modifiable then vim.cmd.checktime() end end,
})


-- formatoptions sanity per buffer
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
  callback = function()
    vim.opt_local.formatoptions = vim.opt_local.formatoptions - "t" - "o" - "2" + "c" + "q" + "r" + "n" + "j"
  end,
})


-- format on save via LSP (exclude tsserver by default)
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(ev)
    pcall(vim.lsp.buf.format, {
      bufnr = ev.buf,
      async = false,
      timeout_ms = 1500,
      filter = function(client)
        return client and client.name ~= "tsserver"
      end,
    })
  end,
})


-- document highlight when supported
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.supports_method("textDocument/documentHighlight") then
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = ev.buf, callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
        buffer = ev.buf, callback = vim.lsp.buf.clear_references,
      })
    end
  end,
})


-- inlay hints toggle + auto-enable
vim.api.nvim_create_user_command("InlayHintsToggle", function()
  local b = vim.api.nvim_get_current_buf()
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = b })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = b })
end, {})
vim.keymap.set("n", "<leader>ih", "<cmd>InlayHintsToggle<cr>", { desc = "Toggle inlay hints" })
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.server_capabilities.inlayHintProvider then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end
  end,
})


--------------------------------------
-- Rust-specific commands and functions
--------------------------------------
local function run_cargo_command(cmd)
  vim.cmd("split")
  vim.fn.termopen("cargo " .. cmd, {
    cwd = vim.fn.getcwd(),
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("Cargo " .. cmd .. " completed successfully", vim.log.levels.INFO)
      else
        vim.notify("Cargo " .. cmd .. " failed with code " .. code, vim.log.levels.ERROR)
      end
    end,
  })
end

vim.api.nvim_create_user_command("CargoRun", function(opts)
  local args = opts.args ~= "" and " " .. opts.args or ""
  run_cargo_command("run" .. args)
end, { nargs = "*", desc = "Run cargo run with optional arguments" })

vim.api.nvim_create_user_command("CargoTest", function(opts)
  local args = opts.args ~= "" and " " .. opts.args or ""
  run_cargo_command("test" .. args)
end, { nargs = "*", desc = "Run cargo test with optional arguments" })

vim.api.nvim_create_user_command("CargoBuild", function(opts)
  local args = opts.args ~= "" and " " .. opts.args or ""
  run_cargo_command("build" .. args)
end, { nargs = "*", desc = "Run cargo build with optional arguments" })

vim.api.nvim_create_user_command("CargoCheck", function()
  run_cargo_command("check")
end, { desc = "Run cargo check" })

vim.api.nvim_create_user_command("CargoClippy", function()
  run_cargo_command("clippy")
end, { desc = "Run cargo clippy" })

vim.api.nvim_create_user_command("CargoFmt", function()
  vim.cmd("!cargo fmt")
  vim.cmd("checktime")
end, { desc = "Run cargo fmt" })

-- Rust-specific keybindings (only in Rust files)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "rust",
  callback = function()
    local opts = { buffer = true, silent = true }
    vim.keymap.set("n", "<leader>rr", "<cmd>CargoRun<cr>", vim.tbl_extend("force", opts, { desc = "Cargo run" }))
    vim.keymap.set("n", "<leader>rt", "<cmd>CargoTest<cr>", vim.tbl_extend("force", opts, { desc = "Cargo test" }))
    vim.keymap.set("n", "<leader>rb", "<cmd>CargoBuild<cr>", vim.tbl_extend("force", opts, { desc = "Cargo build" }))
    vim.keymap.set("n", "<leader>rc", "<cmd>CargoCheck<cr>", vim.tbl_extend("force", opts, { desc = "Cargo check" }))
    vim.keymap.set("n", "<leader>rl", "<cmd>CargoClippy<cr>", vim.tbl_extend("force", opts, { desc = "Cargo clippy" }))
    vim.keymap.set("n", "<leader>rf", "<cmd>CargoFmt<cr>", vim.tbl_extend("force", opts, { desc = "Cargo fmt" }))
  end,
})


--------------------------------------
-- LSP (0.11+ built-in config/enable)
--------------------------------------
vim.lsp.config["rust-analyzer"] = {
  cmd = { "rust-analyzer" },
  root_markers = { "Cargo.toml", "rust-project.json" },
  filetypes = { "rust" },
  single_file_support = true,
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        buildScripts = {
          enable = true,
        },
        features = "all",
      },
      checkOnSave = {
        enable = true,
        command = "clippy",
        extraArgs = { "--no-deps" },
      },
      diagnostics = {
        enable = true,
        disabled = { "unresolved-proc-macro" },
        enableExperimental = false,
      },
      hover = {
        actions = {
          enable = true,
          implementations = {
            enable = true,
          },
          references = {
            enable = true,
          },
          run = {
            enable = true,
          },
          debug = {
            enable = true,
          },
        },
      },
      inlayHints = {
        bindingModeHints = {
          enable = false,
        },
        chainingHints = {
          enable = true,
        },
        closingBraceHints = {
          enable = true,
          minLines = 25,
        },
        closureReturnTypeHints = {
          enable = "never",
        },
        lifetimeElisionHints = {
          enable = "never",
          useParameterNames = false,
        },
        maxLength = 25,
        parameterHints = {
          enable = true,
        },
        reborrowHints = {
          enable = "never",
        },
        renderColons = true,
        typeHints = {
          enable = true,
          hideClosureInitialization = false,
          hideNamedConstructor = false,
        },
      },
      lens = {
        enable = true,
        implementations = {
          enable = true,
        },
        references = {
          adt = {
            enable = true,
          },
          enumVariant = {
            enable = true,
          },
          method = {
            enable = true,
          },
          trait = {
            enable = true,
          },
        },
        run = {
          enable = true,
        },
      },
      notifications = {
        cargoTomlNotFound = true,
      },
      procMacro = {
        enable = true,
        ignored = {
          ["async-trait"] = { "async_trait" },
          ["napi-derive"] = { "napi" },
          ["async-recursion"] = { "async_recursion" },
        },
      },
    },
  },
}

vim.lsp.config["lua_ls"] = {
  cmd = { "lua-language-server" },
  root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
  filetypes = { "lua" },
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false },
    },
  },
}

vim.lsp.config["tsserver"] = {
  cmd = { "typescript-language-server", "--stdio" },
  root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
  filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
}

vim.lsp.config["clangd"] = {
  cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu" },
  root_markers = { "compile_commands.json", "compile_flags.txt", ".clangd", ".git" },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
  single_file_support = true,
}

vim.lsp.enable({ "rust-analyzer", "lua_ls", "tsserver", "clangd" })


--------------------------------------
-- Plugins (lazy.nvim)
--------------------------------------
-- bootstrap lazy
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", lazypath })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  { "neovim/nvim-lspconfig",   cmd = { "LspInfo", "LspStart", "LspStop", "LspRestart" } },

  -- Completion
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              if luasnip.expandable() then
                luasnip.expand()
              else
                cmp.confirm({ select = true })
              end
            else
              fallback()
            end
          end),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = 1000 },
          { name = "luasnip",  priority = 750 },
        }, {
          { name = "buffer", priority = 500 },
          { name = "path",   priority = 250 },
        }),
        formatting = {
          format = function(entry, vim_item)
            vim_item.menu = ({
              nvim_lsp = "[LSP]",
              luasnip = "[Snippet]",
              buffer = "[Buffer]",
              path = "[Path]",
            })[entry.source.name]
            return vim_item
          end,
        },
        experimental = {
          ghost_text = true,
        },
      })

      -- Use buffer source for `/` and `?`
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" }
        }
      })

      -- Use cmdline & path source for ':'
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" }
        }, {
          { name = "cmdline" }
        }),
        matching = { disallow_symbol_nonprefix_matching = false }
      })
    end,
  },
  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      ensure_installed = {
        "lua", "vim", "vimdoc", "rust", "go", "c", "cpp",
        "javascript", "typescript", "bash", "json", "toml", "yaml", "markdown"
      },
      highlight = { enable = true },
      indent = {
        enable = true,
        disable = function(_, buf)
          return vim.api.nvim_buf_line_count(buf) > 20000
        end
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  -- Git
  { "lewis6991/gitsigns.nvim", opts = {},                                               event = { "BufReadPre", "BufNewFile" }, },
  { "tpope/vim-fugitive",      cmd = { "G", "Git", "Gdiffsplit", "Gblame" } },

  -- File Tree
  {
    'stevearc/oil.nvim',
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {},
    -- Optional dependencies
    dependencies = { { "echasnovski/mini.icons", opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
    keys = {
      { "<leader>ft", "<CMD>Oil<CR>", desc = "Open parent directory" },
    }
  },

  -- Fuzzy finder
  {
    "ibhagwan/fzf-lua",
    dependencies = { "echasnovski/mini.icons", "elanmed/fzf-lua-frecency.nvim" },
    opts = {},
    keys = {
      { "<leader>ff",       function() require("fzf-lua").files() end,                                 desc = "[f]ind [f]ile" },
      { "<leader><leader>", function() require("fzf-lua").files() end,                                 desc = "[f]ind [f]ile" },
      { "=",                function() require("fzf-lua").files() end,                                 desc = "[f]ind [f]ile" },
      { "<leader>fp",       function() require("fzf-lua").files({ cwd = vim.fn.expand("%:p:h") }) end, desc = "[f]ind file in [p]ath" },
      { "<leader>fg",       function() require("fzf-lua").live_grep() end,                             desc = "[f]ind by [g]rep" },
    }
  },

  -- Snippets
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
    build = "make install_jsregexp",
    event = "InsertEnter",
    dependencies = { "rafamadriz/friendly-snippets" },
    config = function()
      local ls = require("luasnip")
      local s = ls.snippet
      local sn = ls.snippet_node
      local t = ls.text_node
      local i = ls.insert_node
      local f = ls.function_node
      local c = ls.choice_node
      local d = ls.dynamic_node
      local r = ls.restore_node
      local fmt = require("luasnip.extras.fmt").fmt
      local rep = require("luasnip.extras").rep
      local types = require("luasnip.util.types")

      ls.setup({
        history = true,
        delete_check_events = "TextChanged",
        ext_opts = {
          [types.choiceNode] = {
            active = {
              virt_text = { { "choiceNode", "Comment" } },
            },
          },
        },
        enable_autosnippets = true,
        store_selection_keys = "<Tab>",
      })

      -- Load friendly-snippets
      require("luasnip.loaders.from_vscode").lazy_load()

      -- Helper functions
      local function get_formatted_date()
        return os.date("%Y-%m-%d")
      end

      local function get_week_number()
        return os.date("%U")
      end

      local function get_day_of_week()
        return os.date("%A")
      end

      local function get_iso_date()
        return os.date("%Y-%m-%dT%H:%M:%S")
      end

      local function get_filename()
        return vim.fn.expand("%:t:r")
      end

      local function get_full_filename()
        return vim.fn.expand("%:t")
      end

      local function get_relative_path()
        return vim.fn.expand("%:.")
      end

      local function get_line_number()
        return tostring(vim.fn.line("."))
      end

      local function get_timestamp()
        return os.date("%H:%M:%S")
      end

      local function get_full_timestamp()
        return os.date("%Y-%m-%d %H:%M:%S")
      end

      -- Global snippets
      ls.add_snippets("all", {
        s("date", f(get_formatted_date)),
        s("isodate", f(get_iso_date)),
        s("weeknum", fmt("{}", { f(get_week_number) })),
        s("filename", f(get_filename)),
        s("todo", fmt("TODO({}): {}", { i(1, "username"), i(2, "description") })),
        s("fixme", fmt("FIXME({}): {}", { i(1, "username"), i(2, "description") })),
        s("note", fmt("NOTE({}): {}", { i(1, "username"), i(2, "description") })),
        -- Debug snippets
        s("debug", fmt("DEBUG [{}:{}] {} - {}", {
          f(get_full_filename),
          f(get_line_number),
          f(get_timestamp),
          i(1, "message")
        })),
        s("debugfull", fmt("DEBUG [{}:{}] {} - {}", {
          f(get_relative_path),
          f(get_line_number),
          f(get_full_timestamp),
          i(1, "message")
        })),
      })

      -- Markdown snippets
      ls.add_snippets("markdown", {
        s("daily", fmt("### {} v{} {}", {
          f(get_formatted_date),
          f(get_week_number),
          f(get_day_of_week)
        })),
        s("meta", fmt([[
---
title: {}
date: {}
tags: [{}]
---

{}
        ]], {
          i(1, "title"),
          f(get_formatted_date),
          i(2, "tag1, tag2"),
          i(0)
        })),
        s("link", fmt("[{}]({})", { i(1, "text"), i(2, "url") })),
        s("img", fmt("![{}]({})", { i(1, "alt text"), i(2, "url") })),
        s("code", fmt("```{}\n{}\n```", { i(1, "language"), i(2, "code") })),
        s("table", fmt([[
| {} | {} |
|---|---|
| {} | {} |
        ]], { i(1, "Header 1"), i(2, "Header 2"), i(3, "Cell 1"), i(4, "Cell 2") })),
      })

      -- JavaScript/TypeScript snippets
      ls.add_snippets("javascript", {
        s("cl", fmt("console.log({})", { i(1, "value") })),
        s("ce", fmt("console.error({})", { i(1, "error") })),
        s("cw", fmt("console.warn({})", { i(1, "warning") })),
        s("fn", fmt("function {}({}) {{\n  {}\n}}", { i(1, "name"), i(2, "params"), i(3, "// body") })),
        s("af", fmt("const {} = ({}) => {{\n  {}\n}}", { i(1, "name"), i(2, "params"), i(3, "// body") })),
        s("iife", fmt("(function() {{\n  {}\n}})();", { i(1, "// body") })),
        s("try", fmt([[
try {{
  {}
}} catch ({}) {{
  {}
}}
        ]], { i(1, "// try block"), i(2, "error"), i(3, "// catch block") })),
        -- Debug snippets
        s("dbg", fmt("console.log(`DEBUG [{}:{}] {} - {}`, {})", {
          f(get_full_filename),
          f(get_line_number),
          f(get_timestamp),
          i(1, "message"),
          i(2, "value")
        })),
        s("dbge", fmt("console.error(`DEBUG [{}:{}] {} - {}`, {})", {
          f(get_full_filename),
          f(get_line_number),
          f(get_timestamp),
          i(1, "message"),
          i(2, "value")
        })),
        s("dbgt", fmt("console.trace(`[{}:{}] {} - {}`)", {
          f(get_full_filename),
          f(get_line_number),
          f(get_timestamp),
          i(1, "trace point")
        })),
      })

      -- Copy JavaScript snippets to TypeScript
      ls.add_snippets("typescript", ls.get_snippets("javascript"))
      ls.add_snippets("typescriptreact", ls.get_snippets("javascript"))
      ls.add_snippets("javascriptreact", ls.get_snippets("javascript"))

      -- Lua snippets
      ls.add_snippets("lua", {
        s("fn", fmt("local function {}({})\n  {}\nend", { i(1, "name"), i(2, "params"), i(3, "-- body") })),
        s("req", fmt("local {} = require('{}')", { i(1, "module"), rep(1) })),
        s("print", fmt("print({})", { i(1, "value") })),
        s("if", fmt("if {} then\n  {}\nend", { i(1, "condition"), i(2, "-- body") })),
        s("for", fmt("for {} = {}, {} do\n  {}\nend", { i(1, "i"), i(2, "1"), i(3, "10"), i(4, "-- body") })),
        -- Debug snippets
        s("dbg", fmt("print(string.format(\"DEBUG [%s:%s] %s - %s\", \"{}\", \"{}\", \"{}\", tostring({})))", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
        s("dbgs", fmt("print(\"[{}:{}] {} - \" .. tostring({}))", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
      })

      -- Rust snippets
      ls.add_snippets("rust", {
        s("fn", fmt("fn {}({}) -> {} {{\n    {}\n}}", { i(1, "name"), i(2, "params"), i(3, "()"), i(4, "// body") })),
        s("struct", fmt("struct {} {{\n    {}\n}}", { i(1, "Name"), i(2, "field: Type") })),
        s("impl", fmt("impl {} {{\n    {}\n}}", { i(1, "Type"), i(2, "// methods") })),
        s("match",
          fmt("match {} {{\n    {} => {},\n    _ => {},\n}}",
            { i(1, "expr"), i(2, "pattern"), i(3, "result"), i(4, "default") })),
        s("println", fmt("println!(\"{}\", {})", { i(1, "format"), i(2, "args") })),
        -- Debug snippets
        s("dbg", fmt("println!(\"DEBUG [{}:{}] {} - {{:?}}\", {})", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
        s("dbge", fmt("eprintln!(\"DEBUG [{}:{}] {} - {{:?}}\", {})", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
        s("dbgm", fmt("dbg!(&{});", { i(1, "value") })),
      })

      -- Go snippets
      ls.add_snippets("go", {
        s("fn", fmt("func {}({}) {} {{\n\t{}\n}}", { i(1, "name"), i(2, "params"), i(3, "returnType"), i(4, "// body") })),
        s("if", fmt("if {} {{\n\t{}\n}}", { i(1, "condition"), i(2, "// body") })),
        s("ife", fmt("if err != nil {{\n\t{}\n}}", { i(1, "return err") })),
        s("struct", fmt("type {} struct {{\n\t{}\n}}", { i(1, "Name"), i(2, "Field Type") })),
        s("fmt", fmt("fmt.Println({})", { i(1, "value") })),
        -- Debug snippets
        s("dbg", fmt("fmt.Printf(\"DEBUG [{}:{}] {} - %+v\\n\", {})", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
        s("dbgl", fmt("log.Printf(\"DEBUG [{}:{}] {} - %+v\", {})", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
      })

      -- C/C++ snippets
      ls.add_snippets("c", {
        s("dbg", fmt("printf(\"DEBUG [{}:{}] {} - %s\\n\", {});", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
        s("dbge", fmt("fprintf(stderr, \"DEBUG [{}:{}] {} - %d\\n\", {});", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
      })

      -- Copy C snippets to C++
      ls.add_snippets("cpp", ls.get_snippets("c"))
      ls.add_snippets("cpp", {
        s("dbg", fmt("std::cout << \"DEBUG [{}:{}] {} - \" << {} << std::endl;", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
        s("dbge", fmt("std::cerr << \"DEBUG [{}:{}] {} - \" << {} << std::endl;", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
      })

      -- Python snippets
      ls.add_snippets("python", {
        s("dbg", fmt("print(f\"DEBUG [{}:{}] {} - {{}}\", {})", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
        s("dbgl", fmt("logging.debug(f\"[{}:{}] {} - {{}}\", {})", {
          f(get_full_filename),
          f(get_line_number),
          i(1, "message"),
          i(2, "value")
        })),
        s("dbgp",
          fmt("import pprint; pprint.pprint({{\"file\": \"{}\", \"line\": {}, \"message\": \"{}\", \"value\": {}}})", {
            f(get_full_filename),
            f(get_line_number),
            i(1, "message"),
            i(2, "value")
          })),
      })

      -- Keymaps
      vim.keymap.set({ "i", "s" }, "<C-L>", function() ls.jump(1) end, { silent = true })
      vim.keymap.set({ "i", "s" }, "<C-J>", function() ls.jump(-1) end, { silent = true })
      vim.keymap.set({ "i", "s" }, "<C-E>", function()
        if ls.choice_active() then
          ls.change_choice(1)
        end
      end, { silent = true })
    end,
  },

  { "rafamadriz/friendly-snippets", lazy = true },
})

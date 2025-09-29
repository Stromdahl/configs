-- Neovim Configuration - Single File Setup
-- Table of Contents:
-- 1. Core Configuration (Leaders, Options, Diagnostics)
-- 2. Utility Functions
-- 3. Keymaps & Commands
-- 4. Autocommands
-- 5. LSP Configuration
-- 6. Plugin Setup

--------------------------------------
-- Core Configuration
--------------------------------------

-- Leaders
vim.g.mapleader = " "
vim.g.maplocalleader = "//"

-- Core Options
local o = vim.opt

-- UI & Appearance
o.laststatus = 3
o.showmode = false
o.cursorline = true
o.cursorlineopt = "both"
o.colorcolumn = "100"
o.scrolloff = 999
o.background = "dark"
o.signcolumn = "yes"
o.fillchars = { eob = " " }

-- Editing & Behavior
o.clipboard = "unnamedplus"
o.autoread = true
o.virtualedit = "block"
o.inccommand = "split"
o.mouse = "a"
o.timeoutlen = 400
o.undofile = true
o.updatetime = 250

-- Search
o.ignorecase = true
o.smartcase = true

-- Numbers
o.number = true
o.relativenumber = true
o.numberwidth = 4

-- Indenting
o.expandtab = true
o.shiftwidth = 2
o.smartindent = true
o.tabstop = 2
o.softtabstop = 2

-- Splits
o.splitbelow = true
o.splitright = true

-- Completion & UI
vim.o.winborder = "rounded"
vim.opt.completeopt = { "menuone", "noinsert", "noselect", "fuzzy" }
vim.opt.shortmess:append "I"

-- Diagnostics Configuration
vim.diagnostic.config({
  virtual_text = {
    spacing = 2,
    prefix = "●",
    severity = { min = vim.diagnostic.severity.WARN },
    current_line = true
  },
  virtual_lines = false,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = { border = "rounded" },
})

-- LSP Handlers
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

--------------------------------------
-- Utility Functions
--------------------------------------

-- Autocmd Wrapper API
-- Usage:
--   autocmd("BufEnter", { callback = function() print("Buffer entered") end })
--   autocmd("FileType", { pattern = "lua", callback = "echom 'Lua file!'" })
--   autocmd("BufWritePre", { 
--     condition = function(ev) return vim.bo[ev.buf].buftype == "" end,
--     callback = function() print("Writing regular file") end 
--   })
local function autocmd(event, opts)
  local config = {
    pattern = opts.pattern,
    group = opts.group,
    buffer = opts.buffer,
    once = opts.once,
    nested = opts.nested,
    desc = opts.desc,
  }
  
  if opts.condition then
    config.callback = function(ev)
      if opts.condition(ev) then
        if type(opts.callback) == "function" then
          opts.callback(ev)
        elseif type(opts.callback) == "string" then
          vim.cmd(opts.callback)
        end
      end
    end
  else
    config.callback = opts.callback
  end
  
  return vim.api.nvim_create_autocmd(event, config)
end

-- Buffer Management
local function bclose_keep_layout()
  local cur = vim.api.nvim_get_current_buf()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(bufs, function(a, b) return (a.lastused or 0) > (b.lastused or 0) end)

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

  local ok, err = pcall(vim.api.nvim_buf_delete, cur, {})
  if not ok then vim.notify(err, vim.log.levels.WARN) end
end

-- LSP Navigation
local function go_to_definition_split()
  vim.cmd("split")
  vim.lsp.buf.definition()
end

local function go_to_definition_vsplit()
  vim.cmd("vsplit")
  vim.lsp.buf.definition()
end

-- Diagnostic Toggles
local function toggle_diagnostic_virtual_text()
  local vt = vim.diagnostic.config().virtual_text
  vim.diagnostic.config({ virtual_text = not vt })
end

local function toggle_diagnostic_virtual_lines()
  local vl = vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = not vl })
end

-- Cargo Commands
local function run_cargo_command(cmd)
  vim.cmd("split")
  vim.fn.termopen("cargo " .. cmd, {
    cwd = vim.fn.getcwd(),
    on_exit = function(_, code)
      local level = code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR
      local status = code == 0 and "completed successfully" or ("failed with code " .. code)
      vim.notify("Cargo " .. cmd .. " " .. status, level)
    end,
  })
end

-- Snippet Helper Functions
local function get_file_info()
  return {
    filename = vim.fn.expand("%:t"),
    full_filename = vim.fn.expand("%:t"),
    relative_path = vim.fn.expand("%."),
    line_number = tostring(vim.fn.line(".")),
  }
end

local function get_time_info()
  return {
    date = os.date("%Y-%m-%d"),
    iso_date = os.date("%Y-%m-%dT%H:%M:%S"),
    timestamp = os.date("%H:%M:%S"),
    full_timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    week_number = os.date("%U"),
    day_of_week = os.date("%A"),
  }
end

--------------------------------------
-- Keymaps & Commands
--------------------------------------

-- General Keymaps
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.keymap.set("n", "<leader>q", bclose_keep_layout, { desc = "Close buffer, keep layout" })

-- Diagnostic Keymaps
vim.keymap.set("n", "<leader>dl", toggle_diagnostic_virtual_lines, { desc = "Toggle diagnostic virtual_lines" })
vim.keymap.set("n", "<leader>dt", toggle_diagnostic_virtual_text, { desc = "Toggle diagnostic virtual_text" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
vim.keymap.set("n", "<leader>E", vim.diagnostic.setloclist)
vim.keymap.set("n", "<leader>dd", vim.diagnostic.setqflist, { desc = "Diagnostics → quickfix" })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

-- LSP Keymaps
local lsp = vim.lsp.buf
vim.keymap.set("i", "<C-Space>", lsp.signature_help)
vim.keymap.set("n", "<leader>cr", lsp.rename)
vim.keymap.set("n", "K", lsp.hover)
vim.keymap.set("n", "gD", lsp.declaration)
vim.keymap.set("n", "gd", lsp.definition)
vim.keymap.set("n", "gi", lsp.implementation)
vim.keymap.set("n", "gr", lsp.references)
vim.keymap.set("n", "gsd", go_to_definition_split, { desc = "Go to definition in split" })
vim.keymap.set("n", "gvd", go_to_definition_vsplit, { desc = "Go to definition in vsplit" })
vim.keymap.set({ "n", "v" }, "<leader>ca", lsp.code_action)

-- Inlay Hints
vim.api.nvim_create_user_command("InlayHintsToggle", function()
  local b = vim.api.nvim_get_current_buf()
  local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = b })
  vim.lsp.inlay_hint.enable(not enabled, { bufnr = b })
end, {})
vim.keymap.set("n", "<leader>ih", "<cmd>InlayHintsToggle<cr>", { desc = "Toggle inlay hints" })

-- Cargo Commands
local cargo_commands = {
  { "CargoRun",    "run",    "Run cargo run with optional arguments" },
  { "CargoTest",   "test",   "Run cargo test with optional arguments" },
  { "CargoBuild",  "build",  "Run cargo build with optional arguments" },
  { "CargoCheck",  "check",  "Run cargo check" },
  { "CargoClippy", "clippy", "Run cargo clippy" },
}

for _, cmd in ipairs(cargo_commands) do
  local nargs = (cmd[2] == "check" or cmd[2] == "clippy") and 0 or "*"
  vim.api.nvim_create_user_command(cmd[1], function(opts)
    local args = (cmd[2] == "check" or cmd[2] == "clippy") and "" or (opts.args ~= "" and " " .. opts.args or "")
    run_cargo_command(cmd[2] .. args)
  end, { nargs = nargs, desc = cmd[3] })
end

vim.api.nvim_create_user_command("CargoFmt", function()
  vim.cmd("!cargo fmt")
  vim.cmd("checktime")
end, { desc = "Run cargo fmt" })

--------------------------------------
-- Autocommands
--------------------------------------

-- Highlight on yank
autocmd("TextYankPost", {
  callback = function() vim.highlight.on_yank({ timeout = 150 }) end,
})

-- Open fuzzy files on start
autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() == 0 and vim.fn.empty(vim.fn.expand("%")) == 1 and vim.bo.buftype == "" then
      if vim.bo.modified == false then
        pcall(vim.api.nvim_buf_delete, 0, { force = true })
      end
      pcall(function() require("fzf-lua").files() end)
    end
  end,
})

-- Restore cursor position
autocmd("BufReadPost", {
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      vim.api.nvim_win_set_cursor(0, mark)
    end
  end,
})

-- Close helpers with q
autocmd("FileType", {
  pattern = { "qf", "help", "man", "lspinfo" },
  callback = function() vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true }) end,
})

-- Window management
autocmd("VimResized", {
  callback = function() vim.cmd("tabdo wincmd =") end
})

-- Cursorline only in active window
autocmd("WinEnter", {
  callback = function() vim.opt_local.cursorline = true end,
})
autocmd("WinLeave", {
  callback = function() vim.opt_local.cursorline = false end,
})

-- Relative number toggle on insert
autocmd("InsertEnter", {
  callback = function() vim.opt.relativenumber = false end
})
autocmd("InsertLeave", {
  callback = function() vim.opt.relativenumber = true end
})

-- File management
autocmd("BufWritePre", {
  condition = function(ev)
    local bufname = vim.api.nvim_buf_get_name(ev.buf)
    return vim.bo[ev.buf].buftype == "" and not bufname:match("^%w+://")
  end,
  callback = function(ev)
    local dir = vim.fn.fnamemodify(ev.match, ":p:h")
    if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end
  end,
})

-- Trim trailing whitespace (except markdown/diff)
autocmd("BufWritePre", {
  condition = function(ev)
    local ft = vim.bo[ev.buf].filetype
    return ft ~= "markdown" and ft ~= "diff"
  end,
  callback = function(ev)
    local view = vim.fn.winsaveview()
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Check for external file changes
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  condition = function() return vim.o.modifiable end,
  callback = function() vim.cmd.checktime() end
})

-- Format options sanity
autocmd({ "BufEnter", "BufWinEnter" }, {
  callback = function()
    vim.opt_local.formatoptions = vim.opt_local.formatoptions - "t" - "o" - "2" + "c" + "q" + "r" + "n" + "j"
  end,
})

-- Format on save via LSP (exclude ts_ls)
autocmd("BufWritePre", {
  condition = function(ev)
    local bufname = vim.api.nvim_buf_get_name(ev.buf)
    return vim.bo[ev.buf].buftype == "" and not bufname:match("^%w+://")
  end,
  callback = function(ev)
    pcall(vim.lsp.buf.format, {
      bufnr = ev.buf,
      async = false,
      timeout_ms = 1500,
      filter = function(client)
        return client and client.name ~= "ts_ls"
      end,
    })
  end,
})

-- Document highlight when supported
autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.supports_method("textDocument/documentHighlight") then
      autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = ev.buf,
        callback = vim.lsp.buf.document_highlight,
      })
      autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
        buffer = ev.buf,
        callback = vim.lsp.buf.clear_references,
      })
    end
  end,
})

-- Auto-enable inlay hints
autocmd("LspAttach", {
  condition = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    return client and client.server_capabilities.inlayHintProvider
  end,
  callback = function(ev)
    vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
  end,
})

-- Rust-specific keybindings
autocmd("FileType", {
  pattern = "rust",
  callback = function()
    local opts = { buffer = true, silent = true }
    local rust_maps = {
      { "<leader>rr", "<cmd>CargoRun<cr>",    "Cargo run" },
      { "<leader>rt", "<cmd>CargoTest<cr>",   "Cargo test" },
      { "<leader>rb", "<cmd>CargoBuild<cr>",  "Cargo build" },
      { "<leader>rc", "<cmd>CargoCheck<cr>",  "Cargo check" },
      { "<leader>rl", "<cmd>CargoClippy<cr>", "Cargo clippy" },
      { "<leader>rf", "<cmd>CargoFmt<cr>",    "Cargo fmt" },
    }
    for _, map in ipairs(rust_maps) do
      vim.keymap.set("n", map[1], map[2], vim.tbl_extend("force", opts, { desc = map[3] }))
    end
  end,
})

--------------------------------------
-- LSP Configuration
--------------------------------------

-- Rust Analyzer
vim.lsp.config["rust-analyzer"] = {
  cmd = { "rust-analyzer" },
  root_markers = { "Cargo.toml", "rust-project.json" },
  filetypes = { "rust" },
  single_file_support = true,
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        buildScripts = { enable = true },
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
          implementations = { enable = true },
          references = { enable = true },
          run = { enable = true },
          debug = { enable = true },
        },
      },
      inlayHints = {
        bindingModeHints = { enable = false },
        chainingHints = { enable = true },
        closingBraceHints = { enable = true, minLines = 25 },
        closureReturnTypeHints = { enable = "never" },
        lifetimeElisionHints = { enable = "never", useParameterNames = false },
        maxLength = 25,
        parameterHints = { enable = true },
        reborrowHints = { enable = "never" },
        renderColons = true,
        typeHints = { enable = true, hideClosureInitialization = false, hideNamedConstructor = false },
      },
      lens = {
        enable = true,
        implementations = { enable = true },
        references = {
          adt = { enable = true },
          enumVariant = { enable = true },
          method = { enable = true },
          trait = { enable = true },
        },
        run = { enable = true },
      },
      notifications = { cargoTomlNotFound = true },
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

-- Lua Language Server
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

-- TypeScript Language Server (ts_ls)
vim.lsp.config["ts_ls"] = {
  cmd = { "typescript-language-server", "--stdio" },
  root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
  filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
}

-- Clangd
vim.lsp.config["clangd"] = {
  cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu" },
  root_markers = { "compile_commands.json", "compile_flags.txt", ".clangd", ".git" },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
  single_file_support = true,
}

-- Set global LSP defaults
vim.lsp.config('*', {
  root_markers = { '.git' },
})

-- Enable all configured LSP servers
vim.lsp.enable({ 'rust-analyzer', 'lua_ls', 'ts_ls', 'clangd' })

--------------------------------------
-- Plugin Setup
--------------------------------------

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    lazypath
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- LSP Support
  { "neovim/nvim-lspconfig",   cmd = { "LspInfo", "LspStart", "LspStop", "LspRestart" } },

  -- Mason for LSP server management
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
    build = ":MasonUpdate",
    opts = {
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗"
        }
      }
    },
  },

  -- Mason-LSPConfig bridge
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = {
        "rust_analyzer",
        "lua_ls", 
        "ts_ls",
        "clangd",
      },
      automatic_installation = true,
    },
    config = function(_, opts)
      require("mason-lspconfig").setup(opts)
      
      -- Mason-lspconfig is only used for automatic installation
      -- LSP servers are configured and enabled via native vim.lsp APIs above
    end,
  },

  -- Completion Engine
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
        snippet = { expand = function(args) luasnip.lsp_expand(args.body) end },
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
            local menu_map = {
              nvim_lsp = "[LSP]",
              luasnip = "[Snippet]",
              buffer = "[Buffer]",
              path = "[Path]",
            }
            vim_item.menu = menu_map[entry.source.name]
            return vim_item
          end,
        },
        experimental = { ghost_text = true },
      })

      -- Cmdline completions
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } }
      })
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
        matching = { disallow_symbol_nonprefix_matching = false }
      })
    end,
  },

  -- Syntax Highlighting
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
        disable = function(_, buf) return vim.api.nvim_buf_line_count(buf) > 20000 end
      },
    },
    config = function(_, opts) require("nvim-treesitter.configs").setup(opts) end,
  },

  -- Git Integration
  { "lewis6991/gitsigns.nvim", opts = {},                                               event = { "BufReadPre", "BufNewFile" } },
  { "tpope/vim-fugitive",      cmd = { "G", "Git", "Gdiffsplit", "Gblame" } },

  -- File Management
  {
    'stevearc/oil.nvim',
    opts = {},
    dependencies = { { "echasnovski/mini.icons", opts = {} } },
    lazy = false,
  },

  -- Fuzzy Finder
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
      local t = ls.text_node
      local i = ls.insert_node
      local f = ls.function_node
      local fmt = require("luasnip.extras.fmt").fmt
      local rep = require("luasnip.extras").rep
      local types = require("luasnip.util.types")

      ls.setup({
        history = true,
        delete_check_events = "TextChanged",
        ext_opts = {
          [types.choiceNode] = {
            active = { virt_text = { { "choiceNode", "Comment" } } },
          },
        },
        enable_autosnippets = true,
        store_selection_keys = "<Tab>",
      })

      require("luasnip.loaders.from_vscode").lazy_load()

      -- Helper functions using the utility functions
      local function file_info(info_type)
        return function()
          local info = get_file_info()
          return info[info_type] or ""
        end
      end

      local function time_info(info_type)
        return function()
          local info = get_time_info()
          return info[info_type] or ""
        end
      end

      -- Debug snippet generator
      local function debug_snippet(lang_config)
        return s("dbg", fmt(lang_config.format, {
          f(file_info("filename")),
          f(file_info("line_number")),
          i(1, "message"),
          i(2, "value")
        }))
      end

      -- Global snippets
      ls.add_snippets("all", {
        s("date", f(time_info("date"))),
        s("isodate", f(time_info("iso_date"))),
        s("weeknum", fmt("{}", { f(time_info("week_number")) })),
        s("filename", f(file_info("filename"))),
        s("todo", fmt("TODO({}): {}", { i(1, "username"), i(2, "description") })),
        s("fixme", fmt("FIXME({}): {}", { i(1, "username"), i(2, "description") })),
        s("note", fmt("NOTE({}): {}", { i(1, "username"), i(2, "description") })),
      })

      -- Language-specific debug snippets
      local debug_configs = {
        javascript = { format = "console.log(`DEBUG [{}:{}] {} - ${{{}}}`);" },
        typescript = { format = "console.log(`DEBUG [{}:{}] {} - ${{{}}}`);" },
        lua = { format = "print(string.format(\"DEBUG [%s:%s] %s - %s\", \"{}\", \"{}\", \"{}\", tostring({})))" },
        rust = { format = "println!(\"DEBUG [{}:{}] {} - {{:?}}\", {});" },
        go = { format = "fmt.Printf(\"DEBUG [{}:{}] {} - %+v\\n\", {});" },
        c = { format = "printf(\"DEBUG [{}:{}] {} - %s\\n\", {});" },
        cpp = { format = "std::cout << \"DEBUG [{}:{}] {} - \" << {} << std::endl;" },
        python = { format = "print(f\"DEBUG [{}:{}] {} - {{{}}}\");" },
      }

      for lang, config in pairs(debug_configs) do
        ls.add_snippets(lang, { debug_snippet(config) })
      end

      -- Additional language-specific snippets
      ls.add_snippets("markdown", {
        s("daily", fmt("### {} v{} {}", {
          f(time_info("date")),
          f(time_info("week_number")),
          f(time_info("day_of_week"))
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
          f(time_info("date")),
          i(2, "tag1, tag2"),
          i(0)
        })),
        s("link", fmt("[{}]({})", { i(1, "text"), i(2, "url") })),
        s("img", fmt("![{}]({})", { i(1, "alt text"), i(2, "url") })),
        s("code", fmt("```{}\n{}\n```", { i(1, "language"), i(2, "code") })),
      })

      -- Copy shared snippets
      for _, lang in ipairs({ "typescript", "typescriptreact", "javascriptreact" }) do
        ls.add_snippets(lang, ls.get_snippets("javascript"))
      end
      ls.add_snippets("cpp", ls.get_snippets("c"))

      -- Snippet navigation
      vim.keymap.set({ "i", "s" }, "<C-L>", function() ls.jump(1) end, { silent = true })
      vim.keymap.set({ "i", "s" }, "<C-J>", function() ls.jump(-1) end, { silent = true })
      vim.keymap.set({ "i", "s" }, "<C-E>", function()
        if ls.choice_active() then ls.change_choice(1) end
      end, { silent = true })
    end,
  },

  { "rafamadriz/friendly-snippets", lazy = true },
})

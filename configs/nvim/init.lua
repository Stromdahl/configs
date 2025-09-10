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
  vim.cmd("split")
  vim.lsp.buf.definition()
end

local function toggle_diognastic_virtual_text()
  local vt = vim.diagnostic.config().virtual_text
  vim.diagnostic.config({ virtual_text = not vt })
end

local function toggle_diognastic_virtual_lines()
  local vl = vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = not vl })
end

--------------------------------------
-- Keymaps
--------------------------------------
-- diagnostic toggles
vim.keymap.set("n", "<leader>dl", toggle_diognastic_virtual_lines, { desc = "Toggle diagnostic virtual_lines" })
vim.keymap.set("n", "<leader>dt", toggle_diognastic_virtual_text, { desc = "Toggle diagnostic virtual_text" })

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


vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() math.floor(vim.api.nvim_win_get_height(0) / 4) end,
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
-- LSP (0.11+ built-in config/enable)
--------------------------------------
vim.lsp.config["rust-analyzer"] = {
  cmd = { "rust-analyzer" },
  root_markers = { "Cargo.toml", "rust-project.json" },
  filetypes = { "rust" },
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

vim.lsp.enable({ "rust-analyzer", "lua_ls", "tsserver" })

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })

      vim.keymap.set("i", "<CR>", function()
        return vim.fn.pumvisible() == 1 and "<C-y>" or "<CR>"
      end, { expr = true, buffer = ev.buf })

      vim.keymap.set("i", "<Tab>", function()
        return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
      end, { expr = true, buffer = ev.buf })

      vim.keymap.set("i", "<S-Tab>", function()
        return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
      end, { expr = true, buffer = ev.buf })

      vim.keymap.set("i", "<C-Space>", function()
        vim.lsp.completion.get()
      end, { expr = true, buffer = ev.buf })
    end
  end,
})

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
      { "<leader>ff", function() require("fzf-lua").files() end,                                 desc = "[f]ind [f]ile" },
      { "<leader>fp", function() require("fzf-lua").files({ cwd = vim.fn.expand("%:p:h") }) end, desc = "[f]ind file in [p]ath" },
      { "<leader>fg", function() require("fzf-lua").live_grep() end,                             desc = "[f]ind by [g]rep" },
    }
  },

  -- Snippets
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",                -- use stable branch
    build = "make install_jsregexp", -- optional: regex support
    opt = { enable_autosnippets = true },
    config = function(opt)
      local ls = require("luasnip")
      ls.setup(opt)

      local s = ls.snippet
      local i = ls.insert_node
      local t = ls.text_node
      local f = ls.function_node

      -- Define the snippet
      ls.add_snippets("all", {
        s("weeknum", {
          t("Current week number: "),
          f(get_week_number), -- Call the function to get the week number
        }),
      })


      -- Markdown

      -- Function to get the current date in the desired format
      local function get_formatted_date()
        return os.date("%Y-%m-%d") -- Format: YYYY-MM-DD
      end

      -- Function to get the current week number
      local function get_week_number()
        return os.date("%U") -- Week number (00-53)
      end

      -- Function to get the current day of the week
      local function get_day_of_week()
        return os.date("%A") -- Full weekday name
      end

      -- Define the Markdown header snippet
      ls.add_snippets("markdown", {
        s("daily", {
          t("### "),             -- Static part of the header
          f(get_formatted_date), -- Dynamic date
          t(" v"),               -- Static part for version
          f(get_week_number),    -- Dynamic week number
          t(" "),                -- Space
          f(get_day_of_week),    -- Dynamic day of the week
        }),
      })

      -- JavaScript
      ls.add_snippets("javascript", {
        s("log", { t("console.log("), i(1, "value"), t(")") }),
        s("log", { t("console.log("), i(1, "value"), t(")") }),
      })


      -- Keymaps
      vim.keymap.set({ "i", "s" }, "<C-k>", function() ls.expand_or_jump() end)
      vim.keymap.set({ "i", "s" }, "<C-j>", function() ls.jump(-1) end)
      vim.keymap.set("i", "<C-l>", function() ls.change_choice(1) end)
    end,
  }
})

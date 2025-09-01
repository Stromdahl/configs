return {
  'stevearc/oil.nvim',
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
    view_options = {
      show_hidden = true
    },
    watch_for_changes = true,
    keymaps = {
      ["<ESC>"] = {"actions.close", opts = {mode= 'n'}},
      ["-"] = {"actions.close", opts = {mode= 'n'}},
      ["<BACKSPACE>"] = { "actions.parent", mode = "n" },
    }
  },
  -- Optional dependencies
  dependencies = { { "echasnovski/mini.icons", opts = {}, lazy = false} },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
  keys = require('ms.keymap').oil
}

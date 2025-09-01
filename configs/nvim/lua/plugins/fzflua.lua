return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "echasnovski/mini.icons"},
    opts = {},
    keys = require('ms.keymap').fzf_lua
  },

  {
   "elanmed/fzf-lua-frecency.nvim",
    -- dependencies = {"ibhagwan/fzf-lua"},
    opts = {}
  }
}

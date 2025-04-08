return {
  "ibhagwan/fzf-lua",
  dependencies = { "echasnovski/mini.icons" },
  opts = {},
  keys = {
    {
      '<leader><leader>',
      function() require('fzf-lua').files() end,
      desc="[f]ind [f]files"
    },
    {
      '<leader>ff',
      function() require('fzf-lua').files() end,
      desc="[f]ind [f]files"
    },
    {
      '<leader>fg',
      function() require('fzf-lua').live_grep() end,
      desc="[[f]ind files by [g]rep]"
    },
    {
      '<leader>/',
      function() require('fzf-lua').grep_curbuf() end,
      desc="Grep in current buffer"
    }
  },
}

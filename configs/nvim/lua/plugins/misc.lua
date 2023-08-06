
return {
  "folke/which-key.nvim",
  "folke/neodev.nvim",
  { "iamcco/markdown-preview.nvim",
    config = function() vim.fn["mkdp#util#install"]() end
  },
  { "folke/neoconf.nvim", cmd = "Neoconf" },

  {
    "NLKNguyen/papercolor-theme",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      -- load the colorscheme here
      vim.cmd([[colorscheme PaperColor]])
    end,
    opts = {
    },
  },
  {
    "nvim-orgmode/orgmode",
    lazy = false,
    config = function()
      require('orgmode').setup_ts_grammar()
    end,
    opts = {
      org_agenda_files = {'~/documents/org/*', '~/documents/org/orgs/**/*'},
      org_default_notes_file = '~/documents/org/refile.org',
    }
  }
}

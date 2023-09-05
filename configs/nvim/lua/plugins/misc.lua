return {
  'tpope/vim-fugitive',

  "folke/which-key.nvim",

  "folke/neodev.nvim",

  { "iamcco/markdown-preview.nvim",
    config = function() vim.fn["mkdp#util#install"]() end
  },

  { "folke/neoconf.nvim", cmd = "Neoconf" },

  {
    "ibhagwan/fzf-lua",
    -- optional for icon support
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      -- calling `setup` is optional for customization
      require("fzf-lua").setup({})
    end
  },
  {
    'phaazon/hop.nvim',
    branch = 'v2', -- optional but strongly recommended
    config = function()
      -- you can configure Hop the way you like here; see :h hop-config
      require'hop'.setup {}
    end
  },
}

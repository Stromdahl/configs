local M = {
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    version = false,
    dependencies = {
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make"
      },
      {
        'nvim-telescope/telescope-ui-select.nvim',
      },
    },
    config = function ()
      local telescope = require('telescope')
      telescope.setup {
        ["ui-select"]  = {
          require("telescope.themes").get_dropdown {
          }
        },
        fzf = {
          fuzzy = true,                    -- false will only do exact matching
          override_generic_sorter = true,  -- override the generic sorter
          override_file_sorter = true,     -- override the file sorter
          case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
                                           -- the default case_mode is "smart_case"
        }
      }
      telescope.load_extension("ui-select")
      telescope.load_extension("fzf")
    end
  },

  --{
  --  config = function ()
  --    require("telescope").setup {
  --        extensions = {
  --          ["ui-select"] = {
  --            require("telescope.themes").get_dropdown {
  --            }
  --          }
  --        },
  --        -- fzf = {
  --        --   fuzzy = true,                    -- false will only do exact matching
  --        --   override_generic_sorter = true,  -- override the generic sorter
  --        --   override_file_sorter = true,     -- override the file sorter
  --        --   case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
  --        --                                    -- the default case_mode is "smart_case"
  --        -- }
  --      }
  --      -- To get ui-select loaded and working with telescope, you need to call
  --      -- load_extension, somewhere after setup function:
  --  end
  --},

  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
      -- "3rd/image.nvim", -- Optional image support in preview window: See `# Preview Mode` for more information
    }
  },
}

return M

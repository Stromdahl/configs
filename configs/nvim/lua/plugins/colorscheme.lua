return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      on_colors = function (colors)
        colors.bg = "#181818" -- Set your desired background color
      end,
    },
  },
  {
    "ellisonleao/gruvbox.nvim",
    lazy = false,
    priority = 1000,
    config = true,
    opts = {
      contrast = "hard",
      palette_overrides = {
        dark0_hard = "#181818",
      }
    }
  }
}

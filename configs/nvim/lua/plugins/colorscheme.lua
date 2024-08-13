return {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      on_colors = function (colors)
        colors.bg = "#181818" -- Set your desired background color
      end,
    },
  }

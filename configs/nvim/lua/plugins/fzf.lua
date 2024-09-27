local M = {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    -- calling `setup` is optional for customization
    require("fzf-lua").setup({
      -- keymap = {
      --   fzf = {
      --     ["ctrl-shift-j"]    = "preview-page-down",
      --     ["ctrl-shift-k"]    = "preview-page-up",
      --   }
      -- }
    })
  end
}

return M;

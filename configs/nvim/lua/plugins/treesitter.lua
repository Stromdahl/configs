local M = {
  "nvim-treesitter/nvim-treesitter",
  build = function()
    require("nvim-treesitter.install").update({ with_sync = true })
  end,
  config = function ()
    local configs = require("nvim-treesitter.configs")

    configs.setup({
      ensure_installed = {
        "rust",
        "markdown",
        "c",
        "heex",
        "html",
        "javascript",
        "lua",
        "query",
        "typescript",
        "vim",
        "vimdoc",
      },
      sync_install = false,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = {'org'},
      },
      indent = { enable = true },
    })
  end
}

return { M }

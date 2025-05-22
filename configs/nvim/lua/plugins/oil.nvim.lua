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
      ["<leader>sh"] = {
        function()
          local oil = require("oil")
          local dir = oil.get_current_dir()

          if not dir then
            vim.notify("Not in an Oil buffer", vim.log.levels.WARN)
            return
          end

          vim.ui.input({ prompt = "Shell command: " }, function(cmd)
            if not cmd or cmd == "" then return end

            vim.fn.jobstart(cmd, {
              cwd = dir,
              stdout_buffered = true,
              stderr_buffered = true,
              on_stdout = function(_, data)
                if data then
                  vim.notify(table.concat(data, "\n"), vim.log.levels.INFO)
                end
              end,
              on_stderr = function(_, data)
                if data then
                  vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
                end
              end,
            })
          end)
        end,
        mode = "n"
      }
    }
  },
  -- Optional dependencies
  dependencies = { { "echasnovski/mini.icons", opts = {}, lazy = false} },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
  keys = require('ms.keymap').oil
}
-- :echo expand("%:p:h")

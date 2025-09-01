local map_n = require('ms.utils.keys').map_n
local command = require('ms.utils').command


return {
  'akinsho/toggleterm.nvim',
  event = 'VeryLazy',
  version = "*",
  opts = {
    size = function(term)
      if term.direction == 'horizontal' then
        return vim.o.lines * 0.25
      elseif term.direction == 'vertical' then
        local cols = vim.o.columns * 0.25
        return cols > 80 and cols or 80
      end
    end,
    open_mapping = [[<C-\>]],
    hide_numbers = true,
    direction = 'vertical'
  },
  config = function (_, opts)
    require('toggleterm').setup(opts)

    local Terminal = require('toggleterm.terminal').Terminal

    local inode = Terminal:new({
      cmd = 'node ~/development/javascript/inode',
      hidden = true,
      direction = 'vertical',
      shade_terminals = true,
    });

    map_n({'<leader>tn', function() inode:toggle() end, {
      desc = 'toggleterm: toggle interactive node',
    }})

  end
}

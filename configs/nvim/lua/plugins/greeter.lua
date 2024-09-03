
local header = {
  "                                                     ",
  "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
  "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
  "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
  "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
  "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
  "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
  "                                                     ",
}

local function dashboard()
  dashboard = require("alpha.themes.dashboard")

  -- Set header
  dashboard.section.header.val = header;

  -- Set menu
  dashboard.section.buttons.val = {
      dashboard.button( "e", "  > New file" , ":ene <BAR> startinsert <CR>"),
      dashboard.button( "f", "  > Find file", ":cd $HOME/Workspace | Telescope find_files<CR>"),
      dashboard.button( "r", "  > Recent"   , ":Telescope oldfiles<CR>"),
      dashboard.button( "s", "  > Settings" , ":e ~/.config/nvim | :cd %:p:h | split . | wincmd k | pwd<CR>"),
      dashboard.button( "q", "  > Quit NVIM", ":qa<CR>"),
  }

  -- Set footer
  --   NOTE: This is currently a feature in my fork of alpha-nvim (opened PR #21, will update snippet if added to main)
  --   To see test this yourself, add the function as a dependecy in packer and uncomment the footer lines
  --   ```init.lua
  --   return require('packer').startup(function()
  --       use 'wbthomason/packer.nvim'
  --       use {
  --           'goolord/alpha-nvim', branch = 'feature/startify-fortune',
  --           requires = {'BlakeJC94/alpha-nvim-fortune'},
  --           config = function() require("config.alpha") end
  --       }
  --   end)
  --   ```
  -- local fortune = require("alpha.fortune") 
  -- dashboard.section.footer.val = fortune()
  -- Send config to alpha
  return dashboard
end

local M = {
  {
    'goolord/alpha-nvim',
    config = function ()
      local alpha = require'alpha' --.setup(require'alpha.themes.dashboard'.config)

      alpha.setup(dashboard().opts)

      -- Disable folding on alpha buffer
      vim.cmd([[
          autocmd FileType alpha setlocal nofoldenable
      ]])
      end
  };
}

return M

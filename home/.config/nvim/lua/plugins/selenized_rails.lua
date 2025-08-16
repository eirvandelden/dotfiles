-- Use your theme plugin + set it as the default colorscheme (via wrapper "selenized")
return {
  -- your repo on GitHub
  { "eirvandelden/selenized_rails.nvim", lazy = false, priority = 1000 },

  -- tell LazyVim to use the wrapper name
  { "LazyVim/LazyVim", opts = { colorscheme = "selenized" } },

  -- extra config to pick light/black variants depending on background
  {
    "eirvandelden/selenized_rails.nvim",
    config = function()
      if vim.o.background == "light" then
        vim.g.selenized_light_variant = "light"
      else
        vim.g.selenized_dark_variant = "black"
      end
    end,
  },
}

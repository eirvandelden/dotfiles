return {
  "eirvandelden/selenized_rails.nvim",
  lazy = false,
  priority = 1000,
  config = function()
    if vim.o.background == "light" then
      vim.g.selenized_light_variant = "light"
    else
      vim.g.selenized_dark_variant = "dark"
    end
    vim.cmd.colorscheme("selenized")
  end,
}

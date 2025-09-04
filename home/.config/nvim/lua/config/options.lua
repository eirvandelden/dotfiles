-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
local opt = vim.opt
-- Enable wrap
opt.wrap = true

-- Always add a blank line at the end
opt.endofline = true
opt.fixendofline = true
opt.fixeol = true

-- set cursor
opt.guicursor = {
  -- Normal/visual/command: thick solid bar
  "n-v-c:hor70",

  -- Insert/replace/etc: thin blinking bar
  "i-ci-ve-r-cr-sm:ver20-blinkwait300-blinkon200-blinkoff150",
}

opt.clipboard = "unnamedplus"

-- set leader to ;
vim.g.mapleader = ";"
vim.g.maplocalleader = ";"

-- RUBY
vim.g.lazyvim_ruby_lsp = "solargraph"

-- Ensure visible window separators between splits (including Avante sidebar)
opt.fillchars:append({
  vert = "│",
  vertleft = "│",
  vertright = "│",
  verthoriz = "┼",
})
-- Make the split separator stand out; link to FloatBorder or set explicit colors
pcall(function()
  vim.api.nvim_set_hl(0, "WinSeparator", { link = "FloatBorder" })
end)

vim.g.lazyvim_ruby_formatter = "rubocop"

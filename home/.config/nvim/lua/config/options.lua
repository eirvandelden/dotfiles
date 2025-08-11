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

-- RUBY
vim.g.lazyvim_ruby_lsp = "solargraph"
vim.g.lazyvim_ruby_formatter = "rubocop"

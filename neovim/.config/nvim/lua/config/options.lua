-- Loaded explicitly from init.lua before lazy.nvim startup
-- Disable netrw so it doesn't hijack directory buffers
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Choose startup behavior when launching with a directory: true => mini.files, false => blank buffer
vim.g.start_with_mini_files = true

local opt = vim.opt
-- Enable wrap
opt.wrap = true

-- Always add a blank line at the end
opt.endofline = true
opt.fixendofline = true
opt.fixeol = true

opt.number = true
opt.relativenumber = true
opt.ignorecase = true
opt.smartcase = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.splitbelow = true
opt.splitright = true
opt.termguicolors = true
opt.undofile = true
opt.signcolumn = "yes"
opt.scrolloff = 4
opt.cursorline = true
opt.updatetime = 200
opt.timeoutlen = 300
opt.mouse = "a"
opt.laststatus = 3

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

-- Ensure visible window separators between splits (including Avante sidebar)
do
  local fill = opt.fillchars:get()
  fill.vert = "│"
  fill.vertleft = "│"
  fill.vertright = "│"
  fill.verthoriz = "┼"
  opt.fillchars = fill
end
-- Make the split separator stand out; link to FloatBorder or set explicit colors
pcall(function()
  vim.api.nvim_set_hl(0, "WinSeparator", { link = "FloatBorder" })
end)

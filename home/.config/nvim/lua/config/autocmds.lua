-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
--
--Disable autoformat for ERB-wrapped Lua files
vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
  pattern = "*.lua.erb",
  callback = function(args)
    -- LazyVim checks this flag before formatting
    vim.b[args.buf].autoformat = false
  end,
})

-- Also catch buffers that change filetype later
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "eruby", "eruby.lua" }, -- depending on your ft detection
  callback = function()
    vim.b.autoformat = false
  end,
})

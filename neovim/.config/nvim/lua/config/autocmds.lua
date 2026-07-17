-- Loaded from init.lua after lazy.nvim startup
--Disable autoformat for ERB-wrapped Lua files
vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
  pattern = "*.lua.erb",
  callback = function(args)
    -- conform.nvim checks this flag before formatting
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

-- Write buffer when losing focus
vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
  callback = function()
    if vim.bo.modifiable and not vim.bo.readonly and vim.fn.expand("%") ~= "" then
      vim.cmd("silent! write")
    end
  end,
})

-- When starting with a directory (e.g. `nvim .`), open mini.files or a blank buffer
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() == 1 then
      local arg = vim.fn.argv()[1]
      if arg and vim.fn.isdirectory(arg) == 1 then
        -- Change into the target directory
        pcall(vim.fn.chdir, arg)
        -- Open mini.files or a blank buffer based on toggle
        if vim.g.start_with_mini_files then
          pcall(function()
            require("mini.files").open(arg, true)
          end)
        else
          -- Ensure a clean, empty buffer
          vim.cmd("enew")
        end
      end
    end
  end,
})

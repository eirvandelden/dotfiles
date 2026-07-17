local parsers = {
  "ruby",
  "lua",
  "vim",
  "vimdoc",
  "embedded_template",
  "json",
  "yaml",
  "toml",
  "markdown",
  "markdown_inline",
  "bash",
  "javascript",
  "css",
  "html",
}

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install(parsers)
    vim.treesitter.language.register("embedded_template", "eruby")

    local filetypes = {
      "ruby",
      "lua",
      "vim",
      "help",
      "eruby",
      "json",
      "yaml",
      "toml",
      "markdown",
      "bash",
      "javascript",
      "css",
      "html",
    }
    vim.api.nvim_create_autocmd("FileType", {
      pattern = filetypes,
      callback = function()
        pcall(vim.treesitter.start)
      end,
    })
  end,
}

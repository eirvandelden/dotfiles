return {
  "neovim/nvim-lspconfig",
  dependencies = { "saghen/blink.cmp" },
  opts = {
    servers = {
      lua_ls = {},
      solargraph = {
        enabled = vim.g.lazyvim_ruby_lsp == "solargraph",
      },
      rubocop = {
        -- If Solargraph and Rubocop are both enabled as an LSP,
        -- diagnostics will be duplicated because Solargraph
        -- already calls Rubocop if it is installed
        enabled = vim.g.lazyvim_ruby_formatter == "rubocop" and vim.g.lazyvim_ruby_lsp ~= "solargraph",
      },
    },
  },
  config = function()
    local capabilities = require("blink.cmp").get_lsp_capabilities()
    local lspconfig = require("lspconfig")

    -- Setup Solargraph with blink capabilities, merging user module if present
    local solargraph_opts = {}
    pcall(function()
      solargraph_opts = require("lsp.solargraph")
    end)
    solargraph_opts = vim.tbl_deep_extend("force", solargraph_opts, { capabilities = capabilities })
    if vim.g.lazyvim_ruby_lsp == "solargraph" then
      lspconfig.solargraph.setup(solargraph_opts)
    end

    -- Setup Lua LS
    lspconfig.lua_ls.setup({ capabilities = capabilities })

    -- Setup RuboCop LSP if enabled and not duplicated by Solargraph
    if vim.g.lazyvim_ruby_formatter == "rubocop" and vim.g.lazyvim_ruby_lsp ~= "solargraph" then
      lspconfig.rubocop.setup({ capabilities = capabilities })
    end
  end,
}

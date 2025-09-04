return {
  "neovim/nvim-lspconfig",
  dependencies = { "saghen/blink.cmp" },
  opts = {
    servers = {
      lua_ls = {},
      solargraph = {
        enabled = lsp == "solargraph",
      },
      rubocop = {
        -- If Solargraph and Rubocop are both enabled as an LSP,
        -- diagnostics will be duplicated because Solargraph
        -- already calls Rubocop if it is installed
        enabled = formatter == "rubocop" and lsp ~= "solargraph",
      },
    },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      require("lspconfig").setup({ capabilities = capabilities })
    end,
  },
}

return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
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
  },
}

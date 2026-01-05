-- ~/.config/nvim/lua/plugins/herb.lua
return {
  -- (optional) install the server via Mason
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "herb-language-server" })
    end,
  },

  -- enable Herb LSP (and define it if your lspconfig is too old)
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      local lspconfig = require("lspconfig")
      local configs = require("lspconfig.configs")

      if not configs.herb_ls then
        configs.herb_ls = {
          default_config = {
            name = "herb_ls",
            cmd = { "herb-language-server", "--stdio" },
            filetypes = { "eruby", "erb" },
            root_dir = function(fname)
              return lspconfig.util.root_pattern("Gemfile", ".git")(fname) or vim.loop.cwd()
            end,
            single_file_support = true,
          },
        }
      end

      opts.servers = opts.servers or {}
      opts.servers.herb_ls = {}
    end,
  },
}

return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      ruby = { "rubocop" },
      lua = { "stylua" },
      sh = { "shfmt" },
      eruby = function(bufnr)
        local filename = vim.api.nvim_buf_get_name(bufnr)
        if filename:match("%.html%.erb$") then
          return { "herb" }
        else
          return { "erb_format" } -- fallback for other .erb files
        end
      end,
    },
    format_on_save = {
      timeout_ms = 500,
      lsp_fallback = false,
    },
  },
  config = function(_, opts)
    local conform = require("conform")

    -- Define herb formatter manually
    conform.formatters.herb = {
      command = "herb",
      args = { "format", "--stdin-filename", "$FILENAME" },
      stdin = true,
    }

    conform.setup(opts)
  end,
}

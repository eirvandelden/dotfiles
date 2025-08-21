-- op read op://private/OpenAI/api_key --no-newline"
return {
  {
    "olimorris/codecompanion.nvim",
    event = "VeryLazy",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    opts = function()
      return {
        adapters = {
          openai = function()
            return require("codecompanion.adapters").extend("openai", {
              env = { api_key = "cmd:op read op://private/OpenAI/api_key --no-newline" },
              schema = { model = { default = "gpt-4.1" } },
            })
          end,
        },
        strategies = {
          chat = { adapter = "openai" },
          inline = { adapter = "openai" },
        },
        display = {
          action_palette = { provider = "telescope" },
          chat = { start_in_insert_mode = false, show_token_count = true },
        },
      }
    end,
    config = function(_, opts)
      require("codecompanion").setup(opts)
      pcall(function()
        require("telescope").load_extension("codecompanion")
      end)

      -- Keys
      --- See which-key-extras
      -- Tip: in the chat buffer, press <C-/> to trigger the built-in completion menu
    end,
  },
}

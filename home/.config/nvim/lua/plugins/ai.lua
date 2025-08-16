return {
  {
    "jackMort/ChatGPT.nvim",
    event = "VeryLazy",
    config = function()
      require("chatgpt").setup({
        api_key_cmd = "op read op://private/OpenAI/api_key --no-newline",
        openai_param = {
          model = "gpt-5",
        },
      })
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "folke/trouble.nvim", -- optional
      "nvim-telescope/telescope.nvim",
    },
  },
}

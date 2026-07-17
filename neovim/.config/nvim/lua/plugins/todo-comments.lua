return {
  "folke/todo-comments.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {},
  keys = {
    {
      "<leader>st",
      "<cmd>TodoFzfLua<cr>",
      desc = "Search todos",
    },
  },
}

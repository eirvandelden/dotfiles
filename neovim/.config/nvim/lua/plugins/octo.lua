return {
  "pwntester/octo.nvim",
  cmd = "Octo",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    picker = "snacks",
  },
  keys = {
    { "<leader>go", "<cmd>Octo pr list<cr>", desc = "Octo: list PRs" },
  },
}

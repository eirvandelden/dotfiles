return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "rcarriga/nvim-notify",
  },
  opts = function(_, opts)
    -- Load notify extension once Telescope is ready
    require("telescope").load_extension("notify")
  end,
}

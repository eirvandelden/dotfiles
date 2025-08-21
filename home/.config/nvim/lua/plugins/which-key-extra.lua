--  add extra groups to which key
return {
  -- Add a new group under <leader>a and a command entry on "c"
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>a", group = "AI / Tools" }, -- the group header
        { "<leader>aa", "<cmd>CodeCompanionChat Toggle<cr>", desc = "Chat Toggle", mode = { "n", "v" } },
        { "<leader>ap", "<cmd>CodeCompanionActions<cr>", desc = "Action Palette", mode = { "n", "v" } },
        { "<leader>as", "<cmd>CodeCompanionChat Add<cr>", desc = "Send Selection to Chat", mode = "v" },
        { "<leader>aT", "<cmd>Telescope codecompanion<cr>", desc = "Telescope: CodeCompanion" },
      },
    },
  },
}

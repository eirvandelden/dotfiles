--  add extra groups to which key
return {
  -- Add a new group under <leader>a and a command entry on "c"
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>a", group = "AI / Tools" }, -- the group header
      },
    },
  },
}

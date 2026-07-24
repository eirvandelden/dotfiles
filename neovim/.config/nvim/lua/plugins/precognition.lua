-- Learn vim motion by seeing invisible characters and where they would take me

return {
  "tris203/precognition.nvim",
  --event = "VeryLazy",
  opts = {
    hints = {
      Dollar = { text = "$", prio = 1 },
      w = { text = "w", prio = 10 },
      b = { text = "b", prio = 9 },
      e = { text = "e", prio = 8 },
    },
  },
}

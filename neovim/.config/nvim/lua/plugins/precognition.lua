-- Learn vim motion by seeing invisible characters and where they would take me

return {
  "tris203/precognition.nvim",
  --event = "VeryLazy",
  opts = {
    -- setup() deep-merges over defaults; prio = 0 is the only way to hide a default hint
    hints = {
      Dollar = { text = "$", prio = 1 },
      w = { text = "w", prio = 10 },
      b = { text = "b", prio = 9 },
      e = { text = "e", prio = 8 },
      W = { prio = 0 },
      B = { prio = 0 },
      E = { prio = 0 },
      Caret = { prio = 0 },
      Zero = { prio = 0 },
      MatchingPair = { prio = 0 },
    },
    gutterHints = {
      G = { prio = 0 },
      gg = { prio = 0 },
      PrevParagraph = { prio = 0 },
      NextParagraph = { prio = 0 },
    },
  },
}

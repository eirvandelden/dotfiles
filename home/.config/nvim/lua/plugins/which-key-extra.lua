--  add extra groups to which key
return {
  -- Add a new group under <leader>a and a command entry on "c"
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>a", group = "AI / Tools" }, -- the group header
        { "<leader>ac", "<cmd>ChatGPT<CR>", desc = "ChatGPT", mode = { "n", "v" } }, -- normal-mode command
        { "<leader>ae", "<cmd>ChatGPTEditWithInstruction<CR>", desc = "Edit with instruction", mode = { "n", "v" } },
        { "<leader>ag", "<cmd>ChatGPTRun grammar_correction<CR>", desc = "Grammar Correction", mode = { "n", "v" } },
        { "<leader>at", "<cmd>ChatGPTRun translate<CR>", desc = "Translate", mode = { "n", "v" } },
        { "<leader>ak", "<cmd>ChatGPTRun keywords<CR>", desc = "Keywords", mode = { "n", "v" } },
        { "<leader>ad", "<cmd>ChatGPTRun docstring<CR>", desc = "Docstring", mode = { "n", "v" } },
        { "<leader>aa", "<cmd>ChatGPTRun add_tests<CR>", desc = "Add Tests", mode = { "n", "v" } },
        { "<leader>ao", "<cmd>ChatGPTRun optimize_code<CR>", desc = "Optimize Code", mode = { "n", "v" } },
        { "<leader>as", "<cmd>ChatGPTRun summarize<CR>", desc = "Summarize", mode = { "n", "v" } },
        { "<leader>af", "<cmd>ChatGPTRun fix_bugs<CR>", desc = "Fix Bugs", mode = { "n", "v" } },
        { "<leader>ax", "<cmd>ChatGPTRun explain_code<CR>", desc = "Explain Code", mode = { "n", "v" } },
        { "<leader>ar", "<cmd>ChatGPTRun roxygen_edit<CR>", desc = "Roxygen Edit", mode = { "n", "v" } },
        {
          "<leader>al",
          "<cmd>ChatGPTRun code_readability_analysis<CR>",
          desc = "Code Readability Analysis",
          mode = { "n", "v" },
        },
      },
    },
  },
}

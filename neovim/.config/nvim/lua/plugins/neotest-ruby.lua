return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-neotest/nvim-nio",
    "olimorris/neotest-rspec",
    "zidhuss/neotest-minitest",
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-rspec")({
          rspec_cmd = function()
            return { "rspec" } -- no bundler
          end,
        }),
        require("neotest-minitest")({
          test_cmd = function()
            return { "rails", "test" } -- Rails runner
          end,
        }),
      },
    })
  end,
}

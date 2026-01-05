return {
  -- Neotest core (LazyVim extra)
  { import = "lazyvim.plugins.extras.test.core" },

  -- Add the Ruby adapters
  {
    "nvim-neotest/neotest",
    dependencies = {
      "olimorris/neotest-rspec",
      "zidhuss/neotest-minitest",
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}

      -- RSpec adapter (no `bundle exec`)
      table.insert(
        opts.adapters,
        require("neotest-rspec")({
          rspec_cmd = function(position_type)
            -- choose one:
            return { "rspec" } -- no bundler
            -- return { "bin/rspec" }  -- if you use a binstub
            -- (adapter appends file/line args automatically)
          end,
          -- root_files/filter_dirs use good defaults; tweak if needed
        })
      )

      -- Minitest adapter (keep defaults or drop bundler too)
      table.insert(
        opts.adapters,
        require("neotest-minitest")({
          -- default is {"bundle","exec","ruby","-Itest"}
          -- if you also want NO bundler for minitest, uncomment one:
          -- test_cmd = function() return { "ruby", "-Itest" } end,
          test_cmd = function()
            return { "rails", "test" }
          end, -- Rails runner
        })
      )
    end,
  },
}

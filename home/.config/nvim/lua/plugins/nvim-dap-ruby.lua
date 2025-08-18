-- ~/.config/nvim/lua/plugins/nvim-dap-ruby.lua
return {
  {
    "suketa/nvim-dap-ruby",
    dependencies = { "mfussenegger/nvim-dap" },
    ft = { "ruby" }, -- optional: lazy-load on Ruby files
    config = function()
      require("dap-ruby").setup()
    end,
  },
}
